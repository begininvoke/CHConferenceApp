//
//  AccountPurgeService.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import Fluent
import NIOConcurrencyHelpers
import Vapor

/// Hard-purges soft-deleted accounts once their grace period
/// (`ACCOUNT_PURGE_GRACE_DAYS`) has elapsed: a sweep at boot, then every 12
/// hours (§8).
final class AccountPurgeService: LifecycleHandler {
  private let task: NIOLockedValueBox<Task<Void, Never>?> = .init(nil)

  static let sweepInterval: Duration = .seconds(12 * 60 * 60)

  func didBootAsync(_ application: Application) async throws {
    task.withLockedValue { value in
      value = Task {
        while !Task.isCancelled {
          await Self.purge(on: application)
          try? await Task.sleep(for: Self.sweepInterval)
        }
      }
    }
  }

  func shutdownAsync(_ application: Application) async {
    task.withLockedValue { $0?.cancel() }
  }

  static func purge(on application: Application) async {
    let graceDays = application.authConfiguration.accountPurgeGraceDays
    let cutoff = Date().addingTimeInterval(-TimeInterval(graceDays) * 24 * 60 * 60)

    // Expired refresh tokens are dead weight; delete them. Revoked-but-
    // unexpired rows are kept — reuse detection in `TokenService.rotate`
    // depends on finding them.
    do {
      try await RefreshToken.query(on: application.db)
        .filter(\.$expiresAt < Date())
        .delete()
    } catch {
      application.logger.error("Expired refresh-token sweep failed: \(error)")
    }

    do {
      let expired = try await User.query(on: application.db)
        .withDeleted()
        .filter(\.$deletedAt < cutoff)
        .all()
      guard !expired.isEmpty else { return }
      for user in expired {
        try await user.delete(force: true, on: application.db)
      }
      application.logger.info("Purged \(expired.count) soft-deleted account(s).")
    } catch {
      application.logger.error("Account purge sweep failed: \(error)")
    }
  }
}
