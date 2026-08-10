//
//  AppAttestVerifier.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import Crypto
import Foundation
import SwiftASN1
import X509

/// Server-side verification of Apple App Attest attestation objects and
/// assertions, per
/// https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
///
/// There is no first-party Swift server library for this; the CBOR decoding
/// lives in `CBOR.swift` and the X.509 chain validation uses swift-certificates
/// against Apple's published App Attest root CA.
struct AppAttestVerifier: Sendable {
  /// https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem
  static let appleAppAttestRootCA = """
    -----BEGIN CERTIFICATE-----
    MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
    JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
    QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
    Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
    biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
    bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
    NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
    Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
    MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
    CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
    53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
    oyFraWVIyd/dganmrduC1bmTBGwD
    -----END CERTIFICATE-----
    """

  /// OID of the credential certificate extension carrying the expected nonce.
  static let nonceExtensionOID: ASN1ObjectIdentifier = [1, 2, 840, 113_635, 100, 8, 2]

  enum VerificationError: Error, Equatable {
    case malformedAttestation
    case unexpectedFormat(String)
    case certificateChainInvalid
    case nonceMismatch
    case keyIdMismatch
    case rpIdMismatch
    case invalidSignCount
    case invalidAAGUID
    case credentialIdMismatch
    case malformedAssertion
    case invalidSignature
    case nonIncreasingSignCount
  }

  struct AttestedKey: Sendable {
    /// P-256 public key, X9.63 representation.
    let publicKey: Data
    let receipt: Data
    let signCount: Int
  }

  let environment: AuthConfiguration.AppAttestEnvironment

  /// Verifies an attestation object produced by
  /// `DCAppAttestService.attestKey(_:clientDataHash:)`, where the client data
  /// hash is SHA-256 of the raw challenge bytes.
  func verifyAttestation(
    _ attestation: Data,
    keyId: Data,
    challenge: Data,
    appID: String
  ) async throws -> AttestedKey {
    let object = try CBOR.decode(attestation)
    guard
      let fmt = object["fmt"]?.textValue,
      let attStmt = object["attStmt"],
      let authData = object["authData"]?.bytesValue,
      let x5c = attStmt["x5c"]?.arrayValue,
      let receipt = attStmt["receipt"]?.bytesValue,
      let credCertDER = x5c.first?.bytesValue
    else {
      throw VerificationError.malformedAttestation
    }
    guard fmt == "apple-appattest" else {
      throw VerificationError.unexpectedFormat(fmt)
    }

    // 1. Validate the certificate chain up to Apple's App Attest root CA.
    let credCert = try Certificate(derEncoded: Array(credCertDER))
    let intermediates = try x5c.dropFirst().map { item -> Certificate in
      guard let der = item.bytesValue else { throw VerificationError.malformedAttestation }
      return try Certificate(derEncoded: Array(der))
    }
    let root = try Certificate(pemEncoded: Self.appleAppAttestRootCA)
    var verifier = Verifier(rootCertificates: CertificateStore([root])) {
      RFC5280Policy()
    }
    let result = await verifier.validate(
      leaf: credCert,
      intermediates: CertificateStore(intermediates)
    )
    guard case .validCertificate = result else {
      throw VerificationError.certificateChainInvalid
    }

    // 2/3. Recreate the nonce and compare against the credential certificate's
    // 1.2.840.113635.100.8.2 extension.
    let clientDataHash = Data(SHA256.hash(data: challenge))
    let nonce = Data(SHA256.hash(data: authData + clientDataHash))
    guard
      let nonceExtension = credCert.extensions[oid: Self.nonceExtensionOID],
      try Self.extractNonce(from: nonceExtension.value) == nonce
    else {
      throw VerificationError.nonceMismatch
    }

    // 4. The key identifier must be the SHA-256 of the attested public key.
    guard let publicKey = P256.Signing.PublicKey(credCert.publicKey) else {
      throw VerificationError.malformedAttestation
    }
    guard Data(SHA256.hash(data: publicKey.x963Representation)) == keyId else {
      throw VerificationError.keyIdMismatch
    }

    // 5–9. Authenticator data checks: RP ID hash, initial counter, aaguid,
    // credential id.
    let parsed = try AuthenticatorData(authData)
    guard parsed.rpIdHash == Data(SHA256.hash(data: Data(appID.utf8))) else {
      throw VerificationError.rpIdMismatch
    }
    guard parsed.signCount == 0 else {
      throw VerificationError.invalidSignCount
    }
    guard parsed.aaguid == Self.expectedAAGUID(for: environment) else {
      throw VerificationError.invalidAAGUID
    }
    guard parsed.credentialId == keyId else {
      throw VerificationError.credentialIdMismatch
    }

    return AttestedKey(
      publicKey: publicKey.x963Representation,
      receipt: receipt,
      signCount: Int(parsed.signCount)
    )
  }

