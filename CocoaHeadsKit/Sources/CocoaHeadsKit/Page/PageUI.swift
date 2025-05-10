//
//  UI.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

indirect enum UI: Codable, Identifiable, Sendable {
  case home(HomeUI)
  case eventDetail([EventDetailUI])

  var id: String {
    switch self {
    case .home(let homeUI):
      "page-ui-" + homeUI.id
    case .eventDetail(let eventDetailUI):
      "page-ui-" + String(eventDetailUI.map(\.id).joined().hashValue)
    }
  }
}
