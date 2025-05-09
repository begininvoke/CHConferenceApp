//
//  EventDetailHeader.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/7/25.
//

import SwiftUI

public struct EventDetailHeader: View {
  public init(title: String, imageURL: URL? = nil, scrollPosition: Binding<CGPoint>) {
    self.title = title
    self.imageURL = imageURL
    self._scrollPosition = scrollPosition
  }
  
  let title: String
  let imageURL: URL?
  @Binding var scrollPosition: CGPoint

  public var body: some View {
    VStack {
      GeometryReader { reader in
        AsyncImage(url: imageURL, scale: 2)
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

      Text(title)
        .font(.title)
        .multilineTextAlignment(.center)
    }
    .padding(.bottom)
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
