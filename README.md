# swift-msgpack

MessagePack encoder + decoder — Sendable, Foundation-free; outputs `Bytes` for wire use.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-msgpack.git", from: "0.1.0")
```

Then depend on the `MsgPack` product:

```swift
.product(name: "MsgPack", package: "swift-msgpack")
```

## Usage

```swift
import MsgPack
import Bytes

let value = MsgPackValue.map([
    .init(key: .string("name"), value: .string("alice")),
    .init(key: .string("age"),  value: .uint(30)),
    .init(key: .string("tags"), value: .array([.string("a"), .string("b")])),
])

let bytes: Bytes = MsgPack.encode(value)
let parsed = try MsgPack.decode(bytes)
// parsed == value
```

## Scope

`swift-msgpack` ships v0.1 with:

- `MsgPackValue` value type covering the 11 MessagePack wire types (`nil`, `bool`, `int`, `uint`, `float32`, `float64`, `string`, `binary`, `array`, `map`, `ext`).
- `MsgPack.encode(_:) -> Bytes` — picks the shortest representation for each value.
- `MsgPack.decode(_:) throws(MsgPackError) -> MsgPackValue` — strict UTF-8 validation; rejects reserved `0xC1`.
- `MsgPackError` typed-throws enum (`truncated`, `reservedFormatByte`, `invalidUTF8`, `malformedMap`, `trailingBytes`).
- Map keys preserve wire order and may be any `MsgPackValue` (not just strings).

Out of scope for v0.1:

- `Codable` bridging (deliberate — Foundation-free + non-Codable is the differentiator).
- Schema validation / type coercion. Decoder produces a `MsgPackValue`; mapping to user types is consumer code.
- Streaming partial decode. v0.1 takes a single full `Bytes` payload.
- Timestamp ext-type semantic interpretation. Ext-type `-1` payloads pass through as raw bytes; consumers wire to a date type when one lands in the ecosystem (RFC-0010).

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-msgpack/>

## Source

No upstream Rust crate; this is a native bare-swift package implementing the MessagePack spec directly.

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
