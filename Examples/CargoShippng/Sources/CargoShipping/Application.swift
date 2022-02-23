//
//  File.swift
//  
//
//  Created by Peter Eymann on 22/02/22.
//

import Foundation
import EventSourcing

public protocol BookingApplicationProtocol {
    func bookNewCargo(origin: Location, destination: Location, arrivalDeadLine: Date) -> UUID
    func getCargo(_ trackingId: UUID) throws -> Cargo
    func changeDestination(_ trackingId: UUID, to: Location) throws
    func requestPossibleRoutes(for trackingId: UUID) throws -> [Itinerary]
    func assignRoute(to trackingId: UUID, itinerary: Itinerary) throws
    func registerHandlingEvent(trackingId: UUID, voyageNumber: String?, location: Location, handlingActivity: HandlingActivity) throws
}


public enum BookingErrors: Error {
    case NoRoutesFound(from: Location, to: Location)
}


public final class BookingApplication: Application, BookingApplicationProtocol {
    public required init() {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "Cargo", aggregateClass: Cargo.self)
        InjectedValues[\.aggregateRegistry] = registry
    }
    
    public func bookNewCargo(origin: Location, destination: Location, arrivalDeadLine: Date) -> UUID {
        let cargo = Cargo.newBooking(origin: origin, destination: destination, arrivalDeadline: arrivalDeadLine)
        try! self.save(cargo)
        return cargo.id
    }
    
    public func getCargo(_ trackingId: UUID) throws -> Cargo {
        let cargo: Cargo = try repository.get(aggregateId: trackingId)
        return cargo
    }
    
    public func changeDestination(_ trackingId: UUID, to destination: Location) throws {
        let cargo: Cargo = try repository.get(aggregateId: trackingId)
        cargo.changeDestination(to: destination)
        try! self.save(cargo)
    }
    
    public func requestPossibleRoutes(for trackingId: UUID) throws -> [Itinerary] {
        let cargo: Cargo = try repository.get(aggregateId: trackingId)
        let fromLocation = cargo.lastKnownLocation ?? cargo.origin
        if let choices = RegisteredRoutes[[fromLocation, cargo.destination]] {
            return choices
        } else {
            throw BookingErrors.NoRoutesFound(from: cargo.origin, to: cargo.destination)
        }
    }
    
    public func assignRoute(to trackingId: UUID, itinerary: Itinerary) throws {
        let cargo: Cargo = try repository.get(aggregateId: trackingId)
        cargo.assignRoute(itinerary: itinerary)
        try self.save(cargo)
    }
    
    public func registerHandlingEvent(trackingId: UUID, voyageNumber: String?, location: Location, handlingActivity: HandlingActivity) throws {
        let cargo: Cargo = try repository.get(aggregateId: trackingId)
        try cargo.registerHandlingEvent(
            voyageNumber: voyageNumber, location: location, handlingActivity: handlingActivity
        )
        try self.save(cargo)
    }
}
