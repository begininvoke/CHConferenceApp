//
//  ChapterSelectionView.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/2/25.
//

import SwiftUI

struct ChapterSelectionView: View {
  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ChapterSelectionButton(title: "Belo-Horizonte", isSelected: false)
        ChapterSelectionButton(title: "Fortaleza", isSelected: false)
        ChapterSelectionButton(title: "Campinas", isSelected: false)
        ChapterSelectionButton(title: "Curitiba", isSelected: false)
        ChapterSelectionButton(title: "Rio de Janeiro", isSelected: false)
        ChapterSelectionButton(title: "São Paulo", isSelected: true)
      }
      .padding(.horizontal)
    }
  }
}

struct ChapterSelectionButton: View {
  var title: String
  var isSelected: Bool

  var body: some View {
    Text(title)
      .fontWeight(isSelected ? .regular : .thin)
      .kerning(-0.1)
      .opacity(isSelected ? 1 : 0.5)
      .padding(12)
      .background {
        if isSelected {
          RoundedRectangle(cornerRadius: 50, style: .continuous)
            .fill(.background.shadow(.inner(color: .black.opacity(0.1), radius: 3)))
            .stroke(.black.opacity(0.1), lineWidth: 1)
        }
      }
      .animation(.default, value: isSelected)
  }
}

#Preview {
  ChapterSelectionView()
}
