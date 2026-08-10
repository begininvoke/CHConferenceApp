import CocoaHeadsCore
import Crypto
import Foundation
import JWTKit
import SwiftASN1
import Testing
import VaporTesting
import X509

@testable import backend

@Suite("Access token payload")
struct AccessTokenPayloadTests {
  private func keyCollection() async -> JWTKeyCollection {
    await JWTKeyCollection().add(hmac: "test-signing-secret", digestAlgorithm: .sha256)
  }

  @Test("Signs and verifies a round trip with intact claims")
  func roundTrip() async throws {
    let keys = await keyCollection()
    let userID = UUID()
    let now = Date()
    let payload = AccessTokenPayload(
      subject: SubjectClaim(value: userID.uuidString),
      expiration: ExpirationClaim(value: now.addingTimeInterval(900)),
      issuedAt: IssuedAtClaim(value: now),
      role: .organizer
    )

    let token = try await keys.sign(payload)
    let verified = try await keys.verify(token, as: AccessTokenPayload.self)
    #expect(try verified.userID == userID)
    #expect(verified.role == .organizer)
  }

  @Test("Rejects an expired token")
  func expired() async throws {
    let keys = await keyCollection()
    let payload = AccessTokenPayload(
      subject: SubjectClaim(value: UUID().uuidString),
      expiration: ExpirationClaim(value: Date().addingTimeInterval(-60)),
      issuedAt: IssuedAtClaim(value: Date().addingTimeInterval(-960)),
      role: .user
    )

    let token = try await keys.sign(payload)
    await #expect(throws: (any Error).self) {
      try await keys.verify(token, as: AccessTokenPayload.self)
    }
  }

  @Test("Rejects a token signed with a different key")
  func wrongKey() async throws {
    let keys = await keyCollection()
    let otherKeys = await JWTKeyCollection().add(hmac: "other-secret", digestAlgorithm: .sha256)
    let payload = AccessTokenPayload(
      subject: SubjectClaim(value: UUID().uuidString),
      expiration: ExpirationClaim(value: Date().addingTimeInterval(900)),
      issuedAt: IssuedAtClaim(value: Date()),
      role: .user
    )

    let token = try await otherKeys.sign(payload)
    await #expect(throws: (any Error).self) {
      try await keys.verify(token, as: AccessTokenPayload.self)
    }
  }

  @Test("A malformed subject is rejected when resolving the user id")
  func malformedSubject() {
    let payload = AccessTokenPayload(
      subject: SubjectClaim(value: "not-a-uuid"),
      expiration: ExpirationClaim(value: Date().addingTimeInterval(900)),
      issuedAt: IssuedAtClaim(value: Date()),
      role: .user
    )
    #expect(throws: (any Error).self) {
      try payload.userID
    }
  }
}

@Suite("Apple client secret")
struct AppleClientSecretTests {
  @Test("Carries the claims Apple's token endpoint requires, with the kid header")
  func claimsAndHeader() async throws {
    let privateKey = P256.Signing.PrivateKey()
    let kid = JWKIdentifier(string: "TESTKEY123")
    let keys = JWTKeyCollection()
    try await keys.add(ecdsa: ES256PrivateKey(pem: privateKey.pemRepresentation), kid: kid)

    let now = Date()
    let payload = AppleClientSecretPayload(
      issuer: IssuerClaim(value: "TEAMID1234"),
      issuedAt: IssuedAtClaim(value: now),
      expiration: ExpirationClaim(value: now.addingTimeInterval(300)),
      audience: AudienceClaim(value: "https://appleid.apple.com"),
      subject: SubjectClaim(value: "com.cocoaheadsbr.conf")
    )
    let token = try await keys.sign(payload, kid: kid)

    let verified = try await keys.verify(token, as: AppleClientSecretPayload.self)
    #expect(verified.issuer.value == "TEAMID1234")
    #expect(verified.audience.value.contains("https://appleid.apple.com"))
    #expect(verified.subject.value == "com.cocoaheadsbr.conf")

    // Apple requires the key id in the JOSE header.
    let headerSegment = String(token.split(separator: ".")[0])
    var base64 = headerSegment.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    while base64.count % 4 != 0 { base64.append("=") }
    let headerData = try #require(Data(base64Encoded: base64))
    let header = try #require(
      try JSONSerialization.jsonObject(with: headerData) as? [String: Any]
    )
    #expect(header["kid"] as? String == "TESTKEY123")
    #expect(header["alg"] as? String == "ES256")
  }
}

@Suite("API key middleware")
struct APIKeyMiddlewareTests {
  private func configuration(apiKeys: Set<String>) -> AuthConfiguration {
    AuthConfiguration(
      appleBundleID: "com.cocoaheadsbr.conf",
      apiKeys: apiKeys,
      accessTokenTTL: 900,
      refreshTokenTTL: 3600,
      accountPurgeGraceDays: 30,
      appleTeamID: nil,
      appleSignInKeyID: nil,
      appleSignInPrivateKey: nil,
      appAttestTeamID: nil,
      appAttestEnvironment: .production,
      appAttestDisabled: true
    )
  }

  /// A minimal app with one API-key-gated route — no database needed.
  private func withApp(
    keys: Set<String>,
    _ test: (Application) async throws -> Void
  ) async throws {
    let app = try await Application.make(.testing)
    do {
      app.authConfiguration = configuration(apiKeys: keys)
      app.grouped(APIKeyMiddleware()).get("ping") { _ in "pong" }
      try await test(app)
    } catch {
      try? await app.asyncShutdown()
      throw error
    }
    try await app.asyncShutdown()
  }

