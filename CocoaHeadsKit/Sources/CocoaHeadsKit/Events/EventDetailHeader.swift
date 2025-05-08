//
//  EventDetailHeader.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/7/25.
//

import SwiftUI

// TODO: Inject Image

struct EventDetailHeader: View {
  let event: Event
  @Binding var scrollPosition: CGPoint

  var body: some View {
    VStack {
      GeometryReader { reader in
        Image(.meetup)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: reader.size.width)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
      .frame(maxWidth: .infinity, maxHeight: 250)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .padding(3)
      .background {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .foregroundStyle(.background)
      }

      Text(event.title)
        .font(.title)
        .multilineTextAlignment(.center)
    }
    .background(
      GeometryReader { proxy in
        Color.clear
          .preference(key: HeaderHeightKey.self, value: proxy.size.height)
      }
    )
    .blur(radius: min(-(scrollPosition.y / 35), 15))
    .rotationEffect(
      .degrees(
        -max(
          min(Double(-scrollPosition.y) / 50, 2),
          0
        )
      )
    )
    .offset(y: max(scrollPosition.y / 2, -100))
    .frame(alignment: .top)
    .padding(.horizontal)
  }
}

struct HeaderHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
