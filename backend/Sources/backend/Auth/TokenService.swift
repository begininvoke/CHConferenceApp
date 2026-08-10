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
import Vapor

/// Issues and rotates the backend's own session tokens (§5 of the auth spec).
struct TokenService: Sendable {
  /// Issues an access-token + refresh-token pair for a user. Only the SHA-256
  /// hash of the refresh token is persisted.
  func issueTokenPair(for user: User, on req: Request) async throws -> TokenResponse {
    let config = req.authConfiguration
    let userID = try user.requireID()

    let now = Date()
    let payload = AccessTokenPayload(
      subject: SubjectClaim(value: userID.uuidString),
      expiration: ExpirationClaim(value: now.addingTimeInterval(config.accessTokenTTL)),
      issuedAt: IssuedAtClaim(value: now),
      role: user.role
    )
    let accessToken = try await req.jwt.sign(payload)

    let rawRefreshToken = Self.generateRefreshToken()
    let record = RefreshToken(
      userID: userID,
      tokenHash: Self.hash(rawRefreshToken),
      expiresAt: now.addingTimeInterval(config.refreshTokenTTL)
    )
    try await record.save(on: req.db)

    return TokenResponse(
      accessToken: accessToken,
      refreshToken: rawRefreshToken,
      expiresIn: Int(config.accessTokenTTL),
      user: try user.dto
    )
  }

  /// Single-use rotation: revokes the presented refresh token and issues a new
  /// pair. Rejects unknown, revoked, or expired tokens.
  func rotate(refreshToken raw: String, on req: Request) async throws -> TokenResponse {
    let record = try await validRecord(for: raw, on: req.db)
    record.revoked = true
    try await record.save(on: req.db)

    guard let user = try await User.find(record.$user.id, on: req.db) else {
      throw Abort(.unauthorized, reason: "Account no longer exists.")
    }
    return try await issueTokenPair(for: user, on: req)
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

  /// Revokes every refresh token belonging to a user (account deletion).
  func revokeAll(for userID: UUID, on db: any Database) async throws {
    try await RefreshToken.query(on: db)
      .filter(\.$user.$id == userID)
      .set(\.$revoked, to: true)
      .update()
  }

  private func validRecord(for raw: String, on db: any Database) async throws -> RefreshToken {
    guard
      let record = try await RefreshToken.query(on: db)
        .filter(\.$tokenHash == Self.hash(raw))
        .first()
    else {
      throw Abort(.unauthorized, reason: "Unknown refresh token.")
    }
    guard !record.revoked else {
      throw Abort(.unauthorized, reason: "Refresh token revoked.")
    }
    guard record.expiresAt > Date() else {
      throw Abort(.unauthorized, reason: "Refresh token expired.")
    }
    return record
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
