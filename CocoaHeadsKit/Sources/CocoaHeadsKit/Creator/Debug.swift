//
//  Creator.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/1/25.
//

// TODO: Create a way for chapter leaders to create events on the app

import SwiftUI

struct Debug: View {

  @State private var recordName: String = ""
  @State private var hasAccess: String = ""
  @State private var isLoading = false

  @State private var eventTitle: String = ""
  @State private var eventDate: String = ""
  @State private var eventLocation: String = ""
  @State private var eventDescription: String = ""
  @State private var eventRSVPLink: String = ""
  @State private var meetupEvent: MeetupEvent?

  @State private var textField: String = ""

  var body: some View {
    List {
      Section {
        Text("id: \(recordName)")
        Text("is chapter leader: \(hasAccess)")
        Button("Copy ID") {
          UIPasteboard.general.string = recordName
        }
      }

      Section {
        TextField("Paste meetup link here", text: $textField)
        Button("Add example meetup link") {
          textField =
            "https://www.meetup.com/pt-BR/swift-language/events/307194649/?eventOrigin=home_page_upcoming_events$all"
        }
        Button("Add example cocoaheads meetup link") {
          textField = "https://www.meetup.com/cocoaheadssp/events/307551844/?eventOrigin=group_upcoming_events"
        }

        Button("Scrape Event Data") {
          Task {
            isLoading = true
            meetupEvent = nil
            eventTitle = ""
            await scrapeEvent()
            isLoading = false
          }
        }

        if let meetupEvent {
          NavigationLink("Event detail screen for this meetup") {
            MeetupEventDetail(event: meetupEvent)
          }
        }

        if isLoading {
          Text("Loading")
            .font(.caption)
        }

        if eventTitle.contains("error") {
          Text(eventTitle)
        }

        if let meetupEvent {
          Text("Event Title: \(eventTitle)")
          Text("Event Date: \(eventDate)")
          Text("Location: \(eventLocation)")
          Text("Description: \(eventDescription)")
          Text("RSVP Link: \(eventRSVPLink)")

          VStack {
            AsyncImage(
              url: meetupEvent.image,
              scale: 2
            ) {
              $0
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
            } placeholder: {
              Rectangle()
                .fill(.tertiary)
            }
            .mask {
              RoundedRectangle(cornerRadius: 10, style: .continuous)
            }
            .padding()
          }
        }
      }
    }
    .task {
      async let name: Void = fetchRecordName()
      async let access: Void = fetchLeaderAccess()
      let _ = await [name, access]
    }
    .navigationTitle("debug")
    .animation(.default, value: meetupEvent)
  }

  func fetchRecordName() async {
    let service = CloudKitService()
    do {
      let id = try await service.fetchUserRecordID()
      recordName = id
    } catch {
      recordName = "fetch error - are you logged in icloud?"
    }
  }

  func fetchLeaderAccess() async {
    let service = CloudKitService()
    do {
      let fetchedAccess = try await service.hasLeaderAccess()
      hasAccess = fetchedAccess ? "yes" : "no?"
    } catch {
      hasAccess = "no"
    }
  }

  func scrapeEvent() async {
    do {
      let meetup = MeetupService()
      let event = try await meetup.event(from: textField)
      eventTitle = event.title
      eventDate = event.date.formatted()
      eventLocation =
        event.address + "\nlat: \(event.location.coordinate.latitude) lng: \(event.location.coordinate.longitude)"
      eventDescription = event.description
      eventRSVPLink = event.url.absoluteString
      meetupEvent = event
    } catch {
      eventTitle =
        if let error = error as? MeetupService.Error {
          // TODO: Shouldn't this be MeetupService.Error's `localizedDescription`?
          switch error {
          case .dateError:
            "Não consegui encontrar ou fazer decode da data"
          case .imageError:
            "Não encontrei a URL da imagem"
          case .pastEventError:
            "Em caso de eventos passados, o Meetup redireciona para uma página de Login, sendo assim, não é possível extrair os dados"
          case .urlError:
            "Erro na URL"
          }
        } else {
          "error: \(error)"
        }
    }
  }
}

#Preview {
  Debug()
}
