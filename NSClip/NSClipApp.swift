//
//  NSClipApp.swift
//  NSClip
//
//  Created by Mauricio Cardozo on 1/15/21.
//  Copyright © 2021 Cocoaheadsbr. All rights reserved.
//

import CocoaHeadsKit
import SwiftUI

@main
struct NSClipApp: App {

  @State private var isPresented = false

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        Button("crash app") {
          isPresented.toggle()
        }
        .sheet(isPresented: $isPresented) {
          AppClipView()
        }
      }
    }
  }
}
