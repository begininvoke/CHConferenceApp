//
//  Home.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 4/28/25.
//

import SwiftUI

public struct Home: View {
    @State private var scrollOffset: CGFloat = 0

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            VStack {
                // TODO: These views should blur based on the scroll position
                Image(systemName: "logo.playstation")

                Text("65º CocoaHeads @ Apple Developer Academy Mackenzie")
                    .font(.title)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 300)

            ScrollView {
                Spacer()
                    .frame(height: 300)

                EventDetail()
            }
            .background {
                Rectangle().fill(.quinary)
                    .ignoresSafeArea()
            }
            .onPreferenceChange(ScrollOffsetKey.self) { [$scrollOffset] value in
                $scrollOffset.wrappedValue = -value
            }
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                MainActor.assumeIsolated {
                    scrollOffset = -value
                    print(scrollOffset)
                }
            }

            VariableBlurView(maxBlurRadius: 5)
                .ignoresSafeArea()
                // TODO: This height should be based on the dynamic island height
                .frame(height: 20, alignment: .top)
        }
        .onChange(of: scrollOffset) {
            print(scrollOffset)
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    Home()
}
