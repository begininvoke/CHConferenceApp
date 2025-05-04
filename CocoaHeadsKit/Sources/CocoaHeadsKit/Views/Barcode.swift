//
//  Barcode.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/3/25.
//

import SwiftUI

struct Barcode: View {
  var text: String

  var body: some View {
    Color
      .clear
      .overlay {
        if let barcode {
          barcode
            .resizable()
        }
      }
      .onChange(of: colorScheme) {
        generateBarcode()
      }
      .onAppear {
        generateBarcode()
      }
  }

  @Environment(\.colorScheme) private var colorScheme
  @State private var barcode: Image?

  private func generateBarcode() {
    guard
      case let data = text.data(using: String.Encoding.ascii),
      case let context = CIContext(),
      let filter = CIFilter(name: "CICode128BarcodeGenerator"),
      case _ = filter.setValue(data, forKey: "inputMessage"),
      case let transform = CGAffineTransform(scaleX: 3, y: 3),  // @3x
      let output = filter.outputImage,
      let colorFilter = CIFilter(name: "CIFalseColor"),
      case _ = colorFilter.setValue(output, forKey: kCIInputImageKey),
      case _ = colorFilter.setValue(CIColor(color: UIColor(.primary)), forKey: "inputColor0"),  // bars
      case _ = colorFilter.setValue(CIColor(color: UIColor(.clear)), forKey: "inputColor1"),  // background
      let coloredOutput = colorFilter.outputImage?.transformed(by: transform),
      let cgImage = context.createCGImage(coloredOutput, from: coloredOutput.extent)
    else {
      return
    }

    barcode = Image(cgImage, scale: 1, label: Text(text))
  }
}

#Preview {
    Barcode(text: "Olá CocoaHeads")
}
