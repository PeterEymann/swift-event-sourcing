//
//  ApplicationRecorder.swift
//  
//
//  Created by Peter Eymann on 02/02/22.
//
//  Copyright 2022 Peter Eymann
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation


public protocol ApplicationRecorder: AggregateRecorder {
    /// Returns a list of event notifications from `start`, limited by `limit`
    func selectNotifications(start: Int, limit: Int) -> [Notification]
    /// Returns the maximum notification `id`
    func maxNotificationId() -> Int
}
