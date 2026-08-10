//
//  ChallengeStore.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import Foundation
import Vapor

/// In-memory store of one-time App Attest challenges.
///
/// Challenges are short-lived and consumed on first use, so process-local
/// storage is sufficient for a single-instance deployment. A multi-instance
/// deployment would need to move this to the database or a shared cache.
actor ChallengeStore {
  static let challengeTTL: TimeInterval = 5 * 60

  private var challenges: [String: Date] = [:]

  /// Issues a new random challenge (32 bytes).
  func issue() -> Data {
    prune()
    let challenge = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
    challenges[challenge.base64EncodedString()] = Date().addingTimeInterval(Self.challengeTTL)
    return challenge
  }

  /// Consumes a challenge. Returns `false` for unknown, expired, or already
  /// used challenges.
  func consume(_ challenge: Data) -> Bool {
    prune()
    return challenges.removeValue(forKey: challenge.base64EncodedString()).map { $0 > Date() }
      ?? false
  }

  private func prune() {
    let now = Date()
    challenges = challenges.filter { $0.value > now }
  }
}

extension Application {
  private struct ChallengeStoreKey: StorageKey {
    typealias Value = ChallengeStore
  }

  var challengeStore: ChallengeStore {
    if let existing = storage[ChallengeStoreKey.self] {
      return existing
    }
    let store = ChallengeStore()
    storage[ChallengeStoreKey.self] = store
    return store
  }
}
