//
//  EventList.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

// TODO: This list should scroll horizontally with cards under other cards on small screen sizes, and just be a grid on larger screens
// Maybe the structure itself for larger screens is different
struct EventList: View {
  let events: [Event]

  @State private var isPresented: Event?

  var body: some View {
    VStack(alignment: .leading) {
      NavigationTitle("Eventos")

      if events.isEmpty {
        ContentUnavailableView(
          "Não tem eventos cadastrados (TODO: Copy)",
          systemImage: "tuningfork"
        )
        // TODO: Make ChapterSelectionView's position static
        Text("outro TODO: fixar a navegação")
      } else {
        ForEach(events) { event in
          // TODO: Wallet-like effect with a lot of cards for small screens, grid for larger screens
          Button {
            isPresented = event
          } label: {
            Ticket()
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding()
    .fullScreenCover(item: $isPresented) { event in
      NavigationStack {
        EventDetail(event: event)
      }
    }
  }
}

#Preview {
  EventList(events: [
    .mock
  ])
}
