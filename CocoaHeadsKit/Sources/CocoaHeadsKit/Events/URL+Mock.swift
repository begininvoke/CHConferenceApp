//
//  URL+Mock.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/7/25.
//

import Foundation

extension URL {
  static var mock: URL {
    URL(string: "https://apple.com")!
  }

  static var codeOfConduct: URL {
    URL(string: "https://github.com/iOSDevBR/Codigo-De-Conduta/blob/master/README.md")!
  }
}
