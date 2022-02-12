//
//  File.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
//

import Foundation

public struct ProcessEvent {
    /// Represents an actual occasion of processing
    let tracking: Tracking
    var events: [DomainEvent] = []
    
    mutating func collect(aggregates: [CollectsDomainEvents]) {
        for aggregate in aggregates {
            for event in aggregate.collect() {
                events.append(event)
            }
        }
    }
}


public struct DomainPolicy {
    /// Define a policy that can take different actions depending on the type of domain event.”
    let eventType: DomainEvent.Type
    let action: (DomainEvent, inout ProcessEvent) -> Void
}


public protocol HasPolicies {
    var policies: [DomainPolicy] { get set }
    func applyPolicies(_ event: DomainEvent, processEvent: inout ProcessEvent)
    mutating func addPolicy(_ policy: DomainPolicy)
}

extension HasPolicies {
    mutating public func addPolicy(_ policy: DomainPolicy) {
        policies.append(policy)
    }
    
    public func applyPolicies(_ event: DomainEvent, processEvent: inout ProcessEvent) {
        for policy in policies {
            if type(of: event) == policy.eventType {
                policy.action(event, &processEvent)
            }
        }
    }
}
