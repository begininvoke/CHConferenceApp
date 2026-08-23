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
  static let defaultMaxEntries = 100_000

  private let maxEntries: Int
  private var challenges: [String: Date] = [:]

  init(maxEntries: Int = ChallengeStore.defaultMaxEntries) {
    self.maxEntries = maxEntries
  }

  /// Issues a new random challenge (32 bytes). The store is bounded: at
  /// capacity, the entry closest to expiry is evicted so a flood of challenge
  /// requests cannot grow memory without limit.
  func issue() -> Data {
    prune()
    if challenges.count >= maxEntries,
      let oldest = challenges.min(by: { $0.value < $1.value })
    {
      challenges.removeValue(forKey: oldest.key)
    }
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

  var count: Int { challenges.count }
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
