//
//  Home.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

public struct Home: View {
  public init() {}

  public var body: some View {
    NavigationStack {
      VStack {
        EventList()
        Spacer()
        ChapterSelectionView()
      }
      .padding(.bottom)
    }
  }
}

#Preview {
  Home()
}
