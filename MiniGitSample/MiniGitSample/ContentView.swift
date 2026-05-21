//
//  ContentView.swift
//  MiniGit Sample App
//
//  Created by Lightech on 10/24/2048.
//

import CryptoKit
import Foundation
import LibP2P
import SwiftUI
import GnostrGit
#if os(iOS)
import UIKit
#endif

let documentURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

let remoteRepoLocation = "https://github.com/randymcmillan/ChatAppExample-iOS.git"

func repoLocation(for remoteURL: String) -> URL {
    let repoFolderName = URL(string: remoteURL)?
        .deletingPathExtension()
        .lastPathComponent ?? "MiniGit-SampleApp"
    return documentURL.appendingPathComponent(repoFolderName)
}

let localRepoLocation = repoLocation(for: remoteRepoLocation)

// Do not do this in a real application, put the credentials somewhere safe
// And possibly encrypt them or keychain them by subclassing CredentialsManager
let credentialManager = CredentialsManager(credentialsFileUrl: documentURL.appendingPathComponent("gitcredentials"))

// For push/fetch to work, you might need to add the credential
var credentialAdded = false

func addCredential() {
    do {
        // TODO Change the info here
        try credentialManager.addOrUpdate(nil, Credential(id: "MyGithub", kind: .password, targetURL: "https://github.com/YOUR_USERNAME/", userName: "YOUR_USERNAME", password: "YOUR_ACCESS_TOKEN"))
        credentialAdded = true
        print("Credential added.")
    } catch let error {
        print("Fail to add credential:", error)
    }
}
let repository = GitRepository(localRepoLocation, credentialManager)

@MainActor
final class P2PService: ObservableObject {
    private enum RuntimeProfile: String {
        case macOS
        case macCatalyst
        case iPad
        case iPhone
        case madeForiPad
    }

    enum State: String {
        case stopped
        case starting
        case running
        case stopping
    }

    @Published private(set) var listenAddresses: [String] = []
    @Published private(set) var state: State = .stopped
    @Published private(set) var lastError: String?
    @Published private(set) var activityLog: [String] = []

    private var app: Application?
    private var runTask: Task<Void, Never>?

    let peerID: PeerID

    init() {
        peerID = Self.makePeerID(for: Self.runtimeProfile)
    }

    var runtimeProfile: String {
        Self.runtimeProfile.rawValue
    }

    var listenPort: Int {
        Self.listenPort
    }

    var stateLabel: String {
        state.rawValue.capitalized
    }

    var isRunning: Bool {
        state == .running
    }

    var peerIDString: String {
        peerID.b58String
    }

    func clearActivityLog() {
        activityLog.removeAll()
    }

    func start() {
        guard runTask == nil else { return }

        lastError = nil
        state = .starting
        log("Starting node")

        let app = Self.makeApplication(peerID: peerID)
        self.app = app

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
                self?.log("Executing libp2p application")
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
                self?.log("Node stopped")
            }
        }
    }

    func stop() {
        guard let app else { return }

        state = .stopping
        log("Stopping node")
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
                self?.runTask = nil
                self?.app = nil
                self?.log("Node stopped")
            }
        }
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
            return 10000
        case .iPhone:
            return 10001
        case .iPad:
            return 10002
        case .macCatalyst:
            return 10003
        case .madeForiPad:
            return 10004
        }
    }

    private static func makePeerID(for profile: RuntimeProfile) -> PeerID {
        let seed = Data(SHA256.hash(data: Data("MiniGitSample.peerid.\(profile.rawValue)".utf8)))
        let privateKey = try! Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        return try! PeerID(marshaledPrivateKey: privateKey.marshal())
    }

    private func log(_ message: String) {
        let formatter = Self.timestampFormatter
        activityLog.append("[\(formatter.string(from: Date()))] \(message)")
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

struct ContentView: View {

    @ObservedObject var repo = repository
    @ObservedObject var commitGraph = repository.commitGraph
    @ObservedObject var remoteProgress = repository.remoteProgress
    @StateObject private var p2p = P2PService()

    var body: some View {
        VStack {
            Text("On Mac Catalyst, you should be able to find the cloned repo in `~/Documents/\(localRepoLocation.lastPathComponent)/`.").italic()

            Button("Clone remote Git repo") {
                repo.clone(remoteRepoLocation)
                // We want to do repo.updateCommitGraph() but this will be invoked
                // on main thread so likely before clone finishes in background thread.
                // We don't want to do another callback so maybe await/async.
            }

            if remoteProgress.inProgress {
                ProgressView(remoteProgress.operation)
            }

            if repo.hasRepo {
                // Hide the buttons if there are operations in progress
                if !remoteProgress.inProgress {
                    Button("Push to origin") {
                        let allRemotes = repo.getRemotes()     // get the list of remotes
                        let remoteOrigin = allRemotes[0]       // assuming you have only one remote i.e. origin
                        repo.push(remoteOrigin, false)         // push all branches to the corresponding one in origin
                    }

                    Button("Fetch from origin") {
                        let allRemotes = repo.getRemotes()
                        let remoteOrigin = allRemotes[0]
                        repo.fetch(remoteOrigin)
                    }

                    Button("Merge origin/master into current branch") {
                        repo.updateCommitGraph()
                        for c in repo.commitGraph.commits {
                            for ref in c.refs {
                                if ref.name == "refs/remotes/origin/master" {
                                    print("Found", ref.name)
                                     repo.merge([ref]) // merge the changes in the remote repo "origin/master" into the local "master"
                                }
                            }
                        }
                    }
                }

                // At the moment, clone will update hasRepo after completion. So this
                // has the effect of automatically update the UI if the clone is successful.
                List(commitGraph.commits) { commit in
                    VStack(alignment: .leading) {
                        Text(commit.message).bold()
                        Text(commit.author.name)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Swift p2p network").font(.headline)
                Text("Runtime profile: \(p2p.runtimeProfile)")
                Text("Peer ID: \(p2p.peerIDString)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Text("Listen port: \(p2p.listenPort)")
                Text("State: \(p2p.stateLabel)")

                HStack {
                    Button("Start p2p node") {
                        p2p.start()
                    }
                    Button("Stop p2p node") {
                        p2p.stop()
                    }
                    .disabled(!p2p.isRunning)
                }

                if let lastError = p2p.lastError {
                    Text("Last error: \(lastError)")
                        .foregroundStyle(.red)
                }

                HStack {
                    Text("Network activity").font(.headline)
                    Spacer()
                    Button("Clear") {
                        p2p.clearActivityLog()
                    }
                }

                if p2p.activityLog.isEmpty {
                    Text("No activity yet")
                        .foregroundStyle(.secondary)
                } else {
                    List(p2p.activityLog, id: \.self) { entry in
                        Text(entry)
                            .font(.caption.monospaced())
                    }
                    .frame(minHeight: 180)
                }

                Text("Listening addresses").font(.subheadline.bold())
                if p2p.listenAddresses.isEmpty {
                    Text("No addresses yet")
                        .foregroundStyle(.secondary)
                } else {
                    List(p2p.listenAddresses, id: \.self) { address in
                        Text(address)
                            .font(.caption.monospaced())
                    }
                    .frame(minHeight: 140)
                }
            }
        }
        .padding(5)
        .onAppear {
            if !credentialAdded {
                addCredential()
            }
            repo.open()
            if repo.exists() {
                repo.updateCommitGraph()
            }
            p2p.start()
        }
        .onDisappear {
            p2p.stop()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
