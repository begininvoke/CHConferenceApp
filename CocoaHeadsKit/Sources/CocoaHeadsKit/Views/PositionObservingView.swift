import SwiftUI

public struct PositionObservingView<Content: View>: View {
  public init(coordinateSpace: CoordinateSpace, position: Binding<CGPoint>, content: @escaping () -> Content) {
    self.coordinateSpace = coordinateSpace
    self._position = position
    self.content = content
  }

  var coordinateSpace: CoordinateSpace
  @Binding var position: CGPoint
  @ViewBuilder var content: () -> Content

  public var body: some View {
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
