import Foundation
import EventSourcing
import OpenGL


public struct CargoState: AggregateState {
    public let id: UUID
    public var version: Int
    public let createdOn: Date
    public var modifiedOn: Date
    
    let origin: Location
    var destination: Location
    let arrivalDeadline: Date
    
    var transportStatus: String = "NOT_RECEIVED"
    var routingStatus: String = "NOT_ROUTED"
    var isMisdirected: Bool = false
    var estimatedTimeOfArrival: Date? = nil
    var nextExpectedActivity: NextExpectedActivity? = nil
    var route: Itinerary? = nil
    var lastKnownLocation: Location? = nil
    var currentVoyageNumber: String? = nil
}


protocol CargoEvent: AggregateEvent {
    func apply(obj: Cargo) throws
}

extension CargoEvent {
    func apply<T>(obj: inout T) throws where T : Aggregate {
        if let cargo = obj as? Cargo {
            try apply(obj: cargo)
        }
    }
    
    func apply(obj: Cargo) throws {}
}


public enum CargoError: Error {
    case NoRouteSet
    case LegNotFound(origin: Location, voyageNumber: String)
    case AssertionError
    case UnknownHandlingEvent
}

public class Cargo: GenericAggregate, Aggregate {
    public typealias State = CargoState
    public var state: CargoState
    public var pendingEvents: [DomainEvent] = []
    public override class var events: [DomainEvent.Type] {
        return [BookingStarted.self, DestinationChanged.self, RouteAssigned.self, HandlingEventRegistered.self]
    }
    
    public var origin: Location {
        state.origin
    }

    public var destination: Location {
        state.destination
    }
    
    public var arrivalDeadline: Date {
        state.arrivalDeadline
    }
    
    public var transportStatus: String {
        state.transportStatus
    }
    
    public var routingStatus: String {
        state.routingStatus
    }
    
    public var isMisdirected: Bool {
        state.isMisdirected
    }
    
    public var estimatedTimeOfArrival: Date? {
        state.estimatedTimeOfArrival
    }
    
    public var nextExpectedActivity: NextExpectedActivity? {
        state.nextExpectedActivity
    }
    
    public var lastKnownLocation: Location? {
        state.lastKnownLocation
    }
    
    public var currentVoyageNumber: String? {
        state.currentVoyageNumber
    }
    
    required public init(state: CargoState) {
        self.state = state
        super.init()
    }
    
    convenience init(id: UUID, version: Int, timeStamp: Date, origin: Location, destination: Location, arrivalDeadline: Date) {
        self.init(state: CargoState(
            id: id, version: version, createdOn: timeStamp, modifiedOn: timeStamp,
            origin: origin, destination: destination, arrivalDeadline: arrivalDeadline
        ))
    }
    
    public class func newBooking(origin: Location, destination: Location, arrivalDeadline: Date) -> Cargo {
        return try! Cargo.makeAggregate(eventType: BookingStarted.self, payload: [
            "origin": origin,
            "destination": destination,
            "arrivalDeadline": arrivalDeadline
        ])
    }
    
    struct BookingStarted: CargoEvent, AggregateCreatedEvent {
        var originatorTopic: String
        let origin: Location
        let destination: Location
        let arrivalDeadline: Date

        func createAggregate() -> Cargo {
            return Cargo(
                id: originatorId, version: originatorVersion, timeStamp: timeStamp,
                origin: origin, destination: destination, arrivalDeadline: arrivalDeadline
            )
        }
        
        typealias AggregateType = Cargo
        
