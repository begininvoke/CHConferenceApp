//
//  Creator.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/1/25.
//

// TODO: Create a way for chapter leaders to create events on the app

import SwiftUI

struct Debug: View {
  var body: some View {
    List {
      NavigationLink("CloudKit") {
        CloudKitDebugging()
      }
      NavigationLink("Meetup") {
        MeetupDebugging()
      }
    }
    .navigationTitle("debug")
  }
}

#Preview {
  Debug()
}
