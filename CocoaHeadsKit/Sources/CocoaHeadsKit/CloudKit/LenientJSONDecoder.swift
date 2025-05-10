//
//  LenientJSONDecoder.swift
//  CocoaHeadsKit
//
//  Created by Mauricio on 5/9/25.
//

import Foundation

class LenientJSONDecoder: JSONDecoder, @unchecked Sendable {
  override func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
    do {
      return try super.decode(type, from: data)
    } catch DecodingError.keyNotFound(let key, let context) {
      print("Warning: Missing key '\(key.stringValue)' - Ignoring and proceeding.")
      let patchedData = try patchMissingKeys(type, data: data, context: context)
      return try super.decode(type, from: patchedData)
    }
  }

  private func patchMissingKeys<T: Decodable>(_ type: T.Type, data: Data, context: DecodingError.Context) throws -> Data
  {
    let jsonObject =
      try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? NSMutableDictionary
      ?? NSMutableDictionary()
    if let codingPath = context.codingPath.last?.stringValue {
      jsonObject.setValue(nil, forKey: codingPath)
    }
    return try JSONSerialization.data(withJSONObject: jsonObject, options: [])
  }
}
