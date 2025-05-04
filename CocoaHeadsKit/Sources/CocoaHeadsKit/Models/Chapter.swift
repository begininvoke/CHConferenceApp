//
//  Chapter.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/1/25.
//

import Foundation

struct Chapter {
  let title: String
  let events: [Event]
}

struct Event {
  let title: String
  let location: String
  let startTime: String
  let endTime: String
  let date: String
  let image: URL
}
