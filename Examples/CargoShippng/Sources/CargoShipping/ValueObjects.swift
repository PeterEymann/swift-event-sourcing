//
//  ValueObjects.swift
//  
//
//  Created by Peter Eymann on 13/02/22.
//

import Foundation

public enum Location: String, Codable {
    case Hamburg
    case Hongkong
    case NewYork
    case Stockholm
    case Tokyo
    
    case NLRTM
    case USDAL
    case AUMEL
}

public struct Leg: Codable {
    let origin: Location
    let destination: Location
    let voyageNumber: String
}

public struct Itinerary: Codable {
    let origin: Location
    let destination: Location
    let legs: [Leg]
    
    func indexForDestination(location: Location) -> Int? {
        var index = 0
        for leg in legs {
            if leg.destination == location {
                return index
            }
            index += 1
        }
        return nil
    }
}

public enum HandlingActivity: String, Codable {
    case Receive
    case Load
    case Unload
    case Claim
}

public struct NextExpectedActivity: Codable {
    let activity: HandlingActivity
    let location: Location
    var details: String? = nil
}


public let RegisteredRoutes: [[Location]:[Itinerary]] = [
    [Location.Hongkong, Location.Stockholm]: [Itinerary(
        origin: Location.Hongkong,
        destination: Location.Stockholm,
        legs: [
            Leg(origin: Location.Hongkong, destination: Location.NewYork, voyageNumber: "V1"),
            Leg(origin: Location.NewYork, destination: Location.Stockholm, voyageNumber: "V2")
        ]
    )],
    [Location.Tokyo, Location.Stockholm]: [Itinerary(
        origin: Location.Tokyo,
        destination: Location.Stockholm,
        legs: [
            Leg(origin: Location.Tokyo, destination: Location.Hamburg, voyageNumber: "V3"),
            Leg(origin: Location.Hamburg, destination: Location.Stockholm, voyageNumber: "V4")
        ]
    )]
]
