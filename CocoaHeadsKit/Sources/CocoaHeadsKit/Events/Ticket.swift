//
//  Ticket.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/1/25.
//

import SwiftUI

struct Ticket: View {
  var body: some View {
    TicketCard {
      header
        .padding()

      Image(.meetup)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(height: 150)
        .clipped()

      eventDetails
        .padding()

      Line()
        .stroke(
          style: .init(
            lineWidth: 2,
            lineCap: .square,
            dash: [5, 10]
          )
        )
        .fill(.black.opacity(0.1))
        .frame(height: 1)

      VStack {
        Barcode(text: "CocoaHeadsSaoPaulo")
          .frame(height: 100)
          .overlay {
            Text("Não será permitida a entrada sem inscrição!")
              .font(.caption)
              .fontDesign(.monospaced)
              .italic()
              .foregroundStyle(.secondary)
              .offset(y: 47)
          }
      }
      .frame(maxWidth: .infinity)
      .padding(.bottom)
    }
  }

  private var header: some View {
    HStack {
      // This should be dynamic for each location
      // CocoaHeads Fortaleza uses a different logo
      Image(.logo)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 38, height: 38)

      Spacer()

      VStack(alignment: .trailing) {
        Text("Data")
          .font(.caption)
          .textCase(.uppercase)
        Text("24 ABR")
          .fontWeight(.bold)
      }

      VStack(alignment: .trailing) {
        Text("Horário")
          .font(.caption)
          .textCase(.uppercase)
        Text("19:00")
          .fontWeight(.bold)
      }
    }
    .fontDesign(.monospaced)
  }

  @ViewBuilder
  private var eventDetails: some View {
    titleSubtitleView(
      title: "Evento",
      subtitle: "65º CocoaHeads @ Apple Developer Academy Mackenzie"
    )
    titleSubtitleView(title: "Localização", subtitle: "AV. Paulista, 1100, São Paulo, SP")
    HStack {
      titleSubtitleView(title: "Início", subtitle: "19:00")
      Spacer()
      titleSubtitleView(title: "Fim", subtitle: "22:00")
      Spacer()
      titleSubtitleView(title: "Data", subtitle: "24 ABR")
    }
  }

  private func titleSubtitleView(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.caption)

      Text(subtitle)
        .fontWeight(.bold)
    }
    .textCase(.uppercase)
    .fontDesign(.monospaced)
  }
}

#Preview {
  Ticket()
    .padding()
}
