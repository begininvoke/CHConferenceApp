//
//  Chapter.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/1/25.
//

import CloudKit
import Foundation

// TODO: Move to a separate package, and then rework entirely for a server-driven UI approach
struct Chapter: Identifiable, Sendable {
  var id: String { title }  // There's a unique identifier on CKRecord
  let title: String
  var events: [Event]
}

extension Chapter: Equatable {
  static func == (lhs: Chapter, rhs: Chapter) -> Bool {
    lhs.id == rhs.id
  }
}

public struct Event: Identifiable, Sendable {
  public var id: String { title }  // There's a unique identifier on CKRecord
  let title: String
  let location: CLLocation
  let date: Date
  let rsvpURL: URL
}

struct Talk {
  let speaker: String
  let title: String
}

extension Event {
  public static var mock: Self {
    Event(
      title: "65º CocoaHeads SP @ Apple Developer Academy Mackenzie",
      location: .init(latitude: 12.3456, longitude: 12.3456),
      date: .now,
      rsvpURL: URL(string: "https://meetup.com")!
    )
  }
}

extension Chapter {
  init?(from record: CKRecord) {
    self.events = []
    guard let name = record["name"] as? String else { return nil }
    self.title = name
  }
}

extension Event {
  init?(from record: CKRecord) {
    guard
      let title = record["title"] as? String,
      let location: CLLocation = record["location"] as? CLLocation,
      let date = record["date"] as? Date
    else {
      return nil
    }

    self.title = title
    self.location = location
    self.date = date
    // TODO: Add to CloudKit
    self.rsvpURL = URL(string: "https://apple.com")!
  }
}
