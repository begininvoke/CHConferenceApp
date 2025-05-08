//
//  Chapter.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/1/25.
//

import CloudKit
import Foundation

// TODO: Move to a separate package, and then rework entirely for a server-driven UI approach
struct Chapter: Identifiable {
  var id: String { title }  // There's a unique identifier on CKRecord
  let title: String
  var events: [Event]
}

extension Chapter: Equatable {
  static func == (lhs: Chapter, rhs: Chapter) -> Bool {
    lhs.id == rhs.id
  }
}

struct Event: Identifiable {
  var id: String { title }  // There's a unique identifier on CKRecord
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
  static var mock: Self {
    Event(
      title: "65º CocoaHeads SP @ Apple Developer Academy Mackenzie",
      location: .init(latitude: 12.3456, longitude: 12.3456),
      date: .now,
      rsvpURL: URL(string: "https://meetup.com")!
    )
  }
}

// TODO: Make a service protocol so we reach for a local mock when running debug builds
final class CloudKitService {
  // TODO: Mock for testing
  let container = CKContainer(identifier: "iCloud.br.com.cocoaHeads.conf")

  // TODO: Some form of persistency/caching
  func fetchData() async throws -> [Chapter] {
    let database = container.publicCloudDatabase
    let chapterRecords = try await database.records(
      matching: .init(
        recordType: "Chapter",
        predicate: NSPredicate(value: true)
      )
    )
    var chapters: [Chapter] = []

    let (results, _) = chapterRecords
    for (_, result) in results {
      switch result {
      case .success(let chapterRecord):
        var chapter = Chapter(from: chapterRecord)
        let eventRecords = chapterRecord["events"] as? [CKRecord.Reference]
        for eventReference in eventRecords ?? [] {
          // taskgroup
          let eventRecord = try await database.record(for: eventReference.recordID)
          if let event = Event(from: eventRecord) {
            chapter?.events.append(event)
          }
        }
        if let chapter {
          chapters.append(chapter)
        }
      case .failure(let error):
        print(error)
      }
    }

    return chapters
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
