// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// A parsed MessagePack value. Mirrors the spec's type system one-to-one.
///
/// Integers split into signed (``int(_:)``) and unsigned (``uint(_:)``)
/// because MessagePack distinguishes them on the wire and unsigned values
/// can exceed `Int64.max`. Decoders preserve whichever form was used by
/// the encoder.
///
/// `map` is an *ordered* list of `(key, value)` entries. MessagePack keys
/// can be any value type, so `[String: MsgPackValue]` would lose
/// information; `MapEntry` keeps the wire-order intact for round-tripping.
public indirect enum MsgPackValue: Sendable, Equatable {
    case `nil`
    case bool(Bool)
    case int(Int64)
    case uint(UInt64)
    case float32(Float)
    case float64(Double)
    case string(String)
    case binary(Bytes)
    case array([MsgPackValue])
    case map([MapEntry])
    case ext(Int8, Bytes)

    /// One key/value entry inside a MessagePack `map`. Stored as a struct
    /// rather than a tuple so the enclosing `MsgPackValue` can derive
    /// `Equatable` (tuples are Equatable in Swift; arrays of tuples are
    /// not, because they require element conformance).
    public struct MapEntry: Sendable, Equatable {
        public var key: MsgPackValue
        public var value: MsgPackValue

        public init(key: MsgPackValue, value: MsgPackValue) {
            self.key = key
            self.value = value
        }
    }
}
