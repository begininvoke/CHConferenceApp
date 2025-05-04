//
//  NavigationTitle.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

struct NavigationTitle: View {
  init(_ title: String) {
    self.title = title + " "
  }

  let title: String

  var body: some View {
    Text(title)
      .font(
        .system(
          size: 64,
          weight: .bold,
          design: .default
        )
      )
      .kerning(-4)
  }
}

extension View {
  func navigationTitleFont() -> some View {
    self
  }
}
