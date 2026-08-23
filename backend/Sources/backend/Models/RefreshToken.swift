//
//  RefreshToken.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import Fluent
import Foundation

final class RefreshToken: Model, @unchecked Sendable {
  static let schema = "refresh_tokens"

  @ID(key: .id)
  var id: UUID?

  @Parent(key: "user_id")
  var user: User

  /// SHA-256 hash of the opaque token. The raw value is never stored.
  @Field(key: "token_hash")
  var tokenHash: String

  @Field(key: "expires_at")
  var expiresAt: Date

  /// Set on logout, rotation, or account deletion.
  @Field(key: "revoked")
  var revoked: Bool

  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date?

  init() {}

  init(
    id: UUID? = nil,
    userID: UUID,
    tokenHash: String,
    expiresAt: Date,
    revoked: Bool = false
  ) {
    self.id = id
    self.$user.id = userID
    self.tokenHash = tokenHash
    self.expiresAt = expiresAt
    self.revoked = revoked
  }
}
