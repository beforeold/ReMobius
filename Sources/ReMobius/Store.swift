//
//  Store.swift
//  Cleaner
//
//  Created by Brook_Mobius on 2022/11/10.
//

import Foundation
import Combine

@dynamicMemberLookup
public final class Store<State, Action>: ObservableObject {
  
  @Published public private(set) var state: State
  
  public var effectCancellables: [UUID: AnyCancellable] = [:]
  
  // the Swift runtime was unable to demangle the type of field 'reducer
  // private let reducer: any ReducerProtocol<State, Action>
  // brook: use function instead of instance for back deploy issue
  private let reducer: (inout State, Action) -> EffectTask<Action>
  
  public init<R: ReducerProtocol>(
    initialState: R.State,
    reducer: R
  ) where R.State == State, R.Action == Action {
    self.state = initialState
    self.reducer = reducer.reduce
  }
  
  public func send(_ action: Action) {
    let effect = self.reducer(&state, action)
    
    // handle effect, sink the publisher
    guard case .publisher(let publisher) = effect.operation else {
      return
    }
    
    var didComplete = false
    let uuid = UUID()
    let effectCancellable = publisher
      .handleEvents(receiveCancel: { [weak self] in
        self?.effectCancellables[uuid] = nil
      })
      .sink { [weak self] _ in
        didComplete = true
        self?.effectCancellables[uuid] = nil
      } receiveValue: { [weak self] effectAction in
        self?.send(effectAction)
      }
    
    if !didComplete {
      self.effectCancellables[uuid] = effectCancellable
    }
  }
  
  /// Returns the resulting value of a given key path.
  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

extension Store {
  /// the publisher of the state
  public var statePublisher: AnyPublisher<State, Never> {
    return self.$state.eraseToAnyPublisher()
  }
}

/// A convenience type alias for referring to a store of a given reducer's domain.
///
/// Instead of specifying two generics:
///
/// ```swift
/// let store: Store<Feature.State, Feature.Action>
/// ```
///
/// You can specify a single generic:
///
/// ```swift
/// let store: StoreOf<Feature>
/// ```
public typealias StoreOf<R: ReducerProtocol> = Store<R.State, R.Action>
