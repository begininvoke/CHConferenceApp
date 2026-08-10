# User Authentication & App Authentication — Implementation Notes

Implements [`user-auth-spec.md`](user-auth-spec.md). This document covers what a
client (and a reviewer) needs to know about the concrete implementation.

## Layers

Every route is behind **app authentication**; user-scoped routes additionally
require a **Bearer JWT**:

```
Request ─▶ X-API-Key check ─▶ App Attest assertion ─▶ (Bearer JWT) ─▶ handler
```

| Route | API key | App Attest | Bearer JWT |
| --- | --- | --- | --- |
| `POST /attest/challenge` | ✅ | – | – |
| `POST /attest/key` | ✅ | – (registration) | – |
| `POST /auth/apple` | ✅ | ✅ | – |
| `POST /auth/refresh` | ✅ | ✅ | – (valid refresh token) |
| `POST /auth/logout` | ✅ | ✅ | ✅ |
| `GET /me` | ✅ | ✅ | ✅ |
| `DELETE /me` | ✅ | ✅ | ✅ |
| `POST /scrape` | ✅ | ✅ | – |

## App Attest client protocol

App Attest verification is implemented server-side from scratch
(`Sources/backend/Auth/AppAttest/`): CBOR decoding, X.509 chain validation
against [Apple's App Attest root CA](https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem)
via `swift-certificates`, nonce-extension (OID `1.2.840.113635.100.8.2`)
comparison, and monotonic `signCount` replay protection.

**Registration (once per device):**
1. `POST /attest/challenge` → `{ challenge, expiresIn }` (base64, single-use, 5 min TTL).
2. `DCAppAttestService.generateKey()` → `keyId`.
3. `attestKey(keyId, clientDataHash: SHA256(challenge bytes))` → attestation object.
4. `POST /attest/key` with `{ keyId, attestation, challenge }` (all base64).

**Assertion (per protected request):**
1. `POST /attest/challenge` → fresh challenge.
2. `clientDataHash = SHA256(challenge bytes + exact HTTP body bytes)`.
3. `generateAssertion(keyId, clientDataHash:)` → assertion CBOR.
4. Send the request with headers:
   - `X-Attest-Key-Id`: the key id (base64)
   - `X-Attest-Challenge`: the challenge (base64)
   - `X-Attest-Assertion`: the assertion (base64)

`APP_ATTEST_DISABLED=true` skips assertion checks for local development — App
Attest requires physical hardware (not the simulator). Never set in production.

## Sign in with Apple

`POST /auth/apple` body is `AppleSignInRequest` (shared DTO in
`CocoaHeadsCore`). The server verifies the identity token against Apple's JWKS
(`aud` = `APPLE_BUNDLE_ID`), upserts the user on the Apple `sub`, exchanges the
authorization code at `https://appleid.apple.com/auth/token` (client-secret JWT
signed with the Sign in with Apple `.p8` key), stores Apple's refresh token
AES-GCM-encrypted, and returns a `TokenResponse`:

- **Access token**: backend-signed JWT (ES256 when `JWT_SIGNING_KEY` is a PEM,
  HS256 otherwise), TTL `ACCESS_TOKEN_TTL` (default 15 min), claims
  `sub`/`role`/`exp`/`iat`. Verified statelessly.
- **Refresh token**: opaque 32-byte random value; only its SHA-256 hash is
  stored. Single-use — `POST /auth/refresh` revokes it and issues a new pair.

## Account deletion (Guideline 5.1.1(v))

`DELETE /me`:
1. Revokes the Apple grant via `https://appleid.apple.com/auth/revoke` (best
   effort; failures are logged, deletion proceeds).
2. Scrubs PII immediately (`email`, `fullName`, stored Apple refresh token).
3. Revokes all refresh tokens and App Attest keys for the user.
4. Soft-deletes (`deleted_at`). `AccountPurgeService` hard-purges rows older
   than `ACCOUNT_PURGE_GRACE_DAYS` (default 30) at boot and every 12 h.

## Environment variables

| Variable | Purpose | Default |
| --- | --- | --- |
| `JWT_SIGNING_KEY` | ES256 private-key PEM (recommended) or HS256 secret for access tokens | dev-only fallback |
| `APPLE_BUNDLE_ID` | Expected `aud` of Apple identity tokens / client id | `com.cocoaheadsbr.conf` |
| `API_KEYS` | Comma-separated static client keys | *(unset → requests rejected)* |
| `ACCESS_TOKEN_TTL` | Access-token lifetime (seconds) | `900` |
| `REFRESH_TOKEN_TTL` | Refresh-token lifetime (seconds) | `3888000` (45 days) |
| `ACCOUNT_PURGE_GRACE_DAYS` | Hard-purge delay after soft-delete | `30` |
| `APPLE_TEAM_ID` | Apple Developer Team ID | — |
| `APPLE_SIGNIN_KEY_ID` | Key ID of the Sign in with Apple `.p8` key | — |
| `APPLE_SIGNIN_PRIVATE_KEY` | `.p8` private-key contents (ES256) | — |
| `APP_ATTEST_TEAM_ID` | Team ID for the App Attest app id | falls back to `APPLE_TEAM_ID` |
| `APP_ATTEST_ENVIRONMENT` | `production` or `development` (aaguid) | `production` |
| `APP_ATTEST_DISABLED` | Skip assertion checks (local dev only) | `false` |
| `TOKEN_ENCRYPTION_KEY` | Base64 32-byte AES-256 key for secrets at rest | derived from `JWT_SIGNING_KEY` |

## Local development

```bash
cd backend
docker compose up -d db
export API_KEYS=dev-key APP_ATTEST_DISABLED=true JWT_SIGNING_KEY=dev-secret
swift run backend migrate --yes
swift run backend serve
```

- `APP_ATTEST_DISABLED=true` skips assertion checks (the simulator cannot
  attest). The simulator client should send no attest headers in this mode.
- Sign in with Apple works against a local server: identity-token verification
  only needs internet access to Apple's JWKS. When the `.p8` service
  credentials (`APPLE_TEAM_ID`/`APPLE_SIGNIN_KEY_ID`/`APPLE_SIGNIN_PRIVATE_KEY`)
  are **not** configured, non-production environments skip the
  authorization-code exchange with a warning and store no Apple refresh token
  (account deletion then has no Apple grant to revoke). Production always
  requires the credentials and fails sign-in without them.

## Known limitations / follow-ups

- **Challenge store is in-memory** (`ChallengeStore`): fine for the current
  single-instance deployment; a multi-instance deployment needs a shared store.
- **Roles are foundation-only** (§7): `role` is persisted and embedded in
  access-token claims, but no `RoleMiddleware` enforces it yet.
- **Rate limiting** on `/auth/*` and `DELETE /me` is future work (§10).
- **iOS client** (spec §9) is not part of this change: the app still needs an
  HTTP layer, the Sign in with Apple capability/entitlement, Keychain storage
  for the refresh token + App Attest key id, and an in-app "Delete Account"
  action that calls `DELETE /me`. The shared DTOs it will use are already in
  `CocoaHeadsCore/Sources/CocoaHeadsCore/Auth/`.
