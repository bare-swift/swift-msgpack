// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// MessagePack encoder. Picks the *shortest* representation for each value
/// (e.g. an `int(5)` becomes a positive fixint, `int(200)` becomes a uint8,
/// `int(-1)` becomes a negative fixint). All multi-byte integers are
/// big-endian per the MessagePack spec.
enum Encoder {
    static func encode(_ value: MsgPackValue, into out: inout Bytes) {
        switch value {
        case .nil:
            out.append(0xC0)
        case .bool(let b):
            out.append(b ? 0xC3 : 0xC2)
        case .int(let n):
            encodeInt(n, into: &out)
        case .uint(let n):
            encodeUInt(n, into: &out)
        case .float32(let f):
            out.append(0xCA)
            appendBE32(f.bitPattern, into: &out)
        case .float64(let d):
            out.append(0xCB)
            appendBE64(d.bitPattern, into: &out)
        case .string(let s):
            encodeString(s, into: &out)
        case .binary(let b):
            encodeBinary(b, into: &out)
        case .array(let xs):
            encodeArrayHeader(xs.count, into: &out)
            for x in xs { encode(x, into: &out) }
        case .map(let entries):
            encodeMapHeader(entries.count, into: &out)
            for e in entries {
                encode(e.key, into: &out)
                encode(e.value, into: &out)
            }
        case .ext(let id, let data):
            encodeExt(typeID: id, data: data, into: &out)
        }
    }

    // MARK: - Integers

    private static func encodeInt(_ n: Int64, into out: inout Bytes) {
        // Positive values prefer the unsigned ladder (positive fixint or
        // uint8/16/32/64) because that's the shortest representation for
        // most inputs.
        if n >= 0 {
            encodeUInt(UInt64(n), into: &out)
            return
        }
        if n >= -32 {
            // negative fixint: bottom 5 bits are the magnitude (two's complement).
            out.append(UInt8(bitPattern: Int8(n)))
            return
        }
        if n >= Int64(Int8.min) {
            out.append(0xD0)
            out.append(UInt8(bitPattern: Int8(n)))
            return
        }
        if n >= Int64(Int16.min) {
            out.append(0xD1)
            appendBE16(UInt16(bitPattern: Int16(n)), into: &out)
            return
        }
        if n >= Int64(Int32.min) {
            out.append(0xD2)
            appendBE32(UInt32(bitPattern: Int32(n)), into: &out)
            return
        }
        out.append(0xD3)
        appendBE64(UInt64(bitPattern: n), into: &out)
    }

    private static func encodeUInt(_ n: UInt64, into out: inout Bytes) {
        if n <= 0x7F {
            out.append(UInt8(n))
            return
        }
        if n <= UInt64(UInt8.max) {
            out.append(0xCC)
            out.append(UInt8(n))
            return
        }
        if n <= UInt64(UInt16.max) {
            out.append(0xCD)
            appendBE16(UInt16(n), into: &out)
            return
        }
        if n <= UInt64(UInt32.max) {
            out.append(0xCE)
            appendBE32(UInt32(n), into: &out)
            return
        }
        out.append(0xCF)
        appendBE64(n, into: &out)
    }

    // MARK: - String / binary

    private static func encodeString(_ s: String, into out: inout Bytes) {
        let utf8 = Array(s.utf8)
        let n = utf8.count
        if n <= 31 {
            out.append(0xA0 | UInt8(n))
        } else if n <= 0xFF {
            out.append(0xD9)
            out.append(UInt8(n))
        } else if n <= 0xFFFF {
            out.append(0xDA)
            appendBE16(UInt16(n), into: &out)
        } else {
            out.append(0xDB)
            appendBE32(UInt32(n), into: &out)
        }
        out.append(contentsOf: utf8)
    }

    private static func encodeBinary(_ b: Bytes, into out: inout Bytes) {
        let n = b.count
        if n <= 0xFF {
            out.append(0xC4)
            out.append(UInt8(n))
        } else if n <= 0xFFFF {
            out.append(0xC5)
            appendBE16(UInt16(n), into: &out)
        } else {
            out.append(0xC6)
            appendBE32(UInt32(n), into: &out)
        }
        out.append(contentsOf: b.storage)
    }

    // MARK: - Containers

    private static func encodeArrayHeader(_ n: Int, into out: inout Bytes) {
        if n <= 15 {
            out.append(0x90 | UInt8(n))
        } else if n <= 0xFFFF {
            out.append(0xDC)
            appendBE16(UInt16(n), into: &out)
        } else {
            out.append(0xDD)
            appendBE32(UInt32(n), into: &out)
        }
    }

    private static func encodeMapHeader(_ n: Int, into out: inout Bytes) {
        if n <= 15 {
            out.append(0x80 | UInt8(n))
        } else if n <= 0xFFFF {
            out.append(0xDE)
            appendBE16(UInt16(n), into: &out)
        } else {
            out.append(0xDF)
            appendBE32(UInt32(n), into: &out)
        }
    }

    // MARK: - Ext

    private static func encodeExt(typeID: Int8, data: Bytes, into out: inout Bytes) {
        let n = data.count
        let tid = UInt8(bitPattern: typeID)
        switch n {
        case 1:  out.append(0xD4); out.append(tid)
        case 2:  out.append(0xD5); out.append(tid)
        case 4:  out.append(0xD6); out.append(tid)
        case 8:  out.append(0xD7); out.append(tid)
        case 16: out.append(0xD8); out.append(tid)
        default:
            if n <= 0xFF {
                out.append(0xC7)
                out.append(UInt8(n))
            } else if n <= 0xFFFF {
                out.append(0xC8)
                appendBE16(UInt16(n), into: &out)
            } else {
                out.append(0xC9)
                appendBE32(UInt32(n), into: &out)
            }
            out.append(tid)
        }
        out.append(contentsOf: data.storage)
    }

    // MARK: - Big-endian helpers

    private static func appendBE16(_ value: UInt16, into out: inout Bytes) {
        out.append(UInt8(truncatingIfNeeded: value >> 8))
        out.append(UInt8(truncatingIfNeeded: value))
    }

    private static func appendBE32(_ value: UInt32, into out: inout Bytes) {
        out.append(UInt8(truncatingIfNeeded: value >> 24))
        out.append(UInt8(truncatingIfNeeded: value >> 16))
        out.append(UInt8(truncatingIfNeeded: value >> 8))
        out.append(UInt8(truncatingIfNeeded: value))
    }

    private static func appendBE64(_ value: UInt64, into out: inout Bytes) {
        out.append(UInt8(truncatingIfNeeded: value >> 56))
        out.append(UInt8(truncatingIfNeeded: value >> 48))
        out.append(UInt8(truncatingIfNeeded: value >> 40))
        out.append(UInt8(truncatingIfNeeded: value >> 32))
        out.append(UInt8(truncatingIfNeeded: value >> 24))
        out.append(UInt8(truncatingIfNeeded: value >> 16))
        out.append(UInt8(truncatingIfNeeded: value >> 8))
        out.append(UInt8(truncatingIfNeeded: value))
    }
}
