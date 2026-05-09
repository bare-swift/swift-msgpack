// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// Sendable, Foundation-free MessagePack encoder + decoder.
///
/// Wire format: <https://github.com/msgpack/msgpack/blob/master/spec.md>.
///
/// `MsgPack.encode(_:)` round-trips a ``MsgPackValue`` to `Bytes`;
/// `MsgPack.decode(_:)` parses `Bytes` back into a ``MsgPackValue``.
/// The decoder rejects truncated input, the reserved `0xC1` format byte,
/// and length-mismatched containers via ``MsgPackError``.
public enum MsgPack: Sendable {
    /// Encode a ``MsgPackValue`` to its MessagePack wire form.
    public static func encode(_ value: MsgPackValue) -> Bytes {
        var out = Bytes(reservingCapacity: 32)
        Encoder.encode(value, into: &out)
        return out
    }

    /// Decode a MessagePack-encoded `Bytes` payload into a ``MsgPackValue``.
    public static func decode(_ bytes: Bytes) throws(MsgPackError) -> MsgPackValue {
        var cursor = 0
        let value = try Decoder.decode(bytes, cursor: &cursor)
        if cursor != bytes.count {
            throw .trailingBytes(consumed: cursor, total: bytes.count)
        }
        return value
    }
}
