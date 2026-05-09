# ``MsgPack``

MessagePack encoder + decoder — Sendable, Foundation-free.

## Overview

`MsgPack` parses and serializes the MessagePack binary format
(<https://github.com/msgpack/msgpack/blob/master/spec.md>) without
relying on Foundation or `Codable`. Input and output are `Bytes`.

The encoder picks the shortest representation for each value
(positive fixint over uint8 over uint16, etc.); the decoder accepts
all valid format bytes and rejects the reserved `0xC1`. UTF-8
validation is strict on string payloads — invalid sequences surface
as ``MsgPackError/invalidUTF8`` rather than silently substituting
replacement characters.

```swift
import MsgPack

let value = MsgPackValue.map([
    .init(key: .string("name"), value: .string("alice")),
    .init(key: .string("age"),  value: .uint(30)),
])
let bytes = MsgPack.encode(value)              // → Bytes wire form
let parsed = try MsgPack.decode(bytes)         // round-trips
```

## Topics

### Essentials

- ``MsgPackValue``
- ``MsgPackError``
