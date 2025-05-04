import SwiftUI

struct PositionObservingView<Content: View>: View {
  var coordinateSpace: CoordinateSpace
  @Binding var position: CGPoint
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .background(
        GeometryReader { geometry in
          Color.clear.preference(
            key: PreferenceKey.self,
            value: geometry.frame(in: coordinateSpace).origin
          )
        }
      )
      .onPreferenceChange(PreferenceKey.self) { [$position] position in
          $position.wrappedValue = CGPoint(
            x: position.x.rounded(),
            y: position.y.rounded()
          )
      }
  }

  private struct PreferenceKey: SwiftUI.PreferenceKey {
    static var defaultValue: CGPoint { .zero }
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
  }
}
