//
//  Infrastructure.swift
//  
//
//  Created by Peter Eymann on 04/02/22.
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

public protocol CreatesInfrastructure {
    var isSnapshottingEnabled: Bool { get }
    
    func buildAggregateRecorder() -> AggregateRecorder
    func buildApplicationRecorder() -> ApplicationRecorder
    func buildProcessRecorder() -> ApplicationRecorder
    func buildMapper(applicationName: String?) -> MapsDomainEvents
}

extension CreatesInfrastructure {
    func buildMapper(applicationName: String?="") -> MapsDomainEvents {
        return Mapper()
    }
}

private struct InfraStructureFactoryKey: InjectionKey {
    static var currentValue: CreatesInfrastructure = InMemoryInfrastructureFactory()
}

extension InjectedValues {
    var infrastructureFactory: CreatesInfrastructure {
        get { Self[InfraStructureFactoryKey.self] }
        set { Self[InfraStructureFactoryKey.self] = newValue }
    }
}

class InMemoryInfrastructureFactory: CreatesInfrastructure {
    var isSnapshottingEnabled: Bool = true
    
    func buildAggregateRecorder() -> AggregateRecorder {
        return InMemoryAggregateRecorder()
    }
    
    func buildApplicationRecorder() -> ApplicationRecorder {
        return InMemoryApplicationRecorder()
    }
    
    func buildProcessRecorder() -> ApplicationRecorder {
        return InMemoryProcessRecorder()
    }
}
