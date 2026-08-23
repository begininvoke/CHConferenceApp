//
//  User.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import CocoaHeadsCore
import Fluent
import Foundation

final class User: Model, @unchecked Sendable {
  static let schema = "users"

  @ID(key: .id)
  var id: UUID?

  /// Apple `sub` claim. Stable per Apple ID + team.
  @Field(key: "apple_user_identifier")
  var appleUserIdentifier: String

  /// Only delivered on the user's first authorization. May be a Hide-My-Email relay.
  @OptionalField(key: "email")
  var email: String?

  /// Only delivered on the user's first authorization.
  @OptionalField(key: "full_name")
  var fullName: String?

  @Enum(key: "role")
  var role: UserRole

  /// Apple's refresh token from the authorization-code exchange, AES-GCM
  /// encrypted at rest. Needed to revoke Apple's grant on account deletion.
  @OptionalField(key: "apple_refresh_token")
  var appleRefreshToken: String?

  /// Soft-delete tombstone. PII is scrubbed when this is set; the row is
  /// hard-purged after the configured grace period.
  @Timestamp(key: "deleted_at", on: .delete)
  var deletedAt: Date?

  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date?

  @Timestamp(key: "updated_at", on: .update)
  var updatedAt: Date?

  init() {}

  init(
    id: UUID? = nil,
    appleUserIdentifier: String,
    email: String? = nil,
    fullName: String? = nil,
    role: UserRole = .user,
    appleRefreshToken: String? = nil
  ) {
    self.id = id
    self.appleUserIdentifier = appleUserIdentifier
    self.email = email
    self.fullName = fullName
    self.role = role
    self.appleRefreshToken = appleRefreshToken
  }
}

extension User {
  var dto: UserDTO {
    get throws {
      UserDTO(id: try requireID(), email: email, fullName: fullName, role: role)
    }
  }
}
