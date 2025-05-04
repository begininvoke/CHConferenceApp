//
//  EventDetail.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

struct EventDetail: View {

  @State private var scrollPosition: CGPoint = .zero

  @Environment(\.dismiss) var dismiss

  var body: some View {
    ZStack {
      VStack {
        Image(.meetup)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(maxWidth: .infinity, maxHeight: 250)
          .clipped()

        Text("65º CocoaHeads @ Apple Developer Academy Mackenzie")
          .font(.title)
          .multilineTextAlignment(.center)

        Spacer()
      }
      .blur(radius: min(-(scrollPosition.y / 35), 15))
      .rotationEffect(
        .degrees(
          -max(
            min(Double(-scrollPosition.y) / 50, 2),
            0
          )
        )
      )
      .offset(y: max(scrollPosition.y / 2, -100))
      .frame(alignment: .top)

      ScrollView {
        PositionObservingView(
          coordinateSpace: .named("EventDetail"),
          position: $scrollPosition
        ) {
          Color.clear
            .frame(height: 300)
        }

        innerView
      }
      .coordinateSpace(name: "EventDetail")
      .background {
        Rectangle().fill(.quinary)
          .ignoresSafeArea()
      }
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbar { toolbarItems }
    }
    .onChange(of: scrollPosition.y) {
      if scrollPosition.y > 180 {
        dismiss()
      }
    }
  }

  @ToolbarContentBuilder
  var toolbarItems: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.down")
      }
      .buttonStyle(.plain)
      .toolbarStyle(scrollPosition: scrollPosition.y)
    }

    ToolbarItem(placement: .topBarTrailing) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "square.and.arrow.up")
          .offset(y: -2)
      }
      .buttonStyle(.plain)
      .toolbarStyle(scrollPosition: scrollPosition.y)
    }
  }

  @ViewBuilder
  var innerView: some View {
    VStack(alignment: .leading, spacing: 16) {
      Button {
        // noop
      } label: {
        Text("Confirmar presença! \(Image(systemName: "figure.walk"))")
      }
      .buttonStyle(CallToAction())

      Card(title: "Informações") {
        TitleSubtitleSystemImageView(
          title: "Data",
          subtitle: "Quinta-feira, 24 de abril de 2025",
          systemName: "calendar"
        )

        Divider()

        TitleSubtitleSystemImageView(
          title: "Duração",
          subtitle: "19:00 - 22:00 BRT",
          systemName: "clock"
        )

        Divider()

        TitleSubtitleSystemImageView(
          title: "Endereço",
          subtitle: "Av. Paulista, 1100 - São Paulo, SP",
          systemName: "mappin"
        )
      }

      Card(title: "Agenda") {
        TitleSubtitleSystemImageView(
          title: "Talks & Palestrantes",
          subtitle: "**Aleph Retamal**: HTTP e URLSession 101\n\n**Ruan Reis**: Swift Concurrency: Desafios na adaptação e implementação de código assíncrono",
          systemName: "person.bubble"
        )
      }

      Card(title: "Como chegar") {
        TitleSubtitleSystemImageView(
          title: "Carro",
          subtitle: "O condomínio da OLX tem estacionamento para os convidados!",
          systemName: "car"
        )

        Divider()

        TitleView(title: "Público", systemName: "bus") {
          HStack {
            Text("Brigadeiro")
              .font(.callout)
            Text("L2")
              .font(.caption)
              .foregroundStyle(.white)
              .padding(3)
              .background {
                Circle()
                  .fill(Color(.buttonBottomGradient))
              }
          }
          .padding(5)
          .padding(.horizontal, 3)
          .background {
            RoundedRectangle(cornerRadius: 50)
              .fill(.quinary)
          }
        }
      }
    }
    .padding()
  }
}

#Preview {
  NavigationStack {
    EventDetail()
  }
}

extension View {
  fileprivate func toolbarStyle(scrollPosition: CGFloat) -> some View {
    self
      .font(.caption)
      .foregroundStyle(Color(.buttonBottomGradient))
      .padding()
      .background {
        Circle()
          .fill(.white)
          .shadow(radius: scrollPosition < -100 ? 1 : 0)
          .animation(.default, value: scrollPosition)
      }
  }
}
