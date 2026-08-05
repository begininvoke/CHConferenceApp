//
//  ServerEdge+SwiftUI.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 8/4/26.
//

import CocoaHeadsCore
import SwiftUI

extension ServerEdge.Set {
  /// SwiftUI counterpart of this edge set, for use in view modifiers.
  public var swiftUI: SwiftUI.Edge.Set {
    .init(rawValue: rawValue)
  }
}

extension ServerEdge {
  /// SwiftUI counterpart of this edge.
  public var swiftUI: SwiftUI.Edge {
    switch self {
    case .top: .top
    case .leading: .leading
    case .bottom: .bottom
    case .trailing: .trailing
    }
  }
}
