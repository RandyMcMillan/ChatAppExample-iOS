import CryptoKit
import DefaultBackend
import Foundation
import LibP2P
import LibP2PDCUtR
import LibP2PKadDHT
import LibP2PMDNS
import LibP2PNoise
import LibP2PYAMUX
import SwiftCrossUI

#if os(iOS)
    import UIKit
#endif

@main
struct SwiftCrossUIP2PApp: App {
    @State var viewModel = P2PDemoViewModel()

    var body: some Scene {
        WindowGroup("SwiftCrossUI P2P") {
            ContentView(model: viewModel)
        }
        .defaultSize(width: 980, height: 760)
    }
}

@ObservableObject
final class P2PDemoViewModel {
    enum State: String {
        case stopped
        case starting
        case running
        case stopping
    }

    enum Demo: String, CaseIterable, Hashable {
        case overview = "Overview"
        case discovery = "Discovery"
        case catalog = "Module Catalog"
    }

    struct PeerSummary: Identifiable, Hashable {
        var id: String { peerID }
        let peerID: String
        let addresses: [String]
    }

    var selectedDemo: Demo? = .overview
    var state: State = .stopped
    var listenAddresses: [String] = []
    var discoveredPeers: [PeerSummary] = []
    var activityLog: [String] = []
    var lastError: String?
    var draftMessage = "Hello from SwiftCrossUI P2P"

    private var app: Application?
    private var runTask: Task<Void, Never>?

    let peerID: PeerID
    let runtimeProfile: String
    let listenPort: Int

    init() {
        runtimeProfile = Self.runtimeProfile.rawValue
        listenPort = Self.listenPort
        peerID = Self.makePeerID(for: Self.runtimeProfile)
    }

    var peerIDString: String {
        peerID.b58String
    }

    var isRunning: Bool {
        state == .running
    }

