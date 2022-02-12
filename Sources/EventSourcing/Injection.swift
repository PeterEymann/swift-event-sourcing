//
//  Injection.swift
//  
//
//  Created by Peter Eymann on 01/02/22.
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

/// Dependency injection framework inspired by Antoine van der Lee
/// https://www.avanderlee.com/swift/dependency-injection/
public protocol InjectionKey {
    /// The associated type representing the type of the dependency injection key's value.
    associatedtype Value
    
    /// The default value for the dependency injection key
    static var currentValue: Self.Value { get set }
}


public struct InjectedValues {
    /// Provides access to injected dependencies.
    /// This is only used as an accessor to the computed properties within extensions of `InjectedValues`
    public static var current = InjectedValues()
    
    /// A static subscript for updating the 'currentValue' of 'InjectionKey' instances
    public static subscript<K: InjectionKey>(key: K.Type) -> K.Value {
        get { key.currentValue }
        set { key.currentValue = newValue }
    }
    
    // A static subscript accessor for updating and reference dependencies directly
    public static subscript<T>(_ keyPath: WritableKeyPath<InjectedValues, T>) -> T {
        get { current[keyPath: keyPath] }
        set { current[keyPath: keyPath] = newValue }
    }
}


@propertyWrapper
struct Injected<T> {
    private let keyPath: WritableKeyPath<InjectedValues, T>
    var wrappedValue: T {
        get { InjectedValues[keyPath] }
        set { InjectedValues[keyPath] = newValue }
    }
    
    init(_ keyPath: WritableKeyPath<InjectedValues, T>) {
        self.keyPath = keyPath
    }
}
