import LibP2P

// configures your application
public func configure(_ app: Application) async throws {
    
    // We can specify the global log level here
    app.logger.logLevel = .notice

    // Install our modules on libp2p

    // Configure the modules to be used

    // register routes
    try routes(app)
    
    app.eventLoopGroup.next().scheduleTask(in: .milliseconds(100)) {
        for address in app.listenAddresses {
            let fullAddress = try address.encapsulate(proto: .p2p, address: app.peerID.b58String)
            app.logger.notice("Libp2p listening at \(fullAddress)")
        }
    }
}
