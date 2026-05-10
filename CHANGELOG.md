# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.2.0] - 2026-05-10

### Added
- `MsgPackValue.timestamp(_ instant: Time.Instant) -> MsgPackValue` — build a MessagePack timestamp ext-type (id `−1`) value from a `Time.Instant`. Picks the shortest valid wire form: timestamp32 (4-byte) for whole-second positive-only instants up to year 2106, timestamp64 (8-byte) for sub-second instants up to year 2514, timestamp96 (12-byte) for everything else including pre-epoch.
- `MsgPackValue.asTimestamp: Time.Instant?` — decode a timestamp ext-type back into a `Time.Instant`. Returns `nil` for non-`ext(-1)` values or malformed payloads. Recognises all three wire formats per the spec.
- 10 new tests covering encode-format selection, round-trips through all three wire forms, pre-epoch instants, full `MsgPack.encode → decode` round-trip, and malformed-payload handling.

### Dependencies
- New: `swift-time` 0.1.0 — for the `Time.Instant` type used by the timestamp helpers.

### Migration
- Additive only. v0.1 consumers continue to work unchanged. Timestamp ext-type values still parse to `MsgPackValue.ext(-1, Bytes)`; the new `asTimestamp` getter is available alongside the raw form for opt-in adoption.

## [0.1.0] - 2026-05-09

### Added
- `MsgPackValue` value type (Sendable, Equatable) covering the 11 MessagePack wire types: `nil`, `bool`, `int`, `uint`, `float32`, `float64`, `string`, `binary`, `array`, `map`, `ext`.
- `MsgPackValue.MapEntry` for ordered, any-keyed map entries.
- `MsgPack.encode(_:) -> Bytes` — encoder that picks the shortest representation for each value (positive fixint over uint8 over uint16, etc.).
- `MsgPack.decode(_:) throws(MsgPackError) -> MsgPackValue` — recursive-descent decoder over the format-byte ladder; strict UTF-8 validation; rejects reserved `0xC1`; reports trailing bytes via `.trailingBytes`.
- `MsgPackError` typed-throws enum (`truncated`, `reservedFormatByte`, `invalidUTF8`, `malformedMap`, `trailingBytes`).

### Dependencies
- `swift-bytes` 0.1.0 — input/output buffer.

### Limitations (out of scope for v0.1)
- `Codable` bridging — deliberately excluded; Foundation-free + non-Codable is the differentiator.
- Streaming partial decode. v0.1 takes a single full `Bytes` payload.
- Timestamp ext-type semantic interpretation. Ext-type `-1` payloads pass through as raw bytes pending a Foundation-free date type (RFC-0010).
- The deprecated pre-2013 raw-string format. Decoder recognizes only the modern str8/str16/str32 formats.
