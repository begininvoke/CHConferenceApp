//
//  Color+Button.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

import SwiftUI

// TODO: Investigate if these are really what could've been crashing the AppClip
extension Color {
  static var buttonTopGradient: Color {
    Color(uiColor: UIColor(red: 3 / 255, green: 118 / 255, blue: 69 / 255, alpha: 1))
  }

  static var buttonBottomGradient: Color {
    Color(uiColor: UIColor(red: 3 / 255, green: 90 / 255, blue: 53 / 255, alpha: 1))
  }
}
