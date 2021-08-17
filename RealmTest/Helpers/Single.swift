//
//  Single.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 12.06.2021.
//

import Combine

extension Publishers {
    struct Single<Upstream: Publisher>: Publisher {
        typealias Output = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        
        fileprivate init(upstream: Upstream) {
            self.upstream = upstream
        }
        
        func receive<S: Subscriber>(subscriber: S) where Upstream.Failure == S.Failure, Upstream.Output == S.Input {
            subscriber.receive(subscription: SingleSubscription(upstream: upstream, downstream: subscriber))
        }
    }
}

fileprivate extension Publishers.Single {
    final class SingleSubscription<Downstream: Subscriber>: Subscription where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure {
        private var sink: SingleSink<Upstream, Downstream>?
        
        init(upstream: Upstream, downstream: Downstream) {
            sink = SingleSink(upstream: upstream, downstream: downstream)
        }
        
        func request(_ demand: Subscribers.Demand) { }
        
        func cancel() {
            sink = nil
        }
    }
}

fileprivate final class SingleSink<Upstream: Publisher, Downstream: Subscriber>: Subscriber where Upstream.Output == Downstream.Input, Downstream.Failure == Upstream.Failure {
    private var downstream: Downstream
    private var element: Upstream.Output?
    
    init(upstream: Upstream, downstream: Downstream) {
        self.downstream = downstream
        upstream.subscribe(self)
    }
    
    func receive(subscription: Subscription) {
        subscription.request(.max(1))
    }
    
    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        element = input
        _ = downstream.receive(input)
        downstream.receive(completion: .finished)
        
        return .none
    }
    
    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        switch completion {
        case .failure(let err):
            downstream.receive(completion: .failure(err))
        case .finished:
            if element == nil {
                assertionFailure("❌ Sequence doesn't contain any elements.")
                downstream.receive(completion: completion)
            }
        }
    }
}

typealias AnySinglePublisher<Output, Failure: Error> = Publishers.Single<AnyPublisher<Output, Failure>>

extension Publisher {
    fileprivate func asSingle() -> Publishers.Single<Self> {
        return Publishers.Single(upstream: self)
    }
    
    func eraseToAnySinglePublisher() -> AnySinglePublisher<Output, Failure> {
        return Publishers.Single(upstream: self.eraseToAnyPublisher())
    }
}
