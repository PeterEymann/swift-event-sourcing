//
//  File.swift
//  
//
//  Created by Peter Eymann on 09/02/22.
//

import Foundation

struct Edge: Hashable {
    let leader: String
    let follower: String
    
    init (_ leader: String, _ follower: String) {
        self.leader = leader
        self.follower = follower
    }
}

public typealias ApplicationWithName = Application & HasName
public typealias LeaderApplication = Application & Leads
public typealias FollowerApplication = Application & Follows


public enum SystemErrors: Error, Equatable {
    case NotAFollowerClass(name: String)
    case NotAProcessorClass(name: String)
}

public class System {
    /// Can be used to define a system of applications. “t is constructed with a list of pipes which are each a list of application classes.
    /// From this list of lists it builds a graph defined by a dict of nodes that mappes application class names to application topics, and a list of edges.
    var edges: [Edge]
    var nodes: [String:ApplicationWithName.Type] = [:]
    var follows: [String:[String]] = [:]
    var leads: [String:[String]] = [:]
    var leaders: [String] {
        return Array(leads.keys)
    }
    var leadersOnly: [String] {
        var r: [String] = []
        for name in leads.keys {
            if !follows.keys.contains(name) {
                r.append(name)
            }
        }
        return r
    }
    var followers: [String] {
        return Array(follows.keys)
    }
    var processors: [String] {
        return Array(Set(leaders).intersection(followers))
    }
    
    public init (_ pipes: [[ApplicationWithName.Type]]) throws {
        var edges = Set<Edge>()
        // Build nodes and edges
        for pipe in pipes {
            var followerCls: ApplicationWithName.Type? = nil
            for cls in pipe {
                nodes[cls.name] = cls
                if followerCls == nil {
                    followerCls = cls
                } else {
                    let leaderCls = followerCls!
                    followerCls = cls
                    edges.insert(Edge(leaderCls.name, followerCls!.name))
                }
            }
        }
        self.edges = Array(edges)
        for edge in edges {
            if let _ = leads[edge.leader] {
                leads[edge.leader]!.append(edge.follower)
            } else {
                leads[edge.leader] = [edge.follower]
            }
            if let _ = follows[edge.follower] {
                follows[edge.follower]!.append(edge.leader)
            } else {
                follows[edge.follower] = [edge.leader]
            }
        }
        // check that followers are followers
        for name in follows.keys {
            if !(nodes[name] is Follower.Type) {
                throw SystemErrors.NotAFollowerClass(name: name)
            }
        }
        // check that processors are processors
        for name in processors {
            if !(nodes[name] is ProcessorApplication.Type) {
                throw SystemErrors.NotAProcessorClass(name: name)
            }
        }
    }
    
    func getAppCls(_ name: String) -> ApplicationWithName.Type {
        return nodes[name]!
    }
    
    func leaderCls(_ name: String) -> LeaderApplication.Type {
        let cls = getAppCls(name)
        return cls as! LeaderApplication.Type
    }
    
    func followerCls(_ name: String) -> FollowerApplication.Type {
        let cls = getAppCls(name)
        return cls as! FollowerApplication.Type
    }
}
