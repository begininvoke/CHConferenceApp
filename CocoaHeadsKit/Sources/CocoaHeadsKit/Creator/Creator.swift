//
//  Creator.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

import SwiftUI

struct Creator: View {

  enum Sheet: String, Identifiable {
    case chapterPicker
    case meetupScraper
    case templatePicker
    case createUIFromScratch

    var id: String { rawValue }
  }

  @State private var chapter: Chapter?
  @State private var textField: String = ""
  @State private var sheetState: Sheet?
  @State private var isLoading = false
  @State private var ui: [UI] = []
  @Environment(\.cloudKitService) var cloudKit
  @Environment(\.dismiss) var dismiss

  var body: some View {
    List {
      Section("Chapter") {
        Button(chapter?.title ?? "Pick a chapter") {
          sheetState = .chapterPicker
        }
      }

      Section("Title") {
        TextField("Write a page title", text: $textField)
      }

      Section("Content") {
        Button("Fetch from Meetup.com") {
          sheetState = .meetupScraper
        }

        Button("Use a pre-made template") {
          sheetState = .templatePicker
        }

        Button("Create from scratch") {
          sheetState = .createUIFromScratch
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button {
          Task {
            await savePage()
          }
        } label: {
          if isLoading {
            ProgressView()
          } else {
            Text("Save")
          }
        }
      }
    }
    .sheet(item: $sheetState) { sheet in
      switch sheet {
      case .chapterPicker:
        ChapterPicker(chapter: $chapter)
      case .meetupScraper:
        NavigationStack {
          MeetupCreator(ui: $ui)
        }
      case .templatePicker:
        Text("TO-DO: Build a bunch of templates and allow leaders to pick from them")
      case .createUIFromScratch:
        Text("TO-DO: Build a UI creator")
      }
    }
  }

  func savePage() async {
    isLoading = true
    do {
      let slug =
        chapter?.title
        .lowercased()
        .trim()
        .folding(options: .diacriticInsensitive, locale: .current) ?? ""
        + "/" + textField

      try await cloudKit.createPage(slug: slug, ui: ui)
    } catch {
      // TODO: Alert?
    }
    isLoading = false
    dismiss()
  }
}

struct ChapterPicker: View {

  @Binding var chapter: Chapter?
  @State private var chapterList: [Chapter] = []
  @State private var isLoading = false

  @Environment(\.cloudKitService) var cloudKit
  @Environment(\.dismiss) var dismiss

  var body: some View {
    List(chapterList) { chapter in
      Button(chapter.title) {
        self.chapter = chapter
        dismiss()
      }
    }
    .task {
      isLoading = true
      do {
        chapterList = try await cloudKit.fetchData()
        isLoading = false
      } catch {
        // TODO: ?
      }
    }
  }
}

struct MeetupCreator: View {

  @Binding var ui: [UI]

  @State private var isLoading = false
  @State private var meetupURL: String = ""
  @State private var meetupEvent: MeetupEvent?
  @State private var description: String = ""

  @Environment(\.dismiss) var dismiss

  var body: some View {
    List {
      Section("Meetup") {
        TextField("Paste Meetup URL here", text: $meetupURL)
        Button("Scrape Event Data") {
          Task {
            isLoading = true
            meetupEvent = nil
            await scrapeEvent()
            isLoading = false
          }
        }
      }

      Section("Data") {
        if isLoading {
          Text("Loading")
            .font(.caption)
        }

        if let meetupEvent {
          NavigationLink("Preview") {
            EventDetail(
              title: meetupEvent.title,
              image: meetupEvent.image,
              ui: meetupEvent.ui(customDescription: description),
              shareURL: meetupEvent.url
            )
          }

          TextField("Descrição", text: $description, axis: .vertical)

          // TODO: Add speakers
          Text("TO-DO: Uma forma de adicionar speakers, talks e links deles")
        }
      }
    }
    .toolbar {
      Button("Done") {
        guard let meetupEvent else { return }
        ui = [
          .eventDetail(meetupEvent.ui)
        ]

        dismiss()
      }
      .disabled(meetupEvent == nil)
    }
  }

  func scrapeEvent() async {
    do {
      let meetup = MeetupService()
      let event = try await meetup.event(from: meetupURL)
      meetupEvent = event
      description = event.description
    } catch {
      // TODO: Alert?
    }
  }
}