  /// Verifies a per-request assertion produced by
  /// `DCAppAttestService.generateAssertion(_:clientDataHash:)`.
  /// Returns the new sign count to persist.
  func verifyAssertion(
    _ assertion: Data,
    publicKey x963: Data,
    clientDataHash: Data,
    appID: String,
    storedSignCount: Int
  ) throws -> Int {
    let object = try CBOR.decode(assertion)
    guard
      let signature = object["signature"]?.bytesValue,
      let authData = object["authenticatorData"]?.bytesValue
    else {
      throw VerificationError.malformedAssertion
    }

    let publicKey = try P256.Signing.PublicKey(x963Representation: x963)
    let nonce = Data(SHA256.hash(data: authData + clientDataHash))
    guard
      let ecdsaSignature = try? P256.Signing.ECDSASignature(derRepresentation: signature),
      publicKey.isValidSignature(ecdsaSignature, for: nonce)
    else {
      throw VerificationError.invalidSignature
    }

    guard authData.count >= 37 else {
      throw VerificationError.malformedAssertion
    }
    let rpIdHash = Data(authData.prefix(32))
    guard rpIdHash == Data(SHA256.hash(data: Data(appID.utf8))) else {
      throw VerificationError.rpIdMismatch
    }

    let signCount = authData.dropFirst(33).prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    guard signCount > storedSignCount else {
      throw VerificationError.nonIncreasingSignCount
    }
    return Int(signCount)
  }

  static func expectedAAGUID(for environment: AuthConfiguration.AppAttestEnvironment) -> Data {
    switch environment {
    case .production:
      // "appattest" padded with 7 zero bytes.
      return Data("appattest".utf8) + Data(repeating: 0, count: 7)
    case .development:
      return Data("appattestdevelop".utf8)
    }
  }

  /// The nonce extension value is `SEQUENCE { [1] { OCTET STRING (32) } }`.
  static func extractNonce(from extensionValue: ArraySlice<UInt8>) throws -> Data {
    let root = try DER.parse(Array(extensionValue))
    guard case .constructed(let children) = root.content else {
      throw VerificationError.nonceMismatch
    }
    for child in children {
      switch child.content {
      case .primitive(let bytes) where bytes.count == 32:
        return Data(bytes)
      case .constructed(let inner):
        for node in inner {
          if case .primitive(let bytes) = node.content, bytes.count == 32 {
            return Data(bytes)
          }
        }
      default:
        continue
      }
    }
    throw VerificationError.nonceMismatch
  }
}

/// WebAuthn-style authenticator data with attested credential data, as used by
/// App Attest attestation objects.
struct AuthenticatorData {
  let rpIdHash: Data
  let flags: UInt8
  let signCount: UInt32
  let aaguid: Data
  let credentialId: Data

  init(_ data: Data) throws {
    // rpIdHash(32) | flags(1) | signCount(4) | aaguid(16) | credIdLen(2) | credId
    guard data.count >= 55 else {
      throw AppAttestVerifier.VerificationError.malformedAttestation
    }
    let bytes = [UInt8](data)
    rpIdHash = Data(bytes[0..<32])
    flags = bytes[32]
    signCount = bytes[33..<37].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    aaguid = Data(bytes[37..<53])
    let credIdLength = Int(bytes[53]) << 8 | Int(bytes[54])
    guard bytes.count >= 55 + credIdLength else {
      throw AppAttestVerifier.VerificationError.malformedAttestation
    }
    credentialId = Data(bytes[55..<(55 + credIdLength)])
  }
}
