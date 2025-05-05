//
//  Home.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

// TODO: Kill all of this, replace with server-driven logic and tca

public struct Home: View {
  public init() {}

  enum ViewState {
    case loaded([Chapter])
    case error
    case loading
  }

  @State private var state = ViewState.loading

  public var body: some View {
    VStack {
      switch state {
      case .loading:
        ProgressView()
      case .loaded(let chapters):
        LoadedHome(chapters: chapters)
      case .error:
        ContentUnavailableView {
          Text("Algum erro ocorreu")
        } actions: {
          Button {
            Task {
              await fetchData()
            }
          } label: {
            Text("Tentar novamente")
          }
        }
      }
    }
    .task {
      await fetchData()
    }
  }

  let service = CloudKitService()

  private func fetchData() async {
    state = .loading
    do {
      let chapters = try await CloudKitService().fetchData()
      state = .loaded(chapters)
    } catch {
      state = .error
    }
  }
}

struct LoadedHome: View {

  let chapters: [Chapter]

  // TODO: Chapter selection logic
  // The default chapter should be: The first one from the list that has a future event
  // When the user picks a different chapter, their preference should be saved and that should be the first one instead
  @State private var selectedChapter: Chapter?

  var body: some View {
    NavigationStack {
      ScrollView {
        EventList(events: selectedChapter?.events ?? [])
        ChapterSelectionView(
          selectedChapter: $selectedChapter,
          availableChapters: chapters
        )
        .padding(.bottom)
      }
    }
    .onAppear {
      selectedChapter = chapters.first(where: {
        !$0.events.isEmpty
      })
    }
    .animation(.default, value: selectedChapter)
  }
}

#Preview {
  Home()
}
