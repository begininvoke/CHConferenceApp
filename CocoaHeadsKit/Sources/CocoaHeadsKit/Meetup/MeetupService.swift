//
//  MeetupService.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

import CoreLocation
import SwiftSoup

struct MeetupEvent: Equatable {
  let title: String
  let address: String
  let location: CLLocation
  let description: String
  let date: Date
  let url: URL
  let image: URL?
}

struct MeetupService {
  func event(from urlString: String) async throws -> MeetupEvent {
    guard
      let url = URL(string: urlString),
      case (let data, _) = try await URLSession.shared.data(from: url),
      let html = String(data: data, encoding: .utf8)
    else {
      throw Error.urlError
    }

    guard !url.absoluteString.contains("Entrar") else {
      throw Error.pastEventError
    }

    let document = try SwiftSoup.parse(html)

    return MeetupEvent(
      title: try parseTitle(from: document),
      address: try parseAddress(from: document),
      location: try parseLocation(from: document),
      description: try parseDescription(from: document),
      date: try parseDate(from: document),
      url: url,
      image: try parseImage(from: document)
    )
  }

  func parseTitle(from document: Document) throws -> String {
    let title = try document.title()
    return "\(title.split(separator: ",").first ?? "")"
  }

  // TODO: Replace nil coalescing with throw
  func parseAddress(from document: Document) throws -> String {
    let eventLocation =
      try document.select("[data-event-label='event-location']")
      .first()?.text() ?? "No location found"

    let addressElement = try document.select("[data-testid='location-info']").first()
    let address = try addressElement?.text() ?? "No address found"

    return eventLocation + "\n" + address
  }

  // TODO: Replace nil coalescing with throw
  func parseLocation(from document: Document) throws -> CLLocation {
    // Extracting latitude and longitude from the Google Maps link, if present
    let addressElement = try document.select("[data-testid='location-info']").first()
    if let mapLink = try addressElement?.select("a").first()?.attr("href"),
      let components = URLComponents(string: mapLink),
      let queryItems = components.queryItems
    {
      let lat =
        queryItems.first(where: { $0.name == "q" })?
        .value?.components(separatedBy: ",").first ?? "Unknown lat"
      let lng =
        queryItems.first(where: { $0.name == "q" })?
        .value?.components(separatedBy: ",").last ?? "Unknown lng"

      if let doubleLat = Double(lat), let doubleLng = Double(lng) {
        return CLLocation(latitude: doubleLat, longitude: doubleLng)
      }
    }

    return CLLocation(latitude: 12.34567, longitude: 12.34567)
  }

  func parseDescription(from document: Document) throws -> String {
    try document.select("div#event-details").first()?
      .text()
      .removingFirstOccurrence(of: "detalhes")
      .removingFirstOccurrence(of: "details") ?? ""
  }

  func parseDate(from document: Document) throws -> Date {
    guard let dateTime = try document.select("time").first()?.attr("datetime") else {
      throw Error.dateError
    }
    return try Date.ISO8601FormatStyle().parse(dateTime)
  }

  func parseImage(from document: Document) throws -> URL {
    guard
      let imageString = try document.select("[data-testid='event-description-image']").select("img").first()?.attr(
        "src"),
      let url = URL(string: imageString)
    else {
      throw Error.imageError
    }
    return url
  }

  enum Error: Swift.Error {
    case dateError
    case imageError
    case pastEventError
    case urlError
  }
}

extension String {
  fileprivate func removingFirstOccurrence(of word: String) -> String {
    guard let range = range(of: "\\b\(word)\\b", options: [.regularExpression, .caseInsensitive]) else {
      return self
    }
    return replacingCharacters(in: range, with: "")
  }
}
