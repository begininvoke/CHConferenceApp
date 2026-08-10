//
//  CBOR.swift
//  backend
//
//  Created by Mauricio Cardozo on 8/7/26.
//

import Foundation

/// Minimal CBOR (RFC 8949) decoder covering the subset used by App Attest
/// attestation and assertion objects: unsigned/negative integers, byte
/// strings, text strings, arrays, and maps with definite lengths.
enum CBOR: Equatable, Sendable {
  case unsigned(UInt64)
  case negative(Int64)
  case bytes(Data)
  case text(String)
  case array([CBOR])
  case map([CBOR: CBOR])

  enum DecodingError: Error {
    case truncated
    case unsupportedType(UInt8)
    case indefiniteLengthUnsupported
    case invalidUTF8
    case trailingBytes
  }

  static func decode(_ data: Data) throws -> CBOR {
    var reader = Reader(data: data)
    let value = try reader.decodeItem()
    return value
  }

  subscript(key: String) -> CBOR? {
    guard case .map(let map) = self else { return nil }
    return map[.text(key)]
  }

  var bytesValue: Data? {
    guard case .bytes(let data) = self else { return nil }
    return data
  }

  var textValue: String? {
    guard case .text(let string) = self else { return nil }
    return string
  }

  var arrayValue: [CBOR]? {
    guard case .array(let items) = self else { return nil }
    return items
  }

  var unsignedValue: UInt64? {
    guard case .unsigned(let value) = self else { return nil }
    return value
  }

  private struct Reader {
    let data: Data
    var index: Data.Index

    init(data: Data) {
      self.data = data
      self.index = data.startIndex
    }

    mutating func decodeItem() throws -> CBOR {
      let initial = try readByte()
      let majorType = initial >> 5
      let additional = initial & 0x1F

      switch majorType {
      case 0:
        return .unsigned(try readLength(additional))
      case 1:
        let value = try readLength(additional)
        guard value <= UInt64(Int64.max) else { throw DecodingError.unsupportedType(initial) }
        return .negative(-1 - Int64(value))
      case 2:
        let length = try readLength(additional)
        return .bytes(try readBytes(count: length))
      case 3:
        let length = try readLength(additional)
        guard let string = String(data: try readBytes(count: length), encoding: .utf8) else {
          throw DecodingError.invalidUTF8
        }
        return .text(string)
      case 4:
        let count = try readLength(additional)
        var items: [CBOR] = []
        items.reserveCapacity(Int(count))
        for _ in 0..<count {
          items.append(try decodeItem())
        }
        return .array(items)
      case 5:
        let count = try readLength(additional)
        var map: [CBOR: CBOR] = [:]
        for _ in 0..<count {
          let key = try decodeItem()
          let value = try decodeItem()
          map[key] = value
        }
        return .map(map)
      default:
        throw DecodingError.unsupportedType(initial)
      }
    }

    private mutating func readLength(_ additional: UInt8) throws -> UInt64 {
      switch additional {
      case 0...23:
        return UInt64(additional)
      case 24:
        return UInt64(try readByte())
      case 25:
        let bytes = try readBytes(count: 2)
        return bytes.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
      case 26:
        let bytes = try readBytes(count: 4)
        return bytes.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
      case 27:
        let bytes = try readBytes(count: 8)
        return bytes.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
      default:
        throw DecodingError.indefiniteLengthUnsupported
      }
    }

    private mutating func readByte() throws -> UInt8 {
      guard index < data.endIndex else { throw DecodingError.truncated }
      defer { index = data.index(after: index) }
      return data[index]
    }

    private mutating func readBytes(count: UInt64) throws -> Data {
      guard count <= UInt64(data.distance(from: index, to: data.endIndex)) else {
        throw DecodingError.truncated
      }
      let end = data.index(index, offsetBy: Int(count))
      defer { index = end }
      return Data(data[index..<end])
    }
  }
}

extension CBOR: Hashable {}