    func start() {
        guard runTask == nil else { return }

        lastError = nil
        state = .starting
        log("Starting libp2p node")

        let app = Self.makeApplication(peerID: peerID)
        self.app = app

        app.discovery.onPeerDiscovered(app) { [weak self] peer in
            Task { @MainActor in
                self?.recordDiscoveredPeer(
                    peerID: peer.peer.b58String,
                    addresses: peer.addresses.map(\.description)
                )
            }
        }

        app.eventLoopGroup.next().scheduleTask(in: .milliseconds(100)) { [weak self, weak app] in
            guard let self, let app else { return }
            let addresses = app.listenAddresses.compactMap { address -> String? in
                guard let fullAddress = try? address.encapsulate(proto: .p2p, address: app.peerID.b58String) else {
                    return nil
                }
                return fullAddress.description
            }

            Task { @MainActor in
                self.listenAddresses = addresses
                if !addresses.isEmpty {
                    self.log("Listening on: \(addresses.joined(separator: ", "))")
                }
                if self.state == .starting {
                    self.state = .running
                    self.log("Node is running")
                }
            }
        }

        runTask = Task.detached(priority: .background) { [weak self, app] in
            do {
                try await app.execute()
            } catch {
                await MainActor.run {
                    self?.lastError = error.localizedDescription
                    self?.log("Error: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self?.state = .stopped
                self?.runTask = nil
                self?.app = nil
                self?.listenAddresses = []
                self?.log("Node stopped")
            }
        }
    }

    func stop() {
        guard let app else { return }

        state = .stopping
        log("Stopping libp2p node")
        self.app = nil
        self.runTask = nil

        Task.detached(priority: .background) { [weak self] in
            do {
                try await app.asyncShutdown()
            } catch {
                await MainActor.run {
                    self?.lastError = error.localizedDescription
                    self?.log("Error: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self?.listenAddresses = []
                self?.state = .stopped
                self?.log("Node stopped")
            }
        }
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.start()
        }
    }

    func sendLocalPing() {
        log("Ping: \(draftMessage)")
    }

    private func recordDiscoveredPeer(peerID: String, addresses: [String]) {
        let peer = PeerSummary(peerID: peerID, addresses: addresses)
        if !discoveredPeers.contains(peer) {
            discoveredPeers.append(peer)
            log("Discovered peer \(peerID)")
        }
    }

    private func log(_ message: String) {
        let formatter = Self.timestampFormatter
        activityLog.append("[\(formatter.string(from: Date()))] \(message)")
    }

    private static func makeApplication(peerID: PeerID) -> Application {
        let app = Application(.testing, peerID: peerID)
        app.logger.logLevel = .notice
        app.security.use(.noise)
        app.muxers.use(.yamux)
        app.dcutr.use(.dcutr)
        app.discovery.use(.mdns)
        app.discovery.use(.kadDHT)
        app.listen(.tcp(host: "0.0.0.0", port: listenPort))
        return app
    }

    private static var runtimeProfile: RuntimeProfile {
        #if targetEnvironment(macCatalyst)
            return .macCatalyst
        #elseif os(macOS)
            return .macOS
        #elseif os(iOS)
            if ProcessInfo.processInfo.isiOSAppOnMac {
                return .madeForiPad
            }
            switch UIDevice.current.userInterfaceIdiom {
                case .pad:
                    return .iPad
                case .mac:
                    return .madeForiPad
                default:
                    return .iPhone
            }
        #else
            return .iPhone
        #endif
    }

    private static var listenPort: Int {
        if let value = ProcessInfo.processInfo.environment["P2P_LISTEN_PORT"],
           let port = Int(value),
           port > 0 {
            return port
        }

        switch runtimeProfile {
            case .macOS:
                return 12000
            case .iPhone:
                return 12001
            case .iPad:
                return 12002
            case .macCatalyst:
                return 12003
            case .madeForiPad:
                return 12004
        }
    }

    private static func makePeerID(for profile: RuntimeProfile) -> PeerID {
        let seed = Data(SHA256.hash(data: Data("SwiftCrossUIP2P.peerid.\(profile.rawValue)".utf8)))
        let privateKey = try! Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        return try! PeerID(marshaledPrivateKey: privateKey.marshal())
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private enum RuntimeProfile: String {
        case macOS
        case macCatalyst
        case iPad
        case iPhone
        case madeForiPad
    }
}

struct ContentView: View {
    @State var model: P2PDemoViewModel

    init(model: P2PDemoViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                controls
                demoPicker
                selectedDemo
                activityPanel
            }
            .padding(16)
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SwiftCrossUI P2P")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Cross-platform kitchen sink for libp2p demos")
            Text("Peer ID: \(model.peerIDString)")
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    var controls: some View {
        HStack {
            Button("Start") { model.start() }
            Button("Stop") { model.stop() }
                .disabled(!model.isRunning)
            Button("Restart") { model.restart() }
            Spacer()
            Text("State: \(model.state.rawValue.capitalized)")
        }
    }

    var demoPicker: some View {
        HStack {
            Text("Demo")
            Picker(
                of: P2PDemoViewModel.Demo.allCases,
                selection: Binding(
                    get: { model.selectedDemo },
                    set: { model.selectedDemo = $0 }
                )
            )
        }
    }

    @ViewBuilder
    var selectedDemo: some View {
        switch model.selectedDemo ?? .overview {
            case .overview:
                overviewPanel
            case .discovery:
                discoveryPanel
            case .catalog:
                catalogPanel
        }
    }

    var overviewPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview").font(.headline)
            Text("Runtime profile: \(model.runtimeProfile)")
            Text("Listen port: \(model.listenPort)")
            Text("Listening addresses:")
            ForEach(model.listenAddresses, id: \.self) { address in
                Text(address).font(.caption.monospaced())
            }
            if model.listenAddresses.isEmpty {
                Text("Start the node to populate listen addresses.")
            }
        }
        .padding(12)
    }

    var discoveryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discovery").font(.headline)
            Text("Peers discovered via mDNS and DHT.")
            ForEach(model.discoveredPeers, id: \.id) { peer in
                VStack(alignment: .leading, spacing: 4) {
                    Text(peer.peerID).font(.caption.monospaced())
                    ForEach(peer.addresses, id: \.self) { address in
                        Text(address).font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
            if model.discoveredPeers.isEmpty {
                Text("No peers discovered yet.")
            }
        }
        .padding(12)
    }

    var catalogPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Module Catalog").font(.headline)
            Text("This scaffold is wired for the same stack used by the samples.")
            moduleRow(name: "LibP2P", detail: "Core runtime and application lifecycle")
            moduleRow(name: "Noise", detail: "Secure transport handshake")
            moduleRow(name: "Yamux", detail: "Stream multiplexing")
            moduleRow(name: "mDNS", detail: "Local peer discovery")
            moduleRow(name: "KadDHT", detail: "Distributed peer discovery")
            moduleRow(name: "DCUtR", detail: "Hole punching support")
            HStack {
                TextField(
                    "Message",
                    text: Binding(
                        get: { model.draftMessage },
                        set: { model.draftMessage = $0 }
                    )
                )
                Button("Queue ping") { model.sendLocalPing() }
            }
        }
        .padding(12)
    }

    func moduleRow(name: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(name)
                .font(.body)
                .fontWeight(.bold)
                .frame(width: 90, alignment: .leading)
            Text(detail)
        }
    }

    var activityPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Activity").font(.headline)
                Spacer()
                Button("Clear") {
                    model.activityLog.removeAll()
                }
            }
            ForEach(model.activityLog, id: \.self) { line in
                Text(line)
                    .font(.caption.monospaced())
            }
            if let lastError = model.lastError {
                Text("Last error: \(lastError)")
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
    }
}
