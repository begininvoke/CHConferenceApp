//
//  AccessTokenPayload.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import CocoaHeadsCore
import JWT
import Vapor

/// The backend-signed access token. Verified statelessly — no database hit on
/// the hot path.
struct AccessTokenPayload: JWTPayload, Authenticatable {
  enum CodingKeys: String, CodingKey {
    case subject = "sub"
    case expiration = "exp"
    case issuedAt = "iat"
    case role
  }

  /// The `User` id.
  let subject: SubjectClaim
  let expiration: ExpirationClaim
  let issuedAt: IssuedAtClaim
  let role: UserRole

  func verify(using algorithm: some JWTAlgorithm) async throws {
    try expiration.verifyNotExpired()
  }

  var userID: UUID {
    get throws {
      guard let id = UUID(uuidString: subject.value) else {
        throw Abort(.unauthorized, reason: "Malformed access token subject.")
      }
      return id
    }
  }
}

extension Request {
  /// The authenticated user for a Bearer-protected route. Rejects tokens whose
  /// account no longer exists or is soft-deleted.
  func authenticatedUser() async throws -> User {
    let payload = try auth.require(AccessTokenPayload.self)
    guard let user = try await User.find(payload.userID, on: db) else {
      throw Abort(.unauthorized, reason: "Account no longer exists.")
    }
    return user
  }
}
