// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import MsgPack
import Bytes

/// Helper: spec-canonical byte vectors as `[UInt8]` literals.
private func bytes(_ raw: [UInt8]) -> Bytes {
    var b = Bytes(reservingCapacity: raw.count)
    for x in raw { b.append(x) }
    return b
}

private func raw(_ b: Bytes) -> [UInt8] { Array(b.storage) }

@Suite("Encoder — primitives")
struct EncoderPrimitivesTests {
    @Test("nil → 0xC0")
    func encodeNil() {
        #expect(raw(MsgPack.encode(.nil)) == [0xC0])
    }

    @Test("false → 0xC2; true → 0xC3")
    func encodeBool() {
        #expect(raw(MsgPack.encode(.bool(false))) == [0xC2])
        #expect(raw(MsgPack.encode(.bool(true))) == [0xC3])
    }

    @Test("positive fixint range")
    func positiveFixint() {
        #expect(raw(MsgPack.encode(.uint(0))) == [0x00])
        #expect(raw(MsgPack.encode(.uint(127))) == [0x7F])
        #expect(raw(MsgPack.encode(.int(0))) == [0x00])
        #expect(raw(MsgPack.encode(.int(127))) == [0x7F])
    }

    @Test("negative fixint range")
    func negativeFixint() {
        #expect(raw(MsgPack.encode(.int(-1))) == [0xFF])
        #expect(raw(MsgPack.encode(.int(-32))) == [0xE0])
    }

    @Test("uint ladder picks shortest")
    func uintLadder() {
        #expect(raw(MsgPack.encode(.uint(128))) == [0xCC, 0x80])              // uint8
        #expect(raw(MsgPack.encode(.uint(256))) == [0xCD, 0x01, 0x00])        // uint16
        #expect(raw(MsgPack.encode(.uint(65536))) == [0xCE, 0x00, 0x01, 0x00, 0x00])  // uint32
        #expect(raw(MsgPack.encode(.uint(UInt64(UInt32.max) + 1))) == [0xCF, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])
    }

