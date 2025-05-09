//
//  NSClipApp.swift
//  NSClip
//
//  Created by Mauricio Cardozo on 1/15/21.
//  Copyright © 2021 Cocoaheadsbr. All rights reserved.
//

import CocoaHeadsKit
import SwiftUI

@main
struct NSClipApp: App {

  @State private var isPresented = false

  enum Navigation: String, Identifiable {
    case crash
    case header
    case positionObserving
    case renderer
    case picker

    var id: String { rawValue }
  }

  @State private var navigation: Navigation?

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        VStack {
          Button("crash app") {
            navigation = .crash
          }

          Button("header") {
            navigation = .header
          }

          Button("positionObserving") {
            navigation = .positionObserving
          }

          Button("renderer with mock") {
            navigation = .renderer
          }

          Button("picker") {
            navigation = .picker
          }
        }
        .sheet(item: $navigation) { nav in
          switch nav {
          case .crash:
            AppClipView()
          case .header:
            EventDetailHeader(title: "lmao", imageURL: nil, scrollPosition: .constant(.zero))
          case .positionObserving:
            ScrollView {
              PositionObservingView(coordinateSpace: .global, position: .constant(.zero)) {
                Text("Position")
              }
            }
          case .renderer:
            EventDetailRenderer(ui: Event.mock.ui)
          case .picker:
            EventDetailPickerView()
          }
        }
      }
    }
  }
}

struct EventDetailPickerView: View {

  let elements: [EventDetailUI] = [
    .card(title: "Card Title", ui: [.text("Card Content")]),
    .carousel(ui: [.text("Carousel Item 1"), .text("Carousel Item 2")]),
    .callToAction(title: "Learn More", url: URL(string: "https://example.com")!, systemImage: "link"),
    .caption(text: "This is a caption"),
    .debug(.text("Debug Info")),
    .divider,
    .empty,
    .link(URL(string: "https://example.com")!, title: "Example Link"),
    .map(address: "123 Main St", lat: 37.7749, lng: -122.4194),
    .subtitle("This is a subtitle"),
    .text("Sample text"),
    .titleSubtitle(title: "Title", subtitle: "Subtitle", systemImage: "star"),
    .vstack(ui: [.text("Item 1"), .text("Item 2")])
  ]

  @State private var selectedElement: EventDetailUI?

  var body: some View {
    VStack {
      VStack {
        if let selectedElement {
          EventDetailRenderer(ui: [selectedElement])
            .padding()
            .border(Color.gray, width: 1)
            .padding()
        } else {
          Text("Select an element to preview")
            .foregroundStyle(.secondary)
            .padding()
        }
      }
      .frame(minHeight: 300)

      List(elements.indices, id: \.self) { index in
        let element = elements[index]
        Button(element.id.isEmpty ? "Empty Element" : element.id) {
          selectedElement = element
        }
      }
    }
  }
}
