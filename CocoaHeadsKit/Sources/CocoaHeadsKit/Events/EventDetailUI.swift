//
//  EventDetailUI.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/7/25.
//

import SwiftUI

indirect enum EventDetailUI: Codable {
  case card(title: String?, edges: Edge.Set, insetBy: CGFloat?, ui: [EventDetailUI])
  case carousel(ui: [EventDetailUI])
  // TODO: Action -> openURL instead of direct URL
  case callToAction(title: String, url: URL, systemImage: String?)
  case caption(text: String)
  case divider
  case link(URL, title: String?)
  case subtitle(String)
  case text(String)
  case titleSubtitle(title: String, subtitle: String, systemImage: String)
  case vstack(ui: [EventDetailUI])
}

// MARK: Identifiable

extension EventDetailUI: Identifiable {
  var id: String {
    switch self {
    case .card(let title, let edges, let insetBy, let ui):
      return "card-\(title ?? "nil")-\(edges.rawValue)-\(insetBy ?? 0)-\(ui.map(\.id).joined(separator: ","))"
    case .carousel(let ui):
      return "carousel-\(ui.map(\.id).joined(separator: ","))"
    case .callToAction(let title, let url, let systemImage):
      return "callToAction-\(title)-\(url.absoluteString)-\(systemImage ?? "nil")"
    case .caption(let text):
      return "caption-\(text)"
    case .divider:
      return "divider"
    case .link(let url, let title):
      return "link-\(url.absoluteString)-\(title ?? "nil")"
    case .subtitle(let text):
      return "subtitle-\(text)"
    case .text(let text):
      return "text-\(text)"
    case .titleSubtitle(let title, let subtitle, let systemImage):
      return "titleSubtitle-\(title)-\(subtitle)-\(systemImage)"
    case .vstack(let ui):
      return "vstack-\(ui.map(\.id).joined(separator: ","))"
    }
  }
}

// MARK: Helper methods
extension EventDetailUI {
  static func card(title: String?, ui: [EventDetailUI]) -> EventDetailUI {
    return .card(title: title, edges: .all, insetBy: nil, ui: ui)
  }

  static func callToAction(title: String, url: URL) -> EventDetailUI {
    return .callToAction(title: title, url: url, systemImage: nil)
  }

  static func link(_ url: URL) -> EventDetailUI {
    return .link(url, title: nil)
  }

  static func speaker(name: String?, talk: String?) -> EventDetailUI {
    var string = ""
    if let name {
      string.append("**\(name)**\n")
    }
    if let talk {
      string.append("\(talk)")
    }
    return .subtitle(string)
  }
}
