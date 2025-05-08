//
//  Event+UI.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/7/25.
//

extension Event {
  // TODO: Event should have duration
  var ui: [EventDetailUI] {
    [
      .card(
        title: nil,
        ui: [
          .callToAction(title: "Confirmar presença!", url: .mock, systemImage: "figure.walk"),
          .caption(
            text: "A entrada será permitida somente após o preenchimento dos dados "
              + "necessários para cadastro no evento dentro do app Meetup.")
        ]),
      .card(
        title: "Informações",
        ui: [
          .vstack(ui: [
            .titleSubtitle(
              title: "Data",
              subtitle: date.formatted(date: .complete, time: .omitted),
              systemImage: "calendar"
            ),
            .divider,
            .titleSubtitle(
              title: "Duração",
              subtitle:
                date.formatted(date: .omitted, time: .shortened) + " - "
                + date.advanced(by: 3600 * 3).formatted(date: .omitted, time: .shortened),
              systemImage: "clock"
            ),
            .divider,
            .titleSubtitle(
              title: "Endereço",
              subtitle: "Av. Paulista, 1100 - São Paulo, SP",
              systemImage: "mappin"
            )
          ])
        ]
      ),
      .card(
        title: "Talks & Palestrantes",
        ui: [
          .speaker(name: "Aleph Retamal", talk: "URLSession 101"),
          .carousel(ui: [
            .link(.mock, title: "Canal YouTube"),
            .link(.mock),
            .link(.mock)
          ]),
          .speaker(
            name: "Ruan Reis",
            talk: "Swift Concurrency: Desafios na adaptação e implementação de código assíncrono"
          ),
          .link(.mock, title: "LinkedIn")
        ]
      ),
      .card(
        title: "TO-DO: Card de socials",
        ui: [
          .caption(text: "Adicionar socials e etc")
        ]
      ),
      .card(
        title: "Avisos",
        ui: [
          .text(
            "A organização do CocoaHeads captura fotos durante o evento todo, "
              + "para divulgação de futuros eventos.\n"
              + "Não quer aparecer nas nossas redes? "
              + "Avise o organizador ou faça 🖐️ para a foto."
          ),
          .callToAction(title: "Leia nosso código de conduta", url: .mock)
        ]
      ),
      .card(
        title: "Como chegar",
        ui: [
          .caption(text: "card de como chegar to-do, accordion element to-do")
        ]
      )
    ]
  }
}