  @Test("Accepts a configured key")
  func validKey() async throws {
    try await withApp(keys: ["good-key"]) { app in
      try await app.testing().test(
        .GET, "ping",
        headers: ["X-API-Key": "good-key"],
        afterResponse: { res async in
          #expect(res.status == .ok)
          #expect(res.body.string == "pong")
        }
      )
    }
  }

  @Test("Rejects a missing key")
  func missingKey() async throws {
    try await withApp(keys: ["good-key"]) { app in
      try await app.testing().test(
        .GET, "ping",
        afterResponse: { res async in
          #expect(res.status == .unauthorized)
        }
      )
    }
  }

  @Test("Rejects a wrong key")
  func wrongKey() async throws {
    try await withApp(keys: ["good-key"]) { app in
      try await app.testing().test(
        .GET, "ping",
        headers: ["X-API-Key": "bad-key"],
        afterResponse: { res async in
          #expect(res.status == .unauthorized)
        }
      )
    }
  }

  @Test("Fails closed when no keys are configured")
  func noKeysConfigured() async throws {
    try await withApp(keys: []) { app in
      try await app.testing().test(
        .GET, "ping",
        headers: ["X-API-Key": "any-key"],
        afterResponse: { res async in
          #expect(res.status == .serviceUnavailable)
        }
      )
    }
  }
}

@Suite("App Attest attestation failure paths")
struct AttestationFailureTests {
  private let verifier = AppAttestVerifier(environment: .development)
  private static let appID = "TEAMID1234.com.cocoaheadsbr.conf"
  private static let keyId = Data(repeating: 1, count: 32)
  private static let challenge = Data("challenge".utf8)

  // Minimal CBOR encoders for building attestation objects in tests.
  private func cborText(_ string: String) -> Data {
    Data([0x60 | UInt8(string.utf8.count)]) + Data(string.utf8)
  }

  private func cborBytes(_ data: Data) -> Data {
    precondition(data.count < 65536)
    if data.count <= 23 { return Data([0x40 | UInt8(data.count)]) + data }
    if data.count < 256 { return Data([0x58, UInt8(data.count)]) + data }
    return Data([0x59, UInt8(data.count >> 8), UInt8(data.count & 0xFF)]) + data
  }

  private func attestationObject(fmt: String, credCertDER: Data) -> Data {
    var object = Data([0xA3])
    object.append(cborText("fmt"))
    object.append(cborText(fmt))
    object.append(cborText("attStmt"))
    object.append(Data([0xA2]))
    object.append(cborText("x5c"))
    object.append(Data([0x81]))
    object.append(cborBytes(credCertDER))
    object.append(cborText("receipt"))
    object.append(cborBytes(Data()))
    object.append(cborText("authData"))
    object.append(cborBytes(Data(repeating: 0, count: 55)))
    return object
  }

  @Test("Rejects garbage input")
  func garbage() async {
    await #expect(throws: (any Error).self) {
      try await verifier.verifyAttestation(
        Data([0xDE, 0xAD, 0xBE, 0xEF]),
        keyId: Self.keyId,
        challenge: Self.challenge,
        appID: Self.appID
      )
    }
  }

  @Test("Rejects a non-App-Attest format")
  func wrongFormat() async {
    let attestation = attestationObject(fmt: "packed", credCertDER: Data([1, 2, 3]))
    await #expect(throws: AppAttestVerifier.VerificationError.unexpectedFormat("packed")) {
      try await verifier.verifyAttestation(
        attestation,
        keyId: Self.keyId,
        challenge: Self.challenge,
        appID: Self.appID
      )
    }
  }

  @Test("Rejects an unparseable credential certificate")
  func malformedCertificate() async {
    let attestation = attestationObject(fmt: "apple-appattest", credCertDER: Data([1, 2, 3]))
    await #expect(throws: (any Error).self) {
      try await verifier.verifyAttestation(
        attestation,
        keyId: Self.keyId,
        challenge: Self.challenge,
        appID: Self.appID
      )
    }
  }

  @Test("Rejects a certificate that does not chain to Apple's root")
  func selfSignedCertificate() async throws {
    let key = P256.Signing.PrivateKey()
    let name = try DistinguishedName {
      CommonName("Fake App Attest Credential")
    }
    let now = Date()
    let certificate = try Certificate(
      version: .v3,
      serialNumber: .init(),
      publicKey: .init(key.publicKey),
      notValidBefore: now.addingTimeInterval(-3600),
      notValidAfter: now.addingTimeInterval(3600),
      issuer: name,
      subject: name,
      signatureAlgorithm: .ecdsaWithSHA256,
      extensions: Certificate.Extensions(),
      issuerPrivateKey: .init(key)
    )
    var serializer = DER.Serializer()
    try serializer.serialize(certificate)
    let attestation = attestationObject(
      fmt: "apple-appattest",
      credCertDER: Data(serializer.serializedBytes)
    )

    await #expect(throws: AppAttestVerifier.VerificationError.certificateChainInvalid) {
      try await verifier.verifyAttestation(
        attestation,
        keyId: Self.keyId,
        challenge: Self.challenge,
        appID: Self.appID
      )
    }
  }
}
