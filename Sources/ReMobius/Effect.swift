//
//  Effect.swift
//  Cleaner
//
//  Created by Brook_Mobius on 2022/11/10.
//

import Foundation
import Combine

/// A type that encapsulates a unit of work that can be run in the outside world, and can feed
/// actions back to the ``Store``.
///
/// Effects are the perfect place to do side effects, such as network requests, saving/loading
/// from disk, creating timers, interacting with dependencies, and more. They are returned from
/// reducers so that the ``Store`` can perform the effects after the reducer is done running.
///
/// There are 2 distinct ways to create an `Effect`: one using Swift's native concurrency tools, and
/// the other using Apple's Combine framework:
///
/// * If using Swift's native structured concurrency tools then there are 3 main ways to create an
/// effect, depending on if you want to emit one single action back into the system, or any number
/// of actions, or just execute some work without emitting any actions:
///   * ``EffectPublisher/task(priority:operation:catch:file:fileID:line:)``
///   * ``EffectPublisher/run(priority:operation:catch:file:fileID:line:)``
///   * ``EffectPublisher/fireAndForget(priority:_:)``
/// * If using Combine in your application, in particular for the dependencies of your feature
/// then you can create effects by making use of any of Combine's operators, and then erasing the
/// publisher type to ``EffectPublisher`` with either `eraseToEffect` or `catchToEffect`. Note that
/// the Combine interface to ``EffectPublisher`` is considered soft deprecated, and you should
/// eventually port to Swift's native concurrency tools.
///
/// > Important: ``Store`` is not thread safe, and so all effects must receive values on the same
/// thread. This is typically the main thread,  **and** if the store is being used to drive UI then
/// it must receive values on the main thread.
/// >
/// > This is only an issue if using the Combine interface of ``EffectPublisher`` as mentioned
/// above. If  you are using Swift's concurrency tools and the `.task`, `.run` and `.fireAndForget`
/// functions on ``EffectTask``, then threading is automatically handled for you.
public struct EffectPublisher<Action, Failure: Error> {
  @usableFromInline
  enum Operation {
    case none
    case publisher(AnyPublisher<Action, Failure>)
    /*
    case run(TaskPriority? = nil, @Sendable (Send<Action>) async -> Void)
    */
  }

  @usableFromInline
  let operation: Operation

  @usableFromInline
  init(operation: Operation) {
    self.operation = operation
  }
}

public typealias Effect = EffectPublisher
public typealias EffectTask<Action> = Effect<Action, Never>
