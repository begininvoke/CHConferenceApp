//
//  Page.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

import SwiftUI

struct Page: View {

  @Environment(\.cloudKitService) var cloudKit

  enum ViewState {
    case loaded([UI])
    case loading
  }

  let slug: String
  @State private var viewState: ViewState = .loading

  var body: some View {
    switch viewState {
    case .loaded(let ui):
      PageRenderer(ui: ui)
    case .loading:
      ProgressView()
        .task {
          await fetchPage()
        }
    }
  }

  func fetchPage() async {
    do {
      let ui = try await cloudKit.fetchPage(slug: slug)
      viewState = .loaded(ui)
    } catch {
      // TODO: Handle error
    }
  }
}

struct PageRenderer: View {
  let ui: [UI]

  var body: some View { ForEach(ui) { render($0) } }

  @ViewBuilder
  func render(_ ui: UI) -> some View {
    switch ui {
    case .home:
      Home()
    case .eventDetail(let eventDetailUI):
      EventDetailRenderer(ui: eventDetailUI)
    }
  }
}
