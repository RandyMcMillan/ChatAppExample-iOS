# LibP2P on iOS

This package vendors the upstream `cpp-libp2p` source release `v0.1.37` as a
local build tree.

The first step is to keep the source checked in under
`LibP2P-iOS/cpp-libp2p-0.1.37/` so we can build a separate libp2p package
without tying it to the libgit2 pipeline.

To start the Apple build, use `scripts/build-libp2p-framework.sh`. The current
defaults disable QUIC so the build can start without `lsquic`.

Upstream build notes:

- CMake minimum: 3.12
- C++ standard: C++20
- Default dependency manager: Hunter
- Supported protocols include TCP, Plaintext, SECIO, MPlex, Yamux,
  Kademlia DHT, Gossipsub, and Identify

The build integration still needs platform-specific dependency plumbing for
Apple targets.
