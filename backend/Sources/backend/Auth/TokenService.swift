//
//  TokenService.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import CocoaHeadsCore
import Crypto
import Fluent
import JWT
import SQLKit
import Vapor

/// Issues and rotates the backend's own session tokens (§5 of the auth spec).
struct TokenService: Sendable {
  /// Issues an access-token + refresh-token pair for a user. Only the SHA-256
  /// hash of the refresh token is persisted.
  func issueTokenPair(for user: User, on req: Request) async throws -> TokenResponse {
    let rawRefreshToken = try await Self.storeRefreshToken(
      userID: user.requireID(),
      ttl: req.authConfiguration.refreshTokenTTL,
      on: req.db
    )
    return try await Self.tokenResponse(user: user, rawRefreshToken: rawRefreshToken, on: req)
  }

  /// Single-use rotation: revokes the presented refresh token and issues a new
  /// pair. Rejects unknown, revoked, or expired tokens. Runs in a transaction,
  /// and the revocation is conditional so concurrent rotations of the same
  /// token have exactly one winner. Presenting an already-revoked token is
  /// treated as theft: every refresh token of that user is revoked (§10).
  private enum RotationOutcome {
    case rotated(User, rawRefreshToken: String)
    case reuseDetected(userID: UUID)
    case rejected(reason: String)
  }

  func rotate(refreshToken raw: String, on req: Request) async throws -> TokenResponse {
    let hash = Self.hash(raw)
    let refreshTTL = req.authConfiguration.refreshTokenTTL

    // Throwing inside the transaction would roll back any writes, so reuse
    // detection only *reports* here and the family revocation happens after,
    // where it persists.
    let outcome = try await req.db.transaction { db -> RotationOutcome in
      guard
        let record = try await RefreshToken.query(on: db)
          .filter(\.$tokenHash == hash)
          .first()
      else {
        return .rejected(reason: "Unknown refresh token.")
      }
      let userID = record.$user.id

      guard !record.revoked else {
        // A rotated token came back — assume the family is compromised.
        return .reuseDetected(userID: userID)
      }
      guard record.expiresAt > Date() else {
        return .rejected(reason: "Refresh token expired.")
      }
      guard try await Self.claimForRotation(record, on: db) else {
        // Lost the race — a concurrent rotation just consumed this token.
        return .reuseDetected(userID: userID)
      }
      guard let user = try await User.find(userID, on: db) else {
        return .rejected(reason: "Account no longer exists.")
      }
      let rawRefreshToken = try await Self.storeRefreshToken(
        userID: userID,
        ttl: refreshTTL,
        on: db
      )
      return .rotated(user, rawRefreshToken: rawRefreshToken)
    }

    switch outcome {
    case .rotated(let user, let rawRefreshToken):
      return try await Self.tokenResponse(user: user, rawRefreshToken: rawRefreshToken, on: req)
    case .reuseDetected(let userID):
      try await revokeAll(for: userID, on: req.db)
      throw Abort(.unauthorized, reason: "Refresh token revoked.")
    case .rejected(let reason):
      throw Abort(.unauthorized, reason: reason)
    }
  }

  /// Revokes the presented refresh token (logout).
  func revoke(refreshToken raw: String, on req: Request) async throws {
    guard
      let record = try await RefreshToken.query(on: req.db)
        .filter(\.$tokenHash == Self.hash(raw))
        .first()
    else { return }
    record.revoked = true
    try await record.save(on: req.db)
  }

  /// Revokes every refresh token belonging to a user (account deletion, or
  /// reuse detection during rotation).
  func revokeAll(for userID: UUID, on db: any Database) async throws {
    try await RefreshToken.query(on: db)
      .filter(\.$user.$id == userID)
      .set(\.$revoked, to: true)
      .update()
  }

  /// Marks the record revoked, returning whether this caller won the claim.
  /// On SQL databases the update is conditional (`AND revoked = false` with
  /// `RETURNING`), so exactly one concurrent rotation can succeed.
  private static func claimForRotation(
    _ record: RefreshToken,
    on db: any Database
  ) async throws -> Bool {
    guard let sql = db as? any SQLDatabase else {
      record.revoked = true
      try await record.save(on: db)
      return true
    }
    let claimed = try await sql.raw(
      """
      UPDATE \(ident: RefreshToken.schema)
      SET revoked = true
      WHERE id = \(bind: record.requireID()) AND revoked = false
      RETURNING id
      """
    ).all()
    return !claimed.isEmpty
  }

  private static func storeRefreshToken(
    userID: UUID,
    ttl: TimeInterval,
    on db: any Database
  ) async throws -> String {
    let raw = generateRefreshToken()
    try await RefreshToken(
      userID: userID,
      tokenHash: hash(raw),
      expiresAt: Date().addingTimeInterval(ttl)
    ).save(on: db)
    return raw
  }

  private static func tokenResponse(
    user: User,
    rawRefreshToken: String,
    on req: Request
  ) async throws -> TokenResponse {
    let config = req.authConfiguration
    let now = Date()
    let payload = AccessTokenPayload(
      subject: SubjectClaim(value: try user.requireID().uuidString),
      expiration: ExpirationClaim(value: now.addingTimeInterval(config.accessTokenTTL)),
      issuedAt: IssuedAtClaim(value: now),
      role: user.role
    )
    return TokenResponse(
      accessToken: try await req.jwt.sign(payload),
      refreshToken: rawRefreshToken,
      expiresIn: Int(config.accessTokenTTL),
      user: try user.dto
    )
  }

  static func generateRefreshToken() -> String {
    Data((0..<32).map { _ in UInt8.random(in: .min ... .max) }).base64URLEncodedString()
  }

  static func hash(_ token: String) -> String {
    SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

extension Data {
  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
