//
//  ServerEdge.swift
//  CocoaHeadsCore
//
//  Created by Mauricio on 8/4/26.
//

// Platform-neutral mirror of SwiftUI.Edge, so server-driven UI models
// compile on Linux and stay free of SwiftUI. Raw values match SwiftUI's,
// making the bridge to SwiftUI.Edge.Set a plain rawValue conversion.
public enum ServerEdge: Int8, CaseIterable, Sendable {
  case top, leading, bottom, trailing

  public struct Set: OptionSet, Sendable {
    public let rawValue: Int8

    public init(rawValue: Int8) {
      self.rawValue = rawValue
    }

    public init(_ e: ServerEdge) {
      self.init(rawValue: 1 << e.rawValue)
    }

    public static let top = Set(.top)
    public static let leading = Set(.leading)
    public static let bottom = Set(.bottom)
    public static let trailing = Set(.trailing)
    public static let horizontal: Set = [.leading, .trailing]
    public static let vertical: Set = [.top, .bottom]
    public static let all: Set = [.top, .leading, .bottom, .trailing]
  }
}
