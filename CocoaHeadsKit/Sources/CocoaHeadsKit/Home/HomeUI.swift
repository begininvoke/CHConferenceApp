//
//  HomeUI.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

indirect enum HomeUI: Codable, Sendable {
  case home
}

extension HomeUI: Identifiable {
  var id: String {
    "home"
  }
}
