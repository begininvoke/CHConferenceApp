//
//  AppAttestKey.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import Fluent
import Foundation

final class AppAttestKey: Model, @unchecked Sendable {
  static let schema = "app_attest_keys"

  @ID(key: .id)
  var id: UUID?

  /// Device-scoped; associated with a user after sign-in.
  @OptionalParent(key: "user_id")
  var user: User?

  /// The App Attest key identifier (base64), which is also the SHA-256 of the
  /// attested public key.
  @Field(key: "key_id")
  var keyId: String

  /// Attested P-256 public key (X9.63 representation), used to verify assertions.
  @Field(key: "public_key")
  var publicKey: Data

  /// Apple attestation receipt (kept for future fraud-risk assessment).
  @Field(key: "receipt")
  var receipt: Data

  /// Monotonic assertion counter; non-increasing values are rejected as replays.
  @Field(key: "sign_count")
  var signCount: Int

  /// Set when the owning account is deleted; revoked keys fail app-auth.
  @Field(key: "revoked")
  var revoked: Bool

  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date?

  init() {}

  init(
    id: UUID? = nil,
    userID: UUID? = nil,
    keyId: String,
    publicKey: Data,
    receipt: Data,
    signCount: Int = 0,
    revoked: Bool = false
  ) {
    self.id = id
    self.$user.id = userID
    self.keyId = keyId
    self.publicKey = publicKey
    self.receipt = receipt
    self.signCount = signCount
    self.revoked = revoked
  }
}
