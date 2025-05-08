//
//  EventDetail.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

struct EventDetail: View {

  let event: Event

  @State private var scrollPosition: CGPoint = .zero
  @State private var headerSize: CGFloat = .zero
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .top) {
      EventDetailHeader(event: event, scrollPosition: $scrollPosition)
        .padding(.vertical)
        .onPreferenceChange(HeaderHeightKey.self) { [$headerSize] height in
          $headerSize.wrappedValue = height
        }

      ScrollView {
        PositionObservingView(
          coordinateSpace: .named("EventDetail"),
          position: $scrollPosition
        ) {
          Color.clear
            .frame(height: headerSize)
        }

        VStack(alignment: .leading, spacing: 16) {
          EventDetailRenderer(ui: event.ui)
        }
        .padding()
      }
      .coordinateSpace(name: "EventDetail")
      .background {
        Rectangle().fill(.quinary)
          .ignoresSafeArea()
      }
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbar { toolbarItems }
    }
    .onChange(of: scrollPosition.y) {
      if scrollPosition.y > 180 {
        dismiss()
      }
    }
  }

  @ToolbarContentBuilder
  var toolbarItems: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.down")
          .toolbarStyle(scrollPosition: scrollPosition.y)
      }
      .buttonStyle(.plain)
    }

    ToolbarItem(placement: .topBarTrailing) {
      ShareLink(item: event.rsvpURL) {
        Image(systemName: "square.and.arrow.up")
          .offset(y: -2)
          .toolbarStyle(scrollPosition: scrollPosition.y)
      }
      .buttonStyle(.plain)
    }
  }
}

#Preview("Full") {
  NavigationStack {
    EventDetail(event: .mock)
  }
}

extension View {
  fileprivate func toolbarStyle(scrollPosition: CGFloat) -> some View {
    self
      .font(.caption)
      .foregroundStyle(Color.buttonBottomGradient)
      .padding()
      .background {
        Circle()
          .fill(.white)
          .shadow(radius: scrollPosition < -100 ? 1 : 0)
          .animation(.default, value: scrollPosition)
      }
  }
}

// FIXME: Color assets are crashing App Clip on TestFlight
extension Color {
  static var buttonTopGradient: Color {
    Color(red: 3, green: 118, blue: 69)
  }

  static var buttonBottomGradient: Color {
    Color(red: 3, green: 90, blue: 53)
  }
}
