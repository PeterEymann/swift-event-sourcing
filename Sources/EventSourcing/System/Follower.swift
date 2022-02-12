//
//  File.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
//

import Foundation

public protocol Promptable {
    func receivePrompt(leaderName: String)
}

public struct Reader {
    let reader: NotificationLogReader
    let mapper: MapsDomainEvents
}

public protocol Follows: Application & Promptable & HasPolicies {
    var readers: [String:Reader] { get set }
    func follow(name: String, log: NotificationLog)
}

extension Follows {
    func pullAndProcess(name: String) {
        let start = (recorder as! ProcessRecorder).maxTrackingId(applicationName: name) + 1
        for notification in readers[name]!.reader.read(start: start) {
            let domainEvent = try! readers[name]!.mapper.toDomainEvent(notification.storedEvent)
            var processEvent = ProcessEvent(tracking: Tracking(applicationName: name, notificationId: notification.id))
            applyPolicies(domainEvent, processEvent: &processEvent)
            record(processEvent)
        }
    }
    
    func record(_ processEvent: ProcessEvent) {
        try! events.put(processEvent.events, tracking: processEvent.tracking)
    }
    
    public func follow(name: String, log: NotificationLog) {
        let reader = NotificationLogReader(log)
        let mapper = factory.buildMapper(applicationName: name)
        readers[name] = Reader(reader: reader, mapper: mapper)
    }
    
    public func receivePrompt(leaderName: String) {
        pullAndProcess(name: leaderName)
    }
}

open class Follower: Application, Follows {
    public var policies: [DomainPolicy] = []
    public var readers: [String:Reader] = [:]
    override class func buildRecorder(infrastructureFactory: CreatesInfrastructure) -> ApplicationRecorder {
        return infrastructureFactory.buildProcessRecorder()
    }
}

public protocol ProcessorApplication: Follower & Leads {
}
