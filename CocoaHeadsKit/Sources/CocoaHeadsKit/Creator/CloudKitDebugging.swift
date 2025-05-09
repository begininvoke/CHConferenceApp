//
//  CloudKitDebugging.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

import SwiftUI

struct CloudKitDebugging: View {

  @State private var recordName: String = ""
  @State private var hasAccess: String = ""

  var body: some View {
    List {
      Section {
        Text("id: \(recordName)")
        Text("is chapter leader: \(hasAccess)")
        Button("Copy ID") {
          UIPasteboard.general.string = recordName
        }
      }
    }
    .task {
      async let name: Void = fetchRecordName()
      async let access: Void = fetchLeaderAccess()
      let _ = await [name, access]
    }
  }

  func fetchRecordName() async {
    let service = CloudKitService()
    do {
      let id = try await service.fetchUserRecordID()
      recordName = id
    } catch {
      recordName = "fetch error - are you logged in icloud?"
    }
  }

  func fetchLeaderAccess() async {
    let service = CloudKitService()
    do {
      let fetchedAccess = try await service.hasLeaderAccess()
      hasAccess = fetchedAccess ? "yes" : "no?"
    } catch {
      hasAccess = "no"
    }
  }
}
