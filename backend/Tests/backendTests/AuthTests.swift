import Crypto
import Foundation
import Testing

@testable import backend

@Suite("CBOR decoding")
struct CBORTests {
  @Test("Decodes the attestation object shape")
  func attestationShape() throws {
    // {"fmt": "test", "attStmt": {"x5c": [h'0102']}, "authData": h'AABB'}
    var bytes: [UInt8] = [0xA3]
    bytes += [0x63] + Array("fmt".utf8)
    bytes += [0x64] + Array("test".utf8)
    bytes += [0x67] + Array("attStmt".utf8)
    bytes += [0xA1, 0x63] + Array("x5c".utf8) + [0x81, 0x42, 0x01, 0x02]
    bytes += [0x68] + Array("authData".utf8)
    bytes += [0x42, 0xAA, 0xBB]

    let value = try CBOR.decode(Data(bytes))
    #expect(value["fmt"]?.textValue == "test")
    #expect(value["attStmt"]?["x5c"]?.arrayValue?.first?.bytesValue == Data([0x01, 0x02]))
    #expect(value["authData"]?.bytesValue == Data([0xAA, 0xBB]))
  }

  @Test("Decodes multi-byte lengths")
  func longLengths() throws {
    let payload = Data(repeating: 0x7F, count: 300)
    let bytes: [UInt8] = [0x59, 0x01, 0x2C] + payload  // bytes(300)
    let value = try CBOR.decode(Data(bytes))
    #expect(value.bytesValue == payload)
  }

  @Test("Rejects truncated input")
  func truncated() {
    #expect(throws: CBOR.DecodingError.self) {
      try CBOR.decode(Data([0x42, 0x01]))  // bytes(2) with only 1 byte present
    }
  }
}

@Suite("Token service")
struct TokenServiceTests {
  @Test("Refresh tokens are unique and URL-safe")
  func refreshTokenGeneration() {
    let a = TokenService.generateRefreshToken()
    let b = TokenService.generateRefreshToken()
    #expect(a != b)
    #expect(!a.contains("+") && !a.contains("/") && !a.contains("="))
  }

  @Test("Hashing is stable and hides the token")
  func hashing() {
    let token = "some-refresh-token"
    let hash = TokenService.hash(token)
    #expect(hash == TokenService.hash(token))
    #expect(hash != TokenService.hash("other-token"))
    #expect(hash.count == 64)
    #expect(!hash.contains(token))
  }
}

@Suite("Token encryption")
struct TokenEncryptionTests {
  @Test("Round-trips and never stores plaintext")
  func roundTrip() throws {
    let encryption = TokenEncryption(key: SymmetricKey(size: .bits256))
    let secret = "apple-refresh-token-value"
    let encrypted = try encryption.encrypt(secret)
    #expect(!encrypted.contains(secret))
    #expect(try encryption.decrypt(encrypted) == secret)
  }

  @Test("Distinct keys cannot decrypt each other's output")
  func wrongKey() throws {
    let a = TokenEncryption(key: SymmetricKey(size: .bits256))
    let b = TokenEncryption(key: SymmetricKey(size: .bits256))
    let encrypted = try a.encrypt("secret")
    #expect(throws: (any Error).self) {
      try b.decrypt(encrypted)
    }
  }
}

@Suite("App Attest verification")
struct AppAttestVerifierTests {
  static let appID = "TEAMID1234.com.cocoaheadsbr.conf"

  /// Builds WebAuthn-style authenticator data for assertions (37 bytes).
  private func assertionAuthData(appID: String, signCount: UInt32) -> Data {
    var data = Data(SHA256.hash(data: Data(appID.utf8)))
    data.append(0x40)
    data.append(contentsOf: withUnsafeBytes(of: signCount.bigEndian, Array.init))
    return data
  }

  /// CBOR-encodes {"signature": ..., "authenticatorData": ...}.
  private func assertionCBOR(signature: Data, authenticatorData: Data) -> Data {
    func bytes(_ data: Data) -> Data {
      precondition(data.count < 256)
      return data.count <= 23 ? Data([0x40 | UInt8(data.count)]) + data : Data([0x58, UInt8(data.count)]) + data
    }
    func text(_ string: String) -> Data {
      Data([0x60 | UInt8(string.utf8.count)]) + Data(string.utf8)
    }
    return Data([0xA2]) + text("signature") + bytes(signature)
      + text("authenticatorData") + bytes(authenticatorData)
  }

  @Test("Accepts a valid assertion and returns the new sign count")
  func validAssertion() throws {
    let key = P256.Signing.PrivateKey()
    let clientDataHash = Data(SHA256.hash(data: Data("hello".utf8)))
    let authData = assertionAuthData(appID: Self.appID, signCount: 7)
    let nonce = Data(SHA256.hash(data: authData + clientDataHash))
    let signature = try key.signature(for: nonce)

    let verifier = AppAttestVerifier(environment: .development)
    let newCount = try verifier.verifyAssertion(
      assertionCBOR(signature: signature.derRepresentation, authenticatorData: authData),
      publicKey: key.publicKey.x963Representation,
      clientDataHash: clientDataHash,
      appID: Self.appID,
      storedSignCount: 3
    )
    #expect(newCount == 7)
  }

