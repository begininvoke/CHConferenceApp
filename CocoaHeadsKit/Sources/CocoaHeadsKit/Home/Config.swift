//
//  Config.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/7/25.
//

import StoreKit

struct Config {
  @MainActor
  private(set) static var isTestflightOrDebug = false

  @MainActor
  static func fetchEnvironment() async {
    do {
      let transaction = try await AppTransaction.shared
      switch transaction {
      case .unverified(let signedType, _):
        isTestflightOrDebug = signedType.environment != .production
      case .verified(let signedType):
        isTestflightOrDebug = signedType.environment != .production
      }
    } catch {
      var isSimulatorOrTestFlight: Bool {
        // TODO: Come up with a non-deprecated way to do this that actually works
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
          return false
        }
        return path.contains("CoreSimulator") || path.contains("sandboxReceipt")
      }
      isTestflightOrDebug = isSimulatorOrTestFlight
    }
  }
}
