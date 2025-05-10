//
//  PageLoader.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/10/25.
//

import SwiftUI

struct PageLoader: View {

  @Environment(\.cloudKitService) var cloudKit
  @State private var pageList: [String] = []

  var body: some View {
    if pageList.isEmpty {
      Text("Fetching page list from CloudKit")
        .task {
          await fetchData()
        }
    } else {
      List(pageList, id: \.self) { pageTitle in
        NavigationLink(pageTitle) {
          Page(slug: pageTitle)
        }
      }
    }
  }

  func fetchData() async {
    do {
      pageList = try await cloudKit.fetchPageList().sorted()
      if pageList.isEmpty {
        print("no pages available")
      }
    } catch {
      // TODO: ?
    }
  }
}
