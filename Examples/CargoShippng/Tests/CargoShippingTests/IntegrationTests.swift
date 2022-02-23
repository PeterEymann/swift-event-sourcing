//
//  IntegrationTests.swift
//  
//
//  Created by Peter Eymann on 22/02/22.
//

import XCTest
import CargoShipping

extension Data {
    var prettyPrintedJSONString: NSString? { /// NSString gives us a nice sanitized debugDescription
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }

        return prettyPrintedString
    }
}

extension Date {
    var ISO8601DateString: String {
        let timeZone = TimeZone(abbreviation: "GMT")!
        let options: ISO8601DateFormatter.Options = [.withFullDate]
        return ISO8601DateFormatter.string(from: self, timeZone: timeZone, formatOptions: options)
    }
}

@available(macOS 12.0, *)
class IntegrationTests: XCTestCase {
    var client: LocalClient? = nil
    
    override func setUpWithError() throws {
        client = LocalClient(BookingApplication())
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAdminCanBookNewCargo() throws {
        let deadline = Date(timeIntervalSinceNow: -3*7*24*60*60).ISO8601DateString
        
        let cargoId = client!.bookNewCargo(origin: "NLRTM", destination: "USDAL", arrivalDeadLine: deadline)
        var details = client!.getCargoDetails(cargoId)
        
        debugPrint(try! JSONEncoder().encode(details).prettyPrintedJSONString!)
        XCTAssertEqual(details.origin, "NLRTM")
        XCTAssertEqual(details.destination, "USDAL")
        client!.changeDestination(cargoId, to: "AUMEL")
        details = client!.getCargoDetails(cargoId)
        XCTAssertEqual(details.destination, "AUMEL")
        XCTAssertEqual(details.arrivalDeadline, deadline)
    }
    
    func testScenarioCargoFromHonkongToStockholm() throws {
        /// Test setup: A cargo should be shipped from Honkong to Stockholm, and it should arrive in no more than two weeks.
        let origin = "Hongkong"
        let destination = "Stockholm"
        let deadline = Date(timeIntervalSinceNow: -2*7*24*60*60).ISO8601DateString
        
        /// use case 1: booking.
        /// A new cargo is booked and the unique tracking id is assigned to the cargo.
        let trackingId = client!.bookNewCargo(origin: origin, destination: destination, arrivalDeadLine: deadline)
        
        /// The tracking id can be used to look up the cargo in the repository.
        /// **Important**: The cargo, and thus the domain model, ois responsible for determining the status of the
        /// cargo, wether it is on the right track or not and so on. This is core domain logic. Tracking the cargo
        /// basically amounts to presenting information extracted from the cargo aggregate in a suitable way.
        var cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertEqual(cargoDetails.transportStatus, "NOT_RECEIVED")
        XCTAssertEqual(cargoDetails.routingStatus, "NOT_ROUTED")
        XCTAssertFalse(cargoDetails.isMisdirected)
        XCTAssertNil(cargoDetails.estimatedTimeOfArrival)
        XCTAssertNil(cargoDetails.nextExpectedActivity)
        
        /// Use case 2: routing.
        ///
        /// A  number of possible routes for this cargo is requested and may be presented to the customer
        /// in some way for him to choose from.
        /// Selection could be affected by things like price and time of delivery, but this test simply uses an arbitrary selection
        /// to mimic that process
        var routesDetails = try client!.requestPossibleRoutesForCargo(trackingId)
        var routeDetail = routesDetails[0]
        
        /// The cargo is then assigned to the selected route, descibed by an itinerary
        client!.assignRoute(trackingId, route: routeDetail)
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertEqual(cargoDetails.transportStatus, "NOT_RECEIVED")
        XCTAssertEqual(cargoDetails.routingStatus, "ROUTED")
        XCTAssertFalse(cargoDetails.isMisdirected)
        XCTAssertNotNil(cargoDetails.estimatedTimeOfArrival)
        XCTAssertNotNil(cargoDetails.nextExpectedActivity)
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.activity, "Receive")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.location, "Hongkong")
        
        /// Use case 3: handling
        ///
        /// A handling event registration attempt will be formed from parsing the data coming in as a
        /// handling report either via the web service interface or as an uploaded CSV file. The handling event
        /// factory tries to create a HandlingEvent from the attempt and if the factory decides that this is a
        /// plausible handling event, it is stored. If the attempt is invalid, for example if no cargo exists for the
        /// specified tracking id, the attempt is rejected
        