    @Test("negative int ladder picks shortest")
    func negativeIntLadder() {
        #expect(raw(MsgPack.encode(.int(-33))) == [0xD0, 0xDF])               // int8
        #expect(raw(MsgPack.encode(.int(-129))) == [0xD1, 0xFF, 0x7F])        // int16
        #expect(raw(MsgPack.encode(.int(Int64(Int32.min)))) == [0xD2, 0x80, 0x00, 0x00, 0x00])
        #expect(raw(MsgPack.encode(.int(Int64.min))) == [0xD3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    @Test("float32 1.0 → 0xCA 3F 80 00 00")
    func float32() {
        #expect(raw(MsgPack.encode(.float32(1.0))) == [0xCA, 0x3F, 0x80, 0x00, 0x00])
    }

    @Test("float64 1.0 → 0xCB 3F F0 00 00 00 00 00 00")
    func float64() {
        #expect(raw(MsgPack.encode(.float64(1.0))) == [0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }
}

@Suite("Encoder — strings, binary, containers, ext")
struct EncoderCompositesTests {
    @Test("empty fixstr")
    func emptyFixstr() {
        #expect(raw(MsgPack.encode(.string(""))) == [0xA0])
    }

    @Test("fixstr 'a'")
    func fixstrA() {
        #expect(raw(MsgPack.encode(.string("a"))) == [0xA1, 0x61])
    }

    @Test("fixstr boundary: 31 bytes")
    func fixstrBoundary() {
        let s = String(repeating: "x", count: 31)
        let b = MsgPack.encode(.string(s))
        #expect(b.storage.first == 0xBF)
        #expect(b.count == 32)
    }

    @Test("str8: 32 bytes")
    func str8() {
        let s = String(repeating: "x", count: 32)
        let b = MsgPack.encode(.string(s))
        #expect(b.storage[0] == 0xD9)
        #expect(b.storage[1] == 32)
        #expect(b.count == 34)
    }

    @Test("bin8 empty")
    func bin8Empty() {
        #expect(raw(MsgPack.encode(.binary(Bytes()))) == [0xC4, 0x00])
    }

    @Test("bin8 with payload")
    func bin8Payload() {
        let b = MsgPack.encode(.binary(bytes([0x01, 0x02, 0x03])))
        #expect(raw(b) == [0xC4, 0x03, 0x01, 0x02, 0x03])
    }

    @Test("empty fixarray")
    func emptyFixarray() {
        #expect(raw(MsgPack.encode(.array([]))) == [0x90])
    }

    @Test("fixarray [1, 2, 3]")
    func fixarray123() {
        #expect(raw(MsgPack.encode(.array([.uint(1), .uint(2), .uint(3)]))) == [0x93, 0x01, 0x02, 0x03])
    }

    @Test("empty fixmap")
    func emptyFixmap() {
        #expect(raw(MsgPack.encode(.map([]))) == [0x80])
    }

    @Test("fixmap {a: 1}")
    func fixmapSingle() {
        let m = MsgPackValue.map([
            .init(key: .string("a"), value: .uint(1))
        ])
        // 0x81 (fixmap-1), 0xA1 'a' 0x61, 0x01
        #expect(raw(MsgPack.encode(m)) == [0x81, 0xA1, 0x61, 0x01])
    }

    @Test("fixext 1 (id=0x05, payload=0xAB) → 0xD4 0x05 0xAB")
    func fixext1() {
        let v = MsgPackValue.ext(0x05, bytes([0xAB]))
        #expect(raw(MsgPack.encode(v)) == [0xD4, 0x05, 0xAB])
    }

    @Test("ext 8 (3-byte payload) → 0xC7 0x03 id payload")
    func ext8() {
        let v = MsgPackValue.ext(0x42, bytes([0x01, 0x02, 0x03]))
        #expect(raw(MsgPack.encode(v)) == [0xC7, 0x03, 0x42, 0x01, 0x02, 0x03])
    }
}

@Suite("Decoder — primitives")
struct DecoderPrimitivesTests {
    @Test("nil")
    func decodeNil() throws {
        #expect(try MsgPack.decode(bytes([0xC0])) == .nil)
    }

    @Test("bool")
    func decodeBool() throws {
        #expect(try MsgPack.decode(bytes([0xC2])) == .bool(false))
        #expect(try MsgPack.decode(bytes([0xC3])) == .bool(true))
    }

    @Test("positive fixint")
    func positiveFixint() throws {
        #expect(try MsgPack.decode(bytes([0x00])) == .uint(0))
        #expect(try MsgPack.decode(bytes([0x7F])) == .uint(127))
    }

    @Test("negative fixint")
    func negativeFixint() throws {
        #expect(try MsgPack.decode(bytes([0xFF])) == .int(-1))
        #expect(try MsgPack.decode(bytes([0xE0])) == .int(-32))
    }

    @Test("uint ladder")
    func uintLadder() throws {
        #expect(try MsgPack.decode(bytes([0xCC, 0xFF])) == .uint(255))
        #expect(try MsgPack.decode(bytes([0xCD, 0x10, 0x00])) == .uint(4096))
        #expect(try MsgPack.decode(bytes([0xCE, 0x00, 0x01, 0x00, 0x00])) == .uint(65536))
    }

    @Test("int ladder")
    func intLadder() throws {
        #expect(try MsgPack.decode(bytes([0xD0, 0x80])) == .int(-128))
        #expect(try MsgPack.decode(bytes([0xD1, 0xFF, 0x7F])) == .int(-129))
    }

    @Test("float64 1.0 round-trip")
    func float64() throws {
        #expect(try MsgPack.decode(bytes([0xCB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])) == .float64(1.0))
    }
}

@Suite("Decoder — strings, binary, containers")
struct DecoderCompositesTests {
    @Test("fixstr 'hi'")
    func fixstrHi() throws {
        #expect(try MsgPack.decode(bytes([0xA2, 0x68, 0x69])) == .string("hi"))
    }

    @Test("str8 32-byte string")
    func str8() throws {
        var v: [UInt8] = [0xD9, 32]
        for _ in 0..<32 { v.append(UInt8(ascii: "x")) }
        let decoded = try MsgPack.decode(bytes(v))
        #expect(decoded == .string(String(repeating: "x", count: 32)))
    }

    @Test("bin8 round-trip")
    func bin8() throws {
        let decoded = try MsgPack.decode(bytes([0xC4, 0x03, 0x01, 0x02, 0x03]))
        #expect(decoded == .binary(bytes([0x01, 0x02, 0x03])))
    }

    @Test("fixarray [1, 2, 3]")
    func fixarray() throws {
        #expect(try MsgPack.decode(bytes([0x93, 0x01, 0x02, 0x03])) == .array([.uint(1), .uint(2), .uint(3)]))
    }

    @Test("fixmap {a: 1}")
    func fixmap() throws {
        let m = try MsgPack.decode(bytes([0x81, 0xA1, 0x61, 0x01]))
        #expect(m == .map([.init(key: .string("a"), value: .uint(1))]))
    }

    @Test("fixext1 round-trip")
    func fixext1() throws {
        #expect(try MsgPack.decode(bytes([0xD4, 0x05, 0xAB])) == .ext(0x05, bytes([0xAB])))
    }
}

@Suite("Decoder — error paths")
struct DecoderErrorTests {
    @Test("0xC1 reserved byte throws")
    func reserved() {
        #expect(throws: MsgPackError.reservedFormatByte) {
            try MsgPack.decode(bytes([0xC1]))
        }
    }

    @Test("empty input throws .truncated")
    func empty() {
        #expect(throws: MsgPackError.truncated(needed: 1, available: 0)) {
            try MsgPack.decode(bytes([]))
        }
    }

