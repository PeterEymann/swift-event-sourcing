//
//  ProcessRecorder.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
//

import Foundation

public struct Tracking {
    /// Tracks the current position of notifications for an application
    let applicationName: String
    let notificationId: Int
}

public protocol ProcessRecorder: ApplicationRecorder {
    func maxTrackingId(applicationName: String) -> Int
    func insertEvents(_ events: [StoredEvent], tracking: Tracking?) throws
}
