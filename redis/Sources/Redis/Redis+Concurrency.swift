import NIOCore
import Vapor
import RediStack
import Foundation

extension Application.Redis {
    public func send(command: String, with arguments: [RESPValue]) async throws -> RESPValue {
        try await self.application.redis(self.id)
            .pool(for: self.eventLoop)
            .logging(to: self.application.logger)
            .send(command: command, with: arguments).get()
    }
    
    public func subscribe(
        to channels: [RedisChannelName],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) async throws {
        try await self.application.redis(self.id)
            .pubsubClient
            .logging(to: self.application.logger)
            .subscribe(to: channels, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
            .get()
    }
    
    public func unsubscribe(from channels: [RedisChannelName]) async throws {
        try await self.application.redis(self.id)
            .pubsubClient
            .logging(to: self.application.logger)
            .unsubscribe(from: channels)
            .get()
    }
    
    public func psubscribe(
        to patterns: [String],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) async throws {
        try await self.application.redis(self.id)
            .pubsubClient
            .logging(to: self.application.logger)
            .psubscribe(to: patterns, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
            .get()
    }
    
    public func punsubscribe(from patterns: [String]) async throws {
        try await self.application.redis(self.id)
            .pubsubClient
            .logging(to: self.application.logger)
            .punsubscribe(from: patterns)
            .get()
    }
}

extension Request.Redis {
    public func send(command: String, with arguments: [RESPValue]) async throws -> RESPValue {
        try await self.request.application.redis(self.id)
            .pool(for: self.eventLoop)
            .logging(to: self.request.logger)
            .send(command: command, with: arguments)
            .get()
    }
    
    public func subscribe(
        to channels: [RedisChannelName],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) async throws {
        try await self.request.application.redis(self.id)
            .pubsubClient
            .logging(to: self.request.logger)
            .subscribe(to: channels, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
            .get()
    }
    
    public func unsubscribe(from channels: [RedisChannelName]) async throws {
        try await self.request.application.redis(self.id)
            .pubsubClient
            .logging(to: self.request.logger)
            .unsubscribe(from: channels)
            .get()
    }
    
    public func psubscribe(
        to patterns: [String],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) async throws {
        try await self.request.application.redis(self.id)
            .pubsubClient
            .logging(to: self.request.logger)
            .psubscribe(to: patterns, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
            .get()
    }
    
    public func punsubscribe(from patterns: [String]) async throws {
        try await self.request.application.redis(self.id)
            .pubsubClient
            .logging(to: self.request.logger)
            .punsubscribe(from: patterns)
            .get()
    }
}
