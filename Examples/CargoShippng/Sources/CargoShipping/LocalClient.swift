//
//  File.swift
//  
//
//  Created by Peter Eymann on 22/02/22.
//

import Foundation
import EventSourcing
import AppKit

public struct ExpectedActivity: Codable {
    public let activity: String
    public let location: String
    public let details: String
}

public struct CargoDetails: Codable {
    public let id: String
    public let origin: String
    public let destination: String
    public let arrivalDeadline: String
    public let transportStatus: String
    public let routingStatus: String
    public let isMisdirected: Bool
    public let estimatedTimeOfArrival: String?
    public let nextExpectedActivity: ExpectedActivity?
    public let lastKnownLocation: String?
    public let currentVoyageNumber: String?
}

public struct Route: Codable {
    public let origin: String
    public let destination: String
    public let legs: [RouteLeg]
}

public struct RouteLeg: Codable {
    public let origin: String
    public let destination: String
    public let voyageNumber: String
}

@available(macOS 10.12, *)
public final class LocalClient {
    let timeZone: TimeZone = TimeZone(abbreviation: "GMT")!
    
    internal func toISO8601DateString(_ date: Date) -> String {
        let options: ISO8601DateFormatter.Options = [.withFullDate]
        return ISO8601DateFormatter.string(from: date, timeZone: timeZone, formatOptions: options)
    }
    
    internal func fromISO8601DateString(_ str: String) -> Date {
        let options: ISO8601DateFormatter.Options = [.withFullDate]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter.date(from: str)!
    }
    
    let app: BookingApplicationProtocol
    
    public init(_ app: BookingApplicationProtocol) {
        self.app = app
    }
    
    public func bookNewCargo(origin: String, destination: String, arrivalDeadLine: String) -> String {
        let trackingId = app.bookNewCargo(
            origin: Location(rawValue: origin)!, destination: Location(rawValue: destination)!, arrivalDeadLine: fromISO8601DateString(arrivalDeadLine)
        )
        return trackingId.uuidString
    }
    
    public func getCargoDetails(_ trackingId: String) -> CargoDetails {
        let cargo = try! app.getCargo(UUID(uuidString: trackingId)!)
        
        return CargoDetails(
            id: cargo.id.uuidString,
            origin: cargo.origin.rawValue,
            destination: cargo.destination.rawValue,
            arrivalDeadline: toISO8601DateString(cargo.arrivalDeadline),
            transportStatus: cargo.transportStatus,
            routingStatus: cargo.routingStatus,
            isMisdirected: cargo.isMisdirected,
            estimatedTimeOfArrival: { () -> String? in
                if let t = cargo.estimatedTimeOfArrival {
                    return toISO8601DateString(t)
                } else {
                    return nil
                }
            }(),
            nextExpectedActivity: {
                if let a = cargo.nextExpectedActivity {
                    return ExpectedActivity(activity: a.activity.rawValue, location: a.location.rawValue, details: {
                        if let v = a.details {
                            return v
                        } else {
                            return ""
                        }
                    }())
                } else {
                    return nil
                }
            }(),
            lastKnownLocation: {
                if let l = cargo.lastKnownLocation {
                    return l.rawValue
                } else {
                    return nil
                }
            }(),
            currentVoyageNumber: cargo.currentVoyageNumber
        )
    }
    
    public func changeDestination(_ trackingId: String, to destination: String) {
        try! app.changeDestination(UUID(uuidString: trackingId)!, to: Location(rawValue: destination)!)
    }
    
    public func requestPossibleRoutesForCargo(_ trackingId: String) throws -> [Route] {
        let itineraries = try app.requestPossibleRoutes(for: UUID(uuidString: trackingId)!)
        var routes: [Route] = []
        for itinerary in itineraries {
            var legs: [RouteLeg] = []
            for leg in itinerary.legs {
                legs.append(RouteLeg(origin: leg.origin.rawValue, destination: leg.destination.rawValue, voyageNumber: leg.voyageNumber))
            }
            routes.append(Route(origin: itinerary.origin.rawValue, destination: itinerary.destination.rawValue, legs: legs))
        }
        return routes
    }
    
    public func assignRoute(_ trackingId: String, route: Route) {
        var legs: [Leg] = []
        for leg in route.legs {
            legs.append(Leg(
                origin: Location(rawValue: leg.origin)!,
                destination: Location(rawValue: leg.destination)!,
                voyageNumber: leg.voyageNumber
            ))
        }
        let itinerary = Itinerary(origin: Location(rawValue: route.origin)!, destination: Location(rawValue: route.destination)!, legs: legs)
        try! app.assignRoute(to: UUID(uuidString: trackingId)!, itinerary: itinerary)
    }
    
    public func registerHandlingEvent(trackingId: String, voyageNumber: String?, location: String, handlingActivity: String) throws {
        try app.registerHandlingEvent(
            trackingId: UUID(uuidString: trackingId)!,
            voyageNumber: voyageNumber,
            location: Location(rawValue: location)!,
            handlingActivity: HandlingActivity(rawValue: handlingActivity)!
        )
    }
}
