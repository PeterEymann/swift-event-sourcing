//
//  File.swift
//  
//
//  Created by Peter Eymann on 09/02/22.
//

import Foundation

public protocol Leads: Application & HasPolicies & NotifiesEvents & HasName {
    var followers: [Promptable] { get set }
    func lead(_ follower: Promptable)
}

extension Leads {
    func getName() -> String {
        return Self.name
    }
    
    public func lead(_ follower: Promptable) {
        followers.append(follower)
    }

    func promptFollowers() {
        for follower in followers {
            follower.receivePrompt(leaderName: Self.name)
        }
    }

    public func notify(newEvents: [DomainEvent]) {
        if !newEvents.isEmpty {
            promptFollowers()
        }
    }
}



