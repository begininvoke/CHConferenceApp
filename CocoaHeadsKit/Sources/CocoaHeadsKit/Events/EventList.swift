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
    Button {
      isPresented.toggle()
    } label: {
      Ticket()
    }
    .buttonStyle(.plain)
    .padding()
    .fullScreenCover(isPresented: $isPresented) {
      NavigationStack {
        EventDetail()
      }
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        NavigationTitle("Eventos")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

#Preview {
  EventList()
}