        var data: DomainEventData
        
        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
            originatorTopic = jsonDict["originatorTopic"] as! String
            origin = jsonDict["origin"] as! Location
            destination = jsonDict["destination"] as! Location
            arrivalDeadline = jsonDict["arrivalDeadline"] as! Date
        }
    }
    
    public func changeDestination(to newDestination: Location) {
        try! self.triggerEvent(DestinationChanged.self, for: self, payload: ["newDestination": newDestination])
    }
    
    struct DestinationChanged: CargoEvent {
        let data: DomainEventData
        let newDestination: Location
        
        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
            newDestination = jsonDict["newDestination"] as! Location
        }
        
        func apply(obj: Cargo) throws {
            obj.state.destination = newDestination
        }
    }
    
    public func assignRoute(itinerary: Itinerary) {
        try! self.triggerEvent(RouteAssigned.self, for: self, payload: ["itinerary": itinerary])
    }
    
    struct RouteAssigned: CargoEvent {
        let data: DomainEventData
        let itinerary: Itinerary
        
        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
            itinerary = jsonDict["itinerary"] as! Itinerary
        }
        
        func apply(obj: Cargo) throws {
            obj.state.route = itinerary
            obj.state.routingStatus = "ROUTED"
            obj.state.estimatedTimeOfArrival = Date(timeIntervalSinceNow: 7*24*60*60)
            obj.state.nextExpectedActivity = NextExpectedActivity(activity: HandlingActivity.Receive, location: obj.origin)
            obj.state.isMisdirected = false
        }
    }
    
    public func registerHandlingEvent(voyageNumber: String?, location: Location, handlingActivity: HandlingActivity) throws {
        var payload: JSONDict = [
            "location": location,
            "handlingActivity": handlingActivity
        ]
        if voyageNumber != nil {
            payload["voyageNumber"] = voyageNumber!
        }
        try self.triggerEvent(HandlingEventRegistered.self, for: self, payload: payload)
    }
    
    struct HandlingEventRegistered: CargoEvent {
        let data: DomainEventData
        let voyageNumber: String?
        let location: Location
        let handlingActivity: HandlingActivity
        
        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
            voyageNumber = jsonDict["voyageNumber"] as? String
            location = jsonDict["location"] as! Location
            handlingActivity = jsonDict["handlingActivity"] as! HandlingActivity
        }
        
        func apply(obj: Cargo) throws {
            if obj.state.route == nil {
                throw CargoError.NoRouteSet
            }
            if handlingActivity == HandlingActivity.Receive {
                obj.state.transportStatus = "IN_PORT"
                obj.state.lastKnownLocation = location
                obj.state.nextExpectedActivity = NextExpectedActivity(
                    activity: HandlingActivity.Load, location: location, details: obj.state.route!.legs[0].voyageNumber
                )
            } else if handlingActivity == HandlingActivity.Load {
                if voyageNumber == nil {
                    throw CargoError.AssertionError
                }
                obj.state.transportStatus = "ONBOARD_CARRIER"
                obj.state.currentVoyageNumber = voyageNumber!
                var legFound = false
                for leg in obj.state.route!.legs {
                    if leg.origin == location && leg.voyageNumber == voyageNumber! {
                        obj.state.nextExpectedActivity = NextExpectedActivity(
                            activity: HandlingActivity.Unload, location: leg.destination, details: voyageNumber!
                        )
                        legFound = true
                        break
                    }
                }
                if !legFound {
                    throw CargoError.LegNotFound(origin: location, voyageNumber: voyageNumber!)
                }
            } else if handlingActivity == HandlingActivity.Unload {
                obj.state.currentVoyageNumber = nil
                obj.state.lastKnownLocation = location
                obj.state.transportStatus = "IN_PORT"
                if location == obj.destination {
                    obj.state.nextExpectedActivity = NextExpectedActivity(activity: HandlingActivity.Claim, location: location)
                } else if obj.state.route!.indexForDestination(location: location) != nil {
                    var index = 0
                    for leg in obj.state.route!.legs {
                        if leg.voyageNumber == voyageNumber! {
                            let nextLeg = obj.state.route!.legs[index + 1]
                            if !(nextLeg.origin == location) {
                                throw CargoError.AssertionError
                            }
                            obj.state.nextExpectedActivity = NextExpectedActivity(
                                activity: HandlingActivity.Load, location: location, details: nextLeg.voyageNumber
                            )
                            break
                        }
                        index += 1
                    }
                } else {
                    obj.state.isMisdirected = true
                    obj.state.nextExpectedActivity = nil
                }
            } else if handlingActivity == HandlingActivity.Claim {
                obj.state.nextExpectedActivity = nil
                obj.state.transportStatus = "CLAIMED"
            } else {
                throw CargoError.UnknownHandlingEvent
            }
        }
    }
}
