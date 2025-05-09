//
//  Creator.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/1/25.
//

// TODO: Create a way for chapter leaders to create events on the app

import SwiftUI

struct Creator: View {

  @State private var recordName: String = ""
  @State private var hasAccess: String = ""
  @State private var isLoading = false

  var body: some View {
    VStack {
      Text("id: \(recordName)")
      Text("is chapter leader: \(hasAccess)")
      if isLoading {
        ProgressView()
      }

      Button("copy id") {
        UIPasteboard.general.string = recordName
      }
    }
    .task {
      isLoading = true
      async let name: Void = fetchRecordName()
      async let access: Void = fetchLeaderAccess()
      let _ = await [name, access]
      isLoading = false
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
      hasAccess = fetchedAccess ? "yes" : "no"
    } catch {
      hasAccess = "catch no"
    }
  }
}
