//
//  AttestDTOs.swift
//
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import Foundation

/// Response of `POST /attest/challenge`. The challenge is single-use and
/// short-lived; the client embeds it in the attestation or assertion it
/// produces next.
public struct AttestChallengeResponse: Codable, Equatable, Sendable {
  public init(challenge: String, expiresIn: Int) {
    self.challenge = challenge
    self.expiresIn = expiresIn
  }

  /// Base64-encoded random challenge bytes.
  public let challenge: String
  /// Seconds until the challenge expires.
  public let expiresIn: Int
}

/// Body of `POST /attest/key` — registers an App Attest key with the server.
public struct AttestKeyRegistrationRequest: Codable, Equatable, Sendable {
  public init(keyId: String, attestation: String, challenge: String) {
    self.keyId = keyId
    self.attestation = attestation
    self.challenge = challenge
  }

  /// The App Attest key identifier (base64) from `DCAppAttestService.generateKey`.
  public let keyId: String
  /// Base64-encoded CBOR attestation object from
  /// `DCAppAttestService.attestKey(_:clientDataHash:)`, where `clientDataHash`
  /// is SHA-256 of the raw challenge bytes.
  public let attestation: String
  /// The base64 challenge previously issued by `POST /attest/challenge`.
  public let challenge: String
}
