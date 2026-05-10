// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Time

/// MessagePack timestamp extension type (ext-type id `−1`).
///
/// The spec (https://github.com/msgpack/msgpack/blob/master/spec.md#timestamp-extension-type)
/// defines three wire formats:
///
/// - **timestamp32** — 4-byte unsigned big-endian seconds, nanos = 0; covers
///   1970-01-01 to 2106-02-07.
/// - **timestamp64** — 8 bytes packing 30-bit nanos + 34-bit unsigned seconds;
///   covers 1970-01-01 to ~2514.
/// - **timestamp96** — 12 bytes: 32-bit unsigned nanos + 64-bit signed seconds;
///   covers any time in the `Time.Instant` range, including pre-epoch.
///
/// Encoder picks the smallest valid form; decoder handles all three.
extension MsgPackValue {
    /// Build a MessagePack timestamp ext-type value from a `Time.Instant`.
    /// Picks the shortest wire format that fits.
    public static func timestamp(_ instant: Time.Instant) -> MsgPackValue {
        let totalNanos = instant.nanosecondsSinceEpoch
        // Floor-divide towards negative infinity so nanos lives in [0, 1e9).
        var seconds = totalNanos / 1_000_000_000
        var nanos = totalNanos - seconds * 1_000_000_000
        if nanos < 0 {
            nanos += 1_000_000_000
            seconds -= 1
        }

        // timestamp32: nanos == 0, seconds fits in UInt32.
        if nanos == 0, seconds >= 0, seconds <= Int64(UInt32.max) {
            var b = Bytes(reservingCapacity: 4)
            appendBE32(UInt32(seconds), into: &b)
            return .ext(-1, b)
        }
        // timestamp64: seconds fits in 34 bits unsigned; nanos fits in 30 bits.
        if seconds >= 0, seconds < (Int64(1) << 34), nanos < (Int64(1) << 30) {
            let packed = (UInt64(nanos) << 34) | UInt64(seconds)
            var b = Bytes(reservingCapacity: 8)
            appendBE64(packed, into: &b)
            return .ext(-1, b)
        }
        // timestamp96: 32-bit unsigned nanos + 64-bit signed seconds.
        var b = Bytes(reservingCapacity: 12)
        appendBE32(UInt32(nanos), into: &b)
        appendBE64(UInt64(bitPattern: seconds), into: &b)
        return .ext(-1, b)
    }

    /// If this value is a MessagePack timestamp ext-type (id `−1`), return
    /// the equivalent `Time.Instant`. Otherwise return `nil`. Recognises
    /// all three wire formats per the spec.
    public var asTimestamp: Time.Instant? {
        guard case .ext(let id, let payload) = self, id == -1 else { return nil }
        let bytes = payload.storage
        switch bytes.count {
        case 4:
            // timestamp32
            let secs = readBE32(bytes, offset: 0)
            return Time.Instant(nanosecondsSinceEpoch: Int64(secs) * 1_000_000_000)
        case 8:
            // timestamp64: top 30 bits nanos, bottom 34 bits seconds
            let packed = readBE64(bytes, offset: 0)
            let nanos = Int64(packed >> 34)
            let seconds = Int64(packed & ((UInt64(1) << 34) - 1))
            return Time.Instant(nanosecondsSinceEpoch: seconds * 1_000_000_000 + nanos)
        case 12:
            // timestamp96
            let nanos = Int64(readBE32(bytes, offset: 0))
            let secsRaw = readBE64(bytes, offset: 4)
            let seconds = Int64(bitPattern: secsRaw)
            return Time.Instant(nanosecondsSinceEpoch: seconds * 1_000_000_000 + nanos)
        default:
            return nil
        }
    }

    private static func appendBE32(_ v: UInt32, into out: inout Bytes) {
        out.append(UInt8(truncatingIfNeeded: v >> 24))
        out.append(UInt8(truncatingIfNeeded: v >> 16))
        out.append(UInt8(truncatingIfNeeded: v >> 8))
        out.append(UInt8(truncatingIfNeeded: v))
    }

    private static func appendBE64(_ v: UInt64, into out: inout Bytes) {
        out.append(UInt8(truncatingIfNeeded: v >> 56))
        out.append(UInt8(truncatingIfNeeded: v >> 48))
        out.append(UInt8(truncatingIfNeeded: v >> 40))
        out.append(UInt8(truncatingIfNeeded: v >> 32))
        out.append(UInt8(truncatingIfNeeded: v >> 24))
        out.append(UInt8(truncatingIfNeeded: v >> 16))
        out.append(UInt8(truncatingIfNeeded: v >> 8))
        out.append(UInt8(truncatingIfNeeded: v))
    }
}

private func readBE32(_ b: ContiguousArray<UInt8>, offset: Int) -> UInt32 {
    var v: UInt32 = 0
    for i in 0..<4 { v = (v << 8) | UInt32(b[offset + i]) }
    return v
}

private func readBE64(_ b: ContiguousArray<UInt8>, offset: Int) -> UInt64 {
    var v: UInt64 = 0
    for i in 0..<8 { v = (v << 8) | UInt64(b[offset + i]) }
    return v
}
