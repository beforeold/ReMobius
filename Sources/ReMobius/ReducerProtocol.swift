//
//  ReducerProtocol.swift
//  Cleaner
//
//  Created by Brook_Mobius on 2022/11/10.
//

import Foundation
import Combine

public protocol ReducerProtocol<State, Action> {
  /// A type that holds the current state of the reducer.
  associatedtype State
  
  /// A type that holds all possible actions that cause the ``State`` of the reducer to change
  /// and/or kick off a side ``EffectTask`` that can communicate with the outside world.
  associatedtype Action
  
  /// Evolves the current state of the reducer to the next state.
  ///
  /// Implement this requirement for "primitive" reducers, or reducers that work on leaf node
  /// features. To define a reducer by combining the logic of other reducers together, implement
  /// the ``body-swift.property-97ymy`` requirement instead.
  ///
  /// - Parameters:
  ///   - state: The current state of the reducer.
  ///   - action: An action that can cause the state of the reducer to change, and/or kick off a
  ///     side effect that can communicate with the outside world.
  /// - Returns: An effect that can communicate with the outside world and feed actions back into
  ///   the system.
  func reduce(into state: inout State, action: Action) -> EffectTask<Action>
}
