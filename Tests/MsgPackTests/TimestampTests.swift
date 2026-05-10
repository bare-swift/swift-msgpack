// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import MsgPack
import Time
import Bytes

@Suite("Timestamp ext-type integration with swift-time")
struct TimestampTests {
    @Test("epoch encodes as timestamp32 (4-byte ext)")
    func epochCompact() {
        let v = MsgPackValue.timestamp(.unixEpoch)
        guard case .ext(let id, let payload) = v else { Issue.record(); return }
        #expect(id == -1)
        #expect(payload.count == 4)
    }

    @Test("non-zero nanos forces timestamp64 (8-byte ext)")
    func subSecondCompact() {
        let i = Time.Instant(nanosecondsSinceEpoch: 1_500_000_000) // 1.5 sec post-epoch
        let v = MsgPackValue.timestamp(i)
        guard case .ext(let id, let payload) = v else { Issue.record(); return }
        #expect(id == -1)
        #expect(payload.count == 8)
    }

    @Test("pre-epoch instant forces timestamp96 (12-byte ext)")
    func preEpochCompact() {
        let i = Time.Instant(nanosecondsSinceEpoch: -1_000_000_000) // 1 sec pre-epoch
        let v = MsgPackValue.timestamp(i)
        guard case .ext(let id, let payload) = v else { Issue.record(); return }
        #expect(id == -1)
        #expect(payload.count == 12)
    }

    @Test("epoch round-trip")
    func epochRoundTrip() {
        let v = MsgPackValue.timestamp(.unixEpoch)
        #expect(v.asTimestamp == .unixEpoch)
    }

    @Test("subsecond instant round-trip via timestamp64")
    func subSecondRoundTrip() {
        let i = Time.Instant(nanosecondsSinceEpoch: 1_700_000_000_123_456_789)
        let v = MsgPackValue.timestamp(i)
        #expect(v.asTimestamp == i)
    }

    @Test("pre-epoch round-trip via timestamp96")
    func preEpochRoundTrip() {
        let i = Time.Instant(nanosecondsSinceEpoch: -1_500_000_000)
        let v = MsgPackValue.timestamp(i)
        #expect(v.asTimestamp == i)
    }

    @Test("MsgPack.encode + decode preserves timestamp")
    func wireRoundTrip() throws {
        let i = Time.Instant(nanosecondsSinceEpoch: 1_700_000_000_500_000_000)
        let original = MsgPackValue.timestamp(i)
        let bytes = MsgPack.encode(original)
        let decoded = try MsgPack.decode(bytes)
        #expect(decoded.asTimestamp == i)
    }

    @Test("non-ext value: asTimestamp returns nil")
    func nonExt() {
        #expect(MsgPackValue.string("not a time").asTimestamp == nil)
        #expect(MsgPackValue.int(42).asTimestamp == nil)
        #expect(MsgPackValue.nil.asTimestamp == nil)
    }

    @Test("ext-type with non-(-1) id: asTimestamp returns nil")
    func wrongExtID() {
        let v = MsgPackValue.ext(5, Bytes(reservingCapacity: 0))
        #expect(v.asTimestamp == nil)
    }

    @Test("ext(-1) with malformed payload: asTimestamp returns nil")
    func malformedPayload() {
        var b = Bytes(reservingCapacity: 3)
        b.append(0x00); b.append(0x00); b.append(0x00)
        let v = MsgPackValue.ext(-1, b)  // 3 bytes — not 4/8/12
        #expect(v.asTimestamp == nil)
    }
}
