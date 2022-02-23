import XCTest
import EventSourcing
import CargoShipping

final class CargoShippingTests: XCTestCase {
    func testAggregate() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "Cargo", aggregateClass: Cargo.self)
        InjectedValues[\.aggregateRegistry] = registry
        let cargo = Cargo.newBooking(origin: Location.Hamburg, destination: Location.Hongkong, arrivalDeadline: Date())
        XCTAssertEqual(cargo.destination, Location.Hongkong)
        cargo.changeDestination(to: Location.USDAL)
        XCTAssertEqual(cargo.destination, Location.USDAL)
    }
    
    func testApplication() throws {
        let app = BookingApplication()
        let cargoId = app.bookNewCargo(origin: Location.Hamburg, destination: Location.Hongkong, arrivalDeadLine: Date())
        XCTAssertEqual(try app.getCargo(cargoId).destination, Location.Hongkong)
        try app.changeDestination(cargoId, to: Location.NewYork)
        XCTAssertEqual(try app.getCargo(cargoId).destination, Location.NewYork)
    }
}
