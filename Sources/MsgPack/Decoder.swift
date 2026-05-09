// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// MessagePack decoder. Recursive descent over the format-byte ladder per
/// the spec. All multi-byte integer fields on the wire are big-endian.
enum Decoder {
    static func decode(_ bytes: Bytes, cursor: inout Int) throws(MsgPackError) -> MsgPackValue {
        let format = try readByte(bytes, cursor: &cursor)

        switch format {
        // positive fixint 0x00..0x7F
        case 0x00...0x7F:
            return .uint(UInt64(format))

        // fixmap 0x80..0x8F
        case 0x80...0x8F:
            let n = Int(format & 0x0F)
            return try decodeMap(bytes, cursor: &cursor, count: n)

        // fixarray 0x90..0x9F
        case 0x90...0x9F:
            let n = Int(format & 0x0F)
            return try decodeArray(bytes, cursor: &cursor, count: n)

        // fixstr 0xA0..0xBF
        case 0xA0...0xBF:
            let n = Int(format & 0x1F)
            return try decodeString(bytes, cursor: &cursor, length: n)

        case 0xC0:
            return .nil
        case 0xC1:
            throw .reservedFormatByte
        case 0xC2:
            return .bool(false)
        case 0xC3:
            return .bool(true)

        // bin 8/16/32
        case 0xC4:
            let n = Int(try readByte(bytes, cursor: &cursor))
            return .binary(try readBytes(bytes, cursor: &cursor, length: n))
        case 0xC5:
            let n = Int(try readBE16(bytes, cursor: &cursor))
            return .binary(try readBytes(bytes, cursor: &cursor, length: n))
        case 0xC6:
            let n = Int(try readBE32(bytes, cursor: &cursor))
            return .binary(try readBytes(bytes, cursor: &cursor, length: n))

        // ext 8/16/32
        case 0xC7:
            let n = Int(try readByte(bytes, cursor: &cursor))
            return try decodeExt(bytes, cursor: &cursor, length: n)
        case 0xC8:
            let n = Int(try readBE16(bytes, cursor: &cursor))
            return try decodeExt(bytes, cursor: &cursor, length: n)
        case 0xC9:
            let n = Int(try readBE32(bytes, cursor: &cursor))
            return try decodeExt(bytes, cursor: &cursor, length: n)

        // float 32/64
        case 0xCA:
            return .float32(Float(bitPattern: try readBE32(bytes, cursor: &cursor)))
        case 0xCB:
            return .float64(Double(bitPattern: try readBE64(bytes, cursor: &cursor)))

        // uint 8/16/32/64
        case 0xCC:
            return .uint(UInt64(try readByte(bytes, cursor: &cursor)))
        case 0xCD:
            return .uint(UInt64(try readBE16(bytes, cursor: &cursor)))
        case 0xCE:
            return .uint(UInt64(try readBE32(bytes, cursor: &cursor)))
        case 0xCF:
            return .uint(try readBE64(bytes, cursor: &cursor))

        // int 8/16/32/64
        case 0xD0:
            let raw = try readByte(bytes, cursor: &cursor)
            return .int(Int64(Int8(bitPattern: raw)))
        case 0xD1:
            let raw = try readBE16(bytes, cursor: &cursor)
            return .int(Int64(Int16(bitPattern: raw)))
        case 0xD2:
            let raw = try readBE32(bytes, cursor: &cursor)
            return .int(Int64(Int32(bitPattern: raw)))
        case 0xD3:
            let raw = try readBE64(bytes, cursor: &cursor)
            return .int(Int64(bitPattern: raw))

        // fixext 1/2/4/8/16
        case 0xD4:
            return try decodeExt(bytes, cursor: &cursor, length: 1)
        case 0xD5:
            return try decodeExt(bytes, cursor: &cursor, length: 2)
        case 0xD6:
            return try decodeExt(bytes, cursor: &cursor, length: 4)
        case 0xD7:
            return try decodeExt(bytes, cursor: &cursor, length: 8)
        case 0xD8:
            return try decodeExt(bytes, cursor: &cursor, length: 16)

        // str 8/16/32
        case 0xD9:
            let n = Int(try readByte(bytes, cursor: &cursor))
            return try decodeString(bytes, cursor: &cursor, length: n)
        case 0xDA:
            let n = Int(try readBE16(bytes, cursor: &cursor))
            return try decodeString(bytes, cursor: &cursor, length: n)
        case 0xDB:
            let n = Int(try readBE32(bytes, cursor: &cursor))
            return try decodeString(bytes, cursor: &cursor, length: n)

        // array 16/32
        case 0xDC:
            let n = Int(try readBE16(bytes, cursor: &cursor))
            return try decodeArray(bytes, cursor: &cursor, count: n)
        case 0xDD:
            let n = Int(try readBE32(bytes, cursor: &cursor))
            return try decodeArray(bytes, cursor: &cursor, count: n)

        // map 16/32
        case 0xDE:
            let n = Int(try readBE16(bytes, cursor: &cursor))
            return try decodeMap(bytes, cursor: &cursor, count: n)
        case 0xDF:
            let n = Int(try readBE32(bytes, cursor: &cursor))
            return try decodeMap(bytes, cursor: &cursor, count: n)

        // negative fixint 0xE0..0xFF (-32..-1)
        case 0xE0...0xFF:
            return .int(Int64(Int8(bitPattern: format)))

        default:
            // The switch is exhaustive over UInt8; this branch is unreachable
            // but kept for clarity if ranges are ever modified.
            throw .reservedFormatByte
        }
    }

