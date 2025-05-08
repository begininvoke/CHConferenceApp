//
//  EventDetailRenderer.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/7/25.
//

import SwiftUI

// TODO: Break views into their own files

struct EventDetailRenderer: View {
  let ui: [EventDetailUI]

  var body: some View { ForEach(ui) { render(ui: $0) } }

  @ViewBuilder
  private func render(ui: EventDetailUI) -> some View {
    switch ui {
    case .card(title: let title, edges: let edges, insetBy: let insets, ui: let innerUI):
      Card(title: title, contentInset: (edges, insets)) {
        EventDetailRenderer(ui: innerUI)
      }
    case .carousel(ui: let innerUI):
      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          EventDetailRenderer(ui: innerUI)
        }
      }
    case .callToAction(title: let title, url: let url, systemImage: let systemImage):
      Link(destination: url) {
        if let systemImage {
          Text("\(title) \(Image(systemName: systemImage))")
        } else {
          Text(title)
        }
      }
      .buttonStyle(CallToAction())
    case .caption(text: let text):
      Text(LocalizedStringKey(text))
        .font(.footnote)
        .fontWeight(.thin)
        .italic()
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
    case .divider:
      Divider()
    case .link(let url, title: let title):
      LinkView(url: url, title: title)
    case .map(address: let addr, lat: let lat, lng: let lng):
      MapUI(address: addr, latitude: lat, longitude: lng)
    case .subtitle(let text):
      Text(LocalizedStringKey(text))
        .foregroundStyle(.secondary)
        .font(.callout)
    case .text(let text):
      Text(LocalizedStringKey(text))
        .fontWeight(.thin)
    case .titleSubtitle(title: let title, subtitle: let subtitle, systemImage: let systemName):
      TitleSubtitleSystemImageView(
        title: LocalizedStringKey(title),
        subtitle: LocalizedStringKey(subtitle),
        systemName: systemName
      )
    case .vstack(ui: let innerUI):
      VStack {
        EventDetailRenderer(ui: innerUI)
      }
    }
  }
}

#Preview {
  NavigationStack {
    ScrollView {
      EventDetailRenderer(ui: Event.mock.ui).padding()
    }
  }
}
