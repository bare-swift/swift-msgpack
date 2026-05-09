// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// Errors thrown by ``MsgPack/decode(_:)``.
public enum MsgPackError: Error, Equatable, Sendable {
    /// Decoder ran out of bytes mid-message. `expected` is how many more
    /// bytes the format byte said to read.
    case truncated(needed: Int, available: Int)

    /// Format byte `0xC1` is reserved by MessagePack and must never appear
    /// on the wire.
    case reservedFormatByte

    /// String payload was not valid UTF-8.
    case invalidUTF8

    /// Map declared N entries but ran out of bytes before consuming them.
    case malformedMap

    /// Decoder finished a value but the input had more bytes after it.
    /// Not an error in streaming-decode contexts; ``MsgPack/decode(_:)``
    /// reports it because v0.1 takes a single full payload.
    case trailingBytes(consumed: Int, total: Int)
}
