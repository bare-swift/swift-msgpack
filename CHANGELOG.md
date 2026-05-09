# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
