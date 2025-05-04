//
//  EventDetail.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

struct EventDetail: View {

  @State private var scrollPosition: CGPoint = .zero
  @State private var headerSize: CGFloat = .zero

  @Environment(\.dismiss) var dismiss

  var body: some View {
    ZStack(alignment: .top) {
      GeometryReader { proxy in
        EventDetailHeader(scrollPosition: $scrollPosition)
          .padding(.vertical)
          .border(.pink)
          .onAppear {
            headerSize = proxy.size.height
          }
      }

      ScrollView {
        PositionObservingView(
          coordinateSpace: .named("EventDetail"),
          position: $scrollPosition
        ) {
          Color.clear
//            .frame(height: 330)
            .frame(height: headerSize)
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
          .toolbarStyle(scrollPosition: scrollPosition.y)
      }
      .buttonStyle(.plain)
    }

    ToolbarItem(placement: .topBarTrailing) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "square.and.arrow.up")
          .offset(y: -2)
          .toolbarStyle(scrollPosition: scrollPosition.y)
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  var innerView: some View {
    VStack(alignment: .leading, spacing: 16) {
      Card {
        Button {
          // noop
        } label: {
          Text("Confirmar presença! \(Image(systemName: "figure.walk"))")
        }
        .buttonStyle(CallToAction())

        Text("A entrada será permitida somente após o preenchimento dos dados" +
             "necessários para cadastro no evento dentro do app Meetup.")
        .font(.footnote)
        .fontWeight(.thin)
        .italic()
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
      }

      Card(title: "Informações") {
        VStack {
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
      }

      Card(title: "Agenda") {
        TitleSubtitleSystemImageView(
          title: "Talks & Palestrantes",
          subtitle: "**Aleph Retamal**: HTTP e URLSession 101\n\n**Ruan Reis**: Swift Concurrency: Desafios na adaptação e implementação de código assíncrono",
          systemName: "person.bubble"
        )
      }

      Card(title: "Como chegar") {
        VStack {
          TitleSubtitleSystemImageView(
            title: "Carro",
            subtitle: "O condomínio da OLX tem estacionamento para os convidados!",
            systemName: "car"
          )

          Divider()
            .padding(.vertical, 5)

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
    }
    .padding()
  }
}

#Preview {
  NavigationStack {
    EventDetail()
  }
}

private struct EventDetailHeader: View {

  @Binding var scrollPosition: CGPoint

  var body: some View {
    VStack {
      GeometryReader { reader in
        Image(.meetup)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: reader.size.width)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
      .frame(maxWidth: .infinity, maxHeight: 250)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .padding(3)
      .background {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .foregroundStyle(.background)
      }

      Text("65º CocoaHeads @ Apple Developer Academy Mackenzie")
        .font(.title)
        .multilineTextAlignment(.center)
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
    .padding(.horizontal)
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
