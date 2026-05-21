# SwiftCrossUI P2P

Kitchen-sink demo space for `swift-cross-ui` + `swift-libp2p`.

The first pass includes:

- a cross-platform SwiftCrossUI shell
- a deterministic libp2p node
- TCP + Noise + Yamux
- mDNS discovery
- KadDHT / DCUtR wiring

Run it with:

```sh
cd swift-cross-ui-p2p
swift run SwiftCrossUIP2P
```