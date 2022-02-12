//
//  File.swift
//  
//
//  Created by Peter Eymann on 09/02/22.
//

import Foundation


public enum RunnerError: Error {
    case AlreadyStarted
}

public protocol Runner {
    func start() throws
    func stop()
    func get<T: Application & HasName>(_ cls: T.Type) -> T
}


public class SingleThreadedRunner: Promptable, Runner {
    let system: System
    internal var isStarted: Bool = false
    internal var isPrompting: Bool = false
    var apps: [String:Application] = [:]
    var promptsReceived: [String] = []
    
    public init (system: System) {
        self.system = system
    }
        
    public func start() throws {
        if isStarted {
            throw RunnerError.AlreadyStarted
        }
        isStarted = true
        // construct followers
        for name in system.followers {
            let app = system.followerCls(name).init()
            apps[name] = app
        }
        // construct leaders
        for name in system.leadersOnly {
            let app = system.leaderCls(name).init()
            apps[name] = app
        }
        // lead and follow
        for edge in system.edges {
            let leader = apps[edge.leader]! as! Leads & HasName
            leader.lead(self)
            (apps[edge.follower]! as! Follows).follow(name: leader.getName(), log: leader.log)
        }
    }
    
    public func receivePrompt(leaderName: String) {
        if !promptsReceived.contains(leaderName) {
            promptsReceived.append(leaderName)
        }
        if !isPrompting {
            isPrompting = true
            while !promptsReceived.isEmpty {
                let prompt = promptsReceived.removeFirst()
                for name in system.leads[prompt]! {
                    (apps[name]! as! Follows).receivePrompt(leaderName: prompt)
                }
            }
            isPrompting = false
        }
    }
    
    public func stop() {
        apps.removeAll()
        isStarted = false
    }
    
    public func get<T>(_ cls: T.Type) -> T where T : Application & HasName {
        return apps[cls.name]! as! T
    }
}
