//
//  CloudKitService.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

import CloudKit
import Foundation
import SwiftUI

extension EnvironmentValues {
  @Entry var cloudKitService: CloudKitService = .init()
}

// TODO: Make a service protocol so we reach for a local mock when running debug builds
actor CloudKitService: Sendable {
  // TODO: Mock for testing
  let container = CKContainer(identifier: "iCloud.br.com.cocoaHeads.conf")

  fileprivate init() {}

  // TODO: Some form of persistency/caching
  // TODO: Break down in multiple steps - this is confusing as is
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
        try await withThrowingTaskGroup(of: CKRecord.self) { group in
          for eventReference in eventRecords ?? [] {
            group.addTask {
              try await database.record(for: eventReference.recordID)
            }
          }
          for try await record in group {
            if let event = Event(from: record) {
              chapter?.events.append(event)
            }
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

  func fetchUserRecordID() async throws -> String {
    let ckRecord = try await container.userRecordID()
    return ckRecord.recordName
  }

  private(set) var hasLeaderAccess = false

  @discardableResult
  func fetchLeaderAccess() async throws -> Bool {
    let database = container.publicCloudDatabase
    let (results, _) = try await database.records(
      matching: .init(
        recordType: "Leaders",
        predicate: NSPredicate(value: true)
      )
    )
    hasLeaderAccess = !results.isEmpty
    return hasLeaderAccess
  }

  // TODO: Create a PageService for these

  func createPage(
    slug: String,
    ui: [UI],
    with encoder: JSONEncoder = JSONEncoder()
  ) async throws {
    // TODO: Create page updating flow
    guard try await isSlugAvailable(slug) else {
      // TODO: throw error
      return
    }

    let database = container.publicCloudDatabase
    let record = CKRecord(recordType: "Page")
    let jsonUI = try encoder.encode(ui)
    record["ui"] = jsonUI
    try await database.save(record)
  }

  func isSlugAvailable(_ slug: String) async throws -> Bool {
    let titles = try await fetchPageList()
    return !titles.contains(slug)
  }

  // TODO: Caching
  func fetchPage(slug: String) async throws -> [UI] {
    // We need this until we add home to the database
    guard slug != "local-home" else {
      return [.home(.home)]
    }

    let database = container.publicCloudDatabase
    // TODO: Query specifically for the slug we need! This is *dumb*
    let (matchResults, _) = try await database.records(
      matching: .init(
        recordType: "Page",
        predicate: NSPredicate(value: true)
      )
    )

    for (_, result) in matchResults {
      switch result {
      case .success(let success):
        guard
          let pageSlug = success["slug"] as? String,
          slug == pageSlug,
          let pageJSON = success["ui"] as? String,
          let pageData = pageJSON.data(using: .utf8)
        else {
          // TODO: Force-update UI
          return [
            .eventDetail([
              .text("Atualize o app")
            ])
          ]
        }

        let decoder = LenientJSONDecoder()
        return try decoder.decode([UI].self, from: pageData)

      case .failure:
        continue
      }
    }

    return [
      .eventDetail([
        .text("Atualize o app")
      ])
    ]
  }

  func fetchPageList() async throws -> [String] {
    let database = container.publicCloudDatabase
    let (matchResults, _) = try await database.records(
      matching: .init(
        recordType: "Page",
        predicate: NSPredicate(value: true)
      )
    )
    var pageTitles: [String] = []
    for (_, result) in matchResults {
      switch result {
      case .success(let success):
        if let slug = success["slug"] as? String {
          pageTitles.append(slug)
        }
      case .failure:
        break
      }
    }

    return pageTitles
  }
}