  @Test("Rejects a non-increasing sign count")
  func replayedAssertion() throws {
    let key = P256.Signing.PrivateKey()
    let clientDataHash = Data(SHA256.hash(data: Data("hello".utf8)))
    let authData = assertionAuthData(appID: Self.appID, signCount: 3)
    let nonce = Data(SHA256.hash(data: authData + clientDataHash))
    let signature = try key.signature(for: nonce)

    let verifier = AppAttestVerifier(environment: .development)
    #expect(throws: AppAttestVerifier.VerificationError.nonIncreasingSignCount) {
      try verifier.verifyAssertion(
        assertionCBOR(signature: signature.derRepresentation, authenticatorData: authData),
        publicKey: key.publicKey.x963Representation,
        clientDataHash: clientDataHash,
        appID: Self.appID,
        storedSignCount: 3
      )
    }
  }

  @Test("Rejects a tampered body (signature mismatch)")
  func tamperedBody() throws {
    let key = P256.Signing.PrivateKey()
    let authData = assertionAuthData(appID: Self.appID, signCount: 1)
    let nonce = Data(SHA256.hash(data: authData + Data(SHA256.hash(data: Data("original".utf8)))))
    let signature = try key.signature(for: nonce)

    let verifier = AppAttestVerifier(environment: .development)
    #expect(throws: AppAttestVerifier.VerificationError.invalidSignature) {
      try verifier.verifyAssertion(
        assertionCBOR(signature: signature.derRepresentation, authenticatorData: authData),
        publicKey: key.publicKey.x963Representation,
        clientDataHash: Data(SHA256.hash(data: Data("tampered".utf8))),
        appID: Self.appID,
        storedSignCount: 0
      )
    }
  }

  @Test("Rejects an assertion for a different app id")
  func wrongAppID() throws {
    let key = P256.Signing.PrivateKey()
    let clientDataHash = Data(SHA256.hash(data: Data("hello".utf8)))
    let authData = assertionAuthData(appID: "OTHERTEAM.com.example", signCount: 1)
    let nonce = Data(SHA256.hash(data: authData + clientDataHash))
    let signature = try key.signature(for: nonce)

    let verifier = AppAttestVerifier(environment: .development)
    #expect(throws: AppAttestVerifier.VerificationError.rpIdMismatch) {
      try verifier.verifyAssertion(
        assertionCBOR(signature: signature.derRepresentation, authenticatorData: authData),
        publicKey: key.publicKey.x963Representation,
        clientDataHash: clientDataHash,
        appID: Self.appID,
        storedSignCount: 0
      )
    }
  }

  @Test("Parses attestation authenticator data")
  func authenticatorDataParsing() throws {
    let credentialId = Data((0..<32).map { UInt8($0) })
    var data = Data(SHA256.hash(data: Data(Self.appID.utf8)))
    data.append(0x40)
    data.append(contentsOf: [0, 0, 0, 0])
    data.append(AppAttestVerifier.expectedAAGUID(for: .development))
    data.append(contentsOf: [0, 32])
    data.append(credentialId)

    let parsed = try AuthenticatorData(data)
    #expect(parsed.rpIdHash == Data(SHA256.hash(data: Data(Self.appID.utf8))))
    #expect(parsed.signCount == 0)
    #expect(parsed.aaguid == Data("appattestdevelop".utf8))
    #expect(parsed.credentialId == credentialId)
  }

  @Test("Extracts the nonce from the certificate extension DER")
  func nonceExtraction() throws {
    let nonce = Data((0..<32).map { UInt8($0 &* 3) })
    // SEQUENCE { [1] { OCTET STRING (32) } }
    let der: [UInt8] = [0x30, 0x24, 0xA1, 0x22, 0x04, 0x20] + nonce
    let extracted = try AppAttestVerifier.extractNonce(from: ArraySlice(der))
    #expect(extracted == nonce)
  }

  @Test("Production and development aaguids differ")
  func aaguids() {
    #expect(AppAttestVerifier.expectedAAGUID(for: .production).count == 16)
    #expect(AppAttestVerifier.expectedAAGUID(for: .development).count == 16)
    #expect(
      AppAttestVerifier.expectedAAGUID(for: .production)
        != AppAttestVerifier.expectedAAGUID(for: .development)
    )
  }
}

@Suite("Challenge store")
struct ChallengeStoreTests {
  @Test("Challenges are single-use")
  func singleUse() async {
    let store = ChallengeStore()
    let challenge = await store.issue()
    #expect(await store.consume(challenge))
    #expect(await store.consume(challenge) == false)
  }

  @Test("Unknown challenges are rejected")
  func unknown() async {
    let store = ChallengeStore()
    #expect(await store.consume(Data([1, 2, 3])) == false)
  }
}
