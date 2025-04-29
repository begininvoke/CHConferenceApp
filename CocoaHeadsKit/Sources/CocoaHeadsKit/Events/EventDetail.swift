//
//  EventDetail.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

struct EventDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationTitle("Eventos")

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
