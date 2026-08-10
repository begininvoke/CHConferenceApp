//
//  AttestController.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import CocoaHeadsCore
import Fluent
import Vapor

/// App Attest registration endpoints (§6, phase 1). These sit behind the API
/// key gate only — a device cannot assert before it has registered a key.
struct AttestController: RouteCollection {
  func boot(routes: any RoutesBuilder) throws {
    let attest = routes.grouped("attest")
    attest.post("challenge", use: challenge)
    attest.post("key", use: registerKey)
  }

  @Sendable
  func challenge(req: Request) async throws -> AttestChallengeResponse {
    let challenge = await req.application.challengeStore.issue()
    return AttestChallengeResponse(
      challenge: challenge.base64EncodedString(),
      expiresIn: Int(ChallengeStore.challengeTTL)
    )
  }

  @Sendable
  func registerKey(req: Request) async throws -> HTTPStatus {
    let config = req.authConfiguration
    guard let appID = config.appAttestAppID else {
      throw Abort(.serviceUnavailable, reason: "App Attest is not configured.")
    }

    let registration = try req.content.decode(AttestKeyRegistrationRequest.self)
    guard
      let keyId = Data(base64Encoded: registration.keyId),
      let attestation = Data(base64Encoded: registration.attestation),
      let challenge = Data(base64Encoded: registration.challenge)
    else {
      throw Abort(.badRequest, reason: "Malformed base64 payload.")
    }

    guard await req.application.challengeStore.consume(challenge) else {
      throw Abort(.unauthorized, reason: "Unknown or expired App Attest challenge.")
    }

    let verifier = AppAttestVerifier(environment: config.appAttestEnvironment)
    let attested: AppAttestVerifier.AttestedKey
    do {
      attested = try await verifier.verifyAttestation(
        attestation,
        keyId: keyId,
        challenge: challenge,
        appID: appID
      )
    } catch {
      req.logger.info("App Attest attestation rejected: \(error)")
      throw Abort(.unauthorized, reason: "Invalid App Attest attestation.")
    }

    if let existing = try await AppAttestKey.query(on: req.db)
      .filter(\.$keyId == registration.keyId)
      .first()
    {
      guard existing.publicKey == attested.publicKey, !existing.revoked else {
        throw Abort(.conflict, reason: "Key id is already registered.")
      }
      return .ok
    }

    try await AppAttestKey(
      keyId: registration.keyId,
      publicKey: attested.publicKey,
      receipt: attested.receipt,
      signCount: attested.signCount
    ).save(on: req.db)
    return .created
  }
}

extension AttestChallengeResponse: @retroactive RequestDecodable {}
extension AttestChallengeResponse: @retroactive ResponseEncodable {}
extension AttestChallengeResponse: @retroactive AsyncRequestDecodable {}
extension AttestChallengeResponse: @retroactive AsyncResponseEncodable {}
extension AttestChallengeResponse: @retroactive Content {}