    // MARK: - Container helpers

    private static func decodeArray(_ bytes: Bytes, cursor: inout Int, count: Int) throws(MsgPackError) -> MsgPackValue {
        var items: [MsgPackValue] = []
        items.reserveCapacity(count)
        for _ in 0..<count {
            items.append(try decode(bytes, cursor: &cursor))
        }
        return .array(items)
    }

    private static func decodeMap(_ bytes: Bytes, cursor: inout Int, count: Int) throws(MsgPackError) -> MsgPackValue {
        var entries: [MsgPackValue.MapEntry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            let key = try decode(bytes, cursor: &cursor)
            let value = try decode(bytes, cursor: &cursor)
            entries.append(.init(key: key, value: value))
        }
        return .map(entries)
    }

    private static func decodeString(_ bytes: Bytes, cursor: inout Int, length: Int) throws(MsgPackError) -> MsgPackValue {
        let payload = try readBytes(bytes, cursor: &cursor, length: length)
        guard isValidUTF8(payload.storage) else {
            throw .invalidUTF8
        }
        let s = String(decoding: payload.storage, as: UTF8.self)
        return .string(s)
    }

    /// RFC 3629 UTF-8 validator. `String(decoding:as:)` always succeeds by
    /// substituting replacement characters; we run this first so invalid
    /// MessagePack `str` payloads surface as `.invalidUTF8` instead of
    /// silently corrupting on round-trip.
    private static func isValidUTF8(_ bytes: ContiguousArray<UInt8>) -> Bool {
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            if b <= 0x7F {
                i += 1
            } else if b >= 0xC2 && b <= 0xDF {
                guard i + 1 < bytes.count else { return false }
                guard isCont(bytes[i + 1]) else { return false }
                i += 2
            } else if b == 0xE0 {
                guard i + 2 < bytes.count else { return false }
                let b1 = bytes[i + 1], b2 = bytes[i + 2]
                guard b1 >= 0xA0 && b1 <= 0xBF, isCont(b2) else { return false }
                i += 3
            } else if b >= 0xE1 && b <= 0xEC {
                guard i + 2 < bytes.count, isCont(bytes[i + 1]), isCont(bytes[i + 2]) else { return false }
                i += 3
            } else if b == 0xED {
                // U+D800..U+DFFF surrogates are invalid in UTF-8.
                guard i + 2 < bytes.count else { return false }
                let b1 = bytes[i + 1], b2 = bytes[i + 2]
                guard b1 >= 0x80 && b1 <= 0x9F, isCont(b2) else { return false }
                i += 3
            } else if b >= 0xEE && b <= 0xEF {
                guard i + 2 < bytes.count, isCont(bytes[i + 1]), isCont(bytes[i + 2]) else { return false }
                i += 3
            } else if b == 0xF0 {
                guard i + 3 < bytes.count else { return false }
                let b1 = bytes[i + 1]
                guard b1 >= 0x90 && b1 <= 0xBF, isCont(bytes[i + 2]), isCont(bytes[i + 3]) else { return false }
                i += 4
            } else if b >= 0xF1 && b <= 0xF3 {
                guard i + 3 < bytes.count, isCont(bytes[i + 1]), isCont(bytes[i + 2]), isCont(bytes[i + 3]) else { return false }
                i += 4
            } else if b == 0xF4 {
                // Caps at U+10FFFF; lead byte 0xF4 only allows trail 0x80..0x8F.
                guard i + 3 < bytes.count else { return false }
                let b1 = bytes[i + 1]
                guard b1 >= 0x80 && b1 <= 0x8F, isCont(bytes[i + 2]), isCont(bytes[i + 3]) else { return false }
                i += 4
            } else {
                return false
            }
        }
        return true
    }

    private static func isCont(_ b: UInt8) -> Bool {
        b >= 0x80 && b <= 0xBF
    }

    private static func decodeExt(_ bytes: Bytes, cursor: inout Int, length: Int) throws(MsgPackError) -> MsgPackValue {
        let tid = try readByte(bytes, cursor: &cursor)
        let payload = try readBytes(bytes, cursor: &cursor, length: length)
        return .ext(Int8(bitPattern: tid), payload)
    }

    // MARK: - Cursor helpers

    private static func readByte(_ bytes: Bytes, cursor: inout Int) throws(MsgPackError) -> UInt8 {
        guard cursor < bytes.count else {
            throw .truncated(needed: 1, available: 0)
        }
        let b = bytes.storage[cursor]
        cursor += 1
        return b
    }

    private static func readBE16(_ bytes: Bytes, cursor: inout Int) throws(MsgPackError) -> UInt16 {
        guard cursor + 2 <= bytes.count else {
            throw .truncated(needed: 2, available: bytes.count - cursor)
        }
        let hi = UInt16(bytes.storage[cursor])
        let lo = UInt16(bytes.storage[cursor + 1])
        cursor += 2
        return (hi << 8) | lo
    }

    private static func readBE32(_ bytes: Bytes, cursor: inout Int) throws(MsgPackError) -> UInt32 {
        guard cursor + 4 <= bytes.count else {
            throw .truncated(needed: 4, available: bytes.count - cursor)
        }
        var v: UInt32 = 0
        for i in 0..<4 {
            v = (v << 8) | UInt32(bytes.storage[cursor + i])
        }
        cursor += 4
        return v
    }

    private static func readBE64(_ bytes: Bytes, cursor: inout Int) throws(MsgPackError) -> UInt64 {
        guard cursor + 8 <= bytes.count else {
            throw .truncated(needed: 8, available: bytes.count - cursor)
        }
        var v: UInt64 = 0
        for i in 0..<8 {
            v = (v << 8) | UInt64(bytes.storage[cursor + i])
        }
        cursor += 8
        return v
    }

    private static func readBytes(_ bytes: Bytes, cursor: inout Int, length: Int) throws(MsgPackError) -> Bytes {
        guard cursor + length <= bytes.count else {
            throw .truncated(needed: length, available: bytes.count - cursor)
        }
        var out = Bytes(reservingCapacity: length)
        for i in 0..<length {
            out.append(bytes.storage[cursor + i])
        }
        cursor += length
        return out
    }
}
