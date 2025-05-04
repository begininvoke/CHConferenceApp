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
  @State private var isPresented = false

  var body: some View {
    VStack(alignment: .leading) {
      NavigationTitle("Eventos")

      Button {
        isPresented.toggle()
      } label: {
        Ticket()
      }
      .buttonStyle(.plain)
    }
    .padding()
    .fullScreenCover(isPresented: $isPresented) {
      NavigationStack {
        EventDetail()
      }
    }
  }
}

#Preview {
  EventList()
}