    @Test("truncated uint16 throws")
    func truncatedUInt16() {
        #expect(throws: (any Error).self) {
            try MsgPack.decode(bytes([0xCD, 0x10]))
        }
    }

    @Test("truncated array throws")
    func truncatedArray() {
        // fixarray-2 promises 2 elements but only 1 follows
        #expect(throws: (any Error).self) {
            try MsgPack.decode(bytes([0x92, 0x01]))
        }
    }

    @Test("trailing bytes after valid value throws")
    func trailingBytes() {
        #expect(throws: (any Error).self) {
            try MsgPack.decode(bytes([0xC0, 0xC0]))
        }
    }

    @Test("invalid UTF-8 in str8 throws .invalidUTF8")
    func invalidUTF8() {
        // 0xD9 (str8), length=2, then 0xC0 0x28 — 0xC0 is invalid UTF-8 lead.
        #expect(throws: MsgPackError.invalidUTF8) {
            try MsgPack.decode(bytes([0xD9, 0x02, 0xC0, 0x28]))
        }
    }
}

@Suite("Round-trip")
struct RoundTripTests {
    @Test("nested map with mixed types")
    func nested() throws {
        let original = MsgPackValue.map([
            .init(key: .string("name"), value: .string("alice")),
            .init(key: .string("age"), value: .uint(30)),
            .init(key: .string("active"), value: .bool(true)),
            .init(key: .string("tags"), value: .array([.string("a"), .string("b")])),
            .init(key: .string("score"), value: .float64(95.5)),
            .init(key: .string("blob"), value: .binary(bytes([0xDE, 0xAD, 0xBE, 0xEF]))),
            .init(key: .string("note"), value: .nil),
        ])
        let encoded = MsgPack.encode(original)
        let decoded = try MsgPack.decode(encoded)
        #expect(decoded == original)
    }

    @Test("non-string map keys preserve")
    func nonStringKeys() throws {
        let original = MsgPackValue.map([
            .init(key: .uint(1), value: .string("one")),
            .init(key: .uint(2), value: .string("two")),
        ])
        let decoded = try MsgPack.decode(MsgPack.encode(original))
        #expect(decoded == original)
    }

    @Test("Unicode string round-trip")
    func unicode() throws {
        let s = "héllo, 世界 🎉"
        let decoded = try MsgPack.decode(MsgPack.encode(.string(s)))
        #expect(decoded == .string(s))
    }

    @Test("large array (>16 entries → array16 format)")
    func largeArray() throws {
        let xs: [MsgPackValue] = (0..<100).map { .uint(UInt64($0)) }
        let original = MsgPackValue.array(xs)
        let encoded = MsgPack.encode(original)
        #expect(encoded.storage.first == 0xDC)  // array16 format
        let decoded = try MsgPack.decode(encoded)
        #expect(decoded == original)
    }
}