        // Handling begins: cargo is received in Hongkong
        try client!.registerHandlingEvent(trackingId: trackingId, voyageNumber: nil, location: "Hongkong", handlingActivity: "Receive")
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertEqual(cargoDetails.transportStatus, "IN_PORT")
        XCTAssertEqual(cargoDetails.lastKnownLocation, "Hongkong")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.activity, "Load")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.location, "Hongkong")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.details, "V1")
        
        // load onto voyage V1
        try client!.registerHandlingEvent(trackingId: trackingId, voyageNumber: "V1", location: "Hongkong", handlingActivity: "Load")
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertEqual(cargoDetails.currentVoyageNumber!, "V1")
        XCTAssertEqual(cargoDetails.lastKnownLocation, "Hongkong")
        XCTAssertEqual(cargoDetails.transportStatus, "ONBOARD_CARRIER")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.activity, "Unload")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.location, "NewYork")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.details, "V1")
        
        // incorrectly unload in Tokyo
        try client!.registerHandlingEvent(trackingId: trackingId, voyageNumber: "V1", location: "Tokyo", handlingActivity: "Unload")
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertNil(cargoDetails.currentVoyageNumber)
        XCTAssertEqual(cargoDetails.lastKnownLocation, "Tokyo")
        XCTAssertEqual(cargoDetails.transportStatus, "IN_PORT")
        XCTAssertTrue(cargoDetails.isMisdirected)
        XCTAssertNil(cargoDetails.nextExpectedActivity)
        
        // Reroute.
        routesDetails = try client!.requestPossibleRoutesForCargo(trackingId)
        routeDetail = routesDetails[0]
        client!.assignRoute(trackingId, route: routeDetail)
        
        // Load in Tokyo.
        try client!.registerHandlingEvent(trackingId: trackingId, voyageNumber: "V3", location: "Tokyo", handlingActivity: "Load")
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertEqual(cargoDetails.lastKnownLocation, "Tokyo")
        XCTAssertEqual(cargoDetails.currentVoyageNumber, "V3")
        XCTAssertEqual(cargoDetails.transportStatus, "ONBOARD_CARRIER")
        XCTAssertFalse(cargoDetails.isMisdirected)
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.activity, "Unload")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.location, "Hamburg")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.details, "V3")
        
        // Unload in Hamburg
        try client!.registerHandlingEvent(trackingId: trackingId, voyageNumber: "V3", location: "Hamburg", handlingActivity: "Unload")
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertNil(cargoDetails.currentVoyageNumber)
        XCTAssertEqual(cargoDetails.lastKnownLocation, "Hamburg")
        XCTAssertEqual(cargoDetails.transportStatus, "IN_PORT")
        XCTAssertFalse(cargoDetails.isMisdirected)
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.activity, "Load")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.location, "Hamburg")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.details, "V4")
        
        // Load in Hamburg
        try client!.registerHandlingEvent(trackingId: trackingId, voyageNumber: "V4", location: "Hamburg", handlingActivity: "Load")
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertEqual(cargoDetails.lastKnownLocation, "Hamburg")
        XCTAssertEqual(cargoDetails.currentVoyageNumber, "V4")
        XCTAssertEqual(cargoDetails.transportStatus, "ONBOARD_CARRIER")
        XCTAssertFalse(cargoDetails.isMisdirected)
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.activity, "Unload")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.location, "Stockholm")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.details, "V4")
        
        // Unload in Stockholm
        try client!.registerHandlingEvent(trackingId: trackingId, voyageNumber: "V4", location: "Stockholm", handlingActivity: "Unload")
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertNil(cargoDetails.currentVoyageNumber)
        XCTAssertEqual(cargoDetails.lastKnownLocation, "Stockholm")
        XCTAssertEqual(cargoDetails.transportStatus, "IN_PORT")
        XCTAssertFalse(cargoDetails.isMisdirected)
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.activity, "Claim")
        XCTAssertEqual(cargoDetails.nextExpectedActivity!.location, "Stockholm")
        
        // Finally, cargo is claimed in Stockholm
        try client!.registerHandlingEvent(trackingId: trackingId, voyageNumber: nil, location: "Stockholm", handlingActivity: "Claim")
        cargoDetails = client!.getCargoDetails(trackingId)
        XCTAssertEqual(cargoDetails.transportStatus, "CLAIMED")
        XCTAssertFalse(cargoDetails.isMisdirected)
        XCTAssertNil(cargoDetails.nextExpectedActivity)
    }
}
