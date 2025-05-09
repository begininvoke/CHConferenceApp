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
      await Config.fetchEnvironment()
      await fetchData()
    }
  }

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

// TODO: Break things out from CocoaHeadsKit specifically for the AppClip – size reduction is important
public struct AppClipView: View {
  public init() {}

  enum ViewState {
    case loaded(Event)
    case error
    case loading
  }

  @State private var state = ViewState.loading

  public var body: some View {
    VStack {
      switch state {
      case .loading:
        ProgressView()
      case .loaded(let event):
        EventDetail(event: event)
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
      await Config.fetchEnvironment()
      await fetchData()
    }
  }

  private func fetchData() async {
    state = .loading
    do {
      let chapters = try await CloudKitService().fetchData()
      guard
        let event = chapters.first(where: {
          !$0.events.isEmpty
        })?.events.first
      else {
        state = .error
        return
      }

      state = .loaded(event)
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
        HStack {
          NavigationTitle("Eventos")
          Spacer()
          NavigationLink {
            Creator()
          } label: {
            Image(systemName: "gearshape")
              .font(.title)
          }
        }
        .padding()
        ChapterSelectionView(
          selectedChapter: $selectedChapter,
          availableChapters: chapters
        )
        EventList(events: selectedChapter?.events ?? [])
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

extension UIApplication {
  var isAppClip: Bool {
    Bundle.main.isAppClip
  }
}

extension Bundle {
  var isAppClip: Bool {
    infoDictionary?["NSAppClip"] != nil
  }
}
