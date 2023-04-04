//
//  Publisher.swift
//  Cleaner
//
//  Created by Brook_Mobius on 2022/11/10.
//

import Foundation
import Combine

extension EffectPublisher {
  /// An effect that does nothing and completes immediately. Useful for situations where you must
  /// return an effect, but you don't need to do anything.
  @inlinable
  public static var none: Self {
    Self(operation: .none)
  }
  
  /// Initializes an effect that wraps a publisher.
  ///
  /// > Important: This Combine interface has been soft-deprecated in favor of Swift concurrency.
  /// > Prefer performing asynchronous work directly in
  /// > ``EffectPublisher/run(priority:operation:catch:file:fileID:line:)`` by adopting a
  /// > non-Combine interface, or by iterating over the publisher's asynchronous sequence of
  /// > `values`:
  /// >
  /// > ```swift
  /// > return .run { send in
  /// >   for await value in publisher.values {
  /// >     send(.response(value))
  /// >   }
  /// > }
  /// > ```
  ///
  /// - Parameter publisher: A publisher.
  public init<P: Publisher>(_ publisher: P) where P.Output == Action, P.Failure == Failure {
    self.operation = .publisher(publisher.eraseToAnyPublisher())
  }
  
  /// Initializes an effect that immediately emits the value passed in.
  ///
  /// - Parameter value: The value that is immediately emitted by the effect.
  public init(value: Action) {
    self.init(Just(value).setFailureType(to: Failure.self))
  }
  
  /// Initializes an effect that immediately fails with the error passed in.
  ///
  /// - Parameter error: The error that is immediately emitted by the effect.
  public init(error: Failure) {
    // NB: Ideally we'd return a `Fail` publisher here, but due to a bug in iOS 13 that publisher
    //     can crash when used with certain combinations of operators such as `.retry.catch`. The
    //     bug was fixed in iOS 14, but to remain compatible with iOS 13 and higher we need to do
    //     a little trickery to fail in a slightly different way.
    self.init(
      Deferred {
        Future { $0(.failure(error)) }
      }
    )
  }
  
  /// Creates an effect that can supply a single value asynchronously in the future.
  ///
  /// This can be helpful for converting APIs that are callback-based into ones that deal with
  /// ``EffectPublisher``s.
  ///
  /// For example, to create an effect that delivers an integer after waiting a second:
  ///
  /// ```swift
  /// EffectPublisher<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///   }
  /// }
  /// ```
  ///
  /// Note that you can only deliver a single value to the `callback`. If you send more they will be
  /// discarded:
  ///
  /// ```swift
  /// EffectPublisher<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///     callback(.success(1729)) // Will not be emitted by the effect
  ///   }
  /// }
  /// ```
  ///
  ///  If you need to deliver more than one value to the effect, you should use the
  ///  ``EffectPublisher`` initializer that accepts a ``Subscriber`` value.
  ///
  /// - Parameter attemptToFulfill: A closure that takes a `callback` as an argument which can be
  ///   used to feed it `Result<Output, Failure>` values.
  public static func future(
    _ attemptToFulfill: @escaping (@escaping (Result<Action, Failure>) -> Void) -> Void
  ) -> Self {
    return Deferred {
      Future(attemptToFulfill)
    }.eraseToEffect()
  }
  
  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// EffectPublisher<User, Error>.result {
  ///   let fileUrl = URL(
  ///     fileURLWithPath: NSSearchPathForDirectoriesInDomains(
  ///       .documentDirectory, .userDomainMask, true
  ///     )[0]
  ///   )
  ///   .appendingPathComponent("user.json")
  ///
  ///   let result = Result<User, Error> {
  ///     let data = try Data(contentsOf: fileUrl)
  ///     return try JSONDecoder().decode(User.self, from: $0)
  ///   }
  ///
  ///   return result
  /// }
  /// ```
  ///
  /// - Parameter attemptToFulfill: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public static func result(_ attemptToFulfill: @escaping () -> Result<Action, Failure>) -> Self {
    .future { $0(attemptToFulfill()) }
  }
}

extension Publisher {
  /// Creates an effect that can supply a single value asynchronously in the future.
  ///
  /// This can be helpful for converting APIs that are callback-based into ones that deal with
  /// ``EffectPublisher``s.
  ///
  /// For example, to create an effect that delivers an integer after waiting a second:
  ///
  /// ```swift
  /// EffectPublisher<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///   }
  /// }
  /// ```
  ///
  /// Note that you can only deliver a single value to the `callback`. If you send more they will be
  /// discarded:
  ///
  /// ```swift
  /// EffectPublisher<Int, Never>.future { callback in
  ///   DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
  ///     callback(.success(42))
  ///     callback(.success(1729)) // Will not be emitted by the effect
  ///   }
  /// }
  /// ```
  ///
  ///  If you need to deliver more than one value to the effect, you should use the
  ///  ``EffectPublisher`` initializer that accepts a ``Subscriber`` value.
  ///
  /// - Parameter attemptToFulfill: A closure that takes a `callback` as an argument which can be
  ///   used to feed it `Result<Output, Failure>` values.
  public func eraseToEffect() -> EffectPublisher<Output, Failure> {
    EffectPublisher(self)
  }
  
  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// EffectPublisher<User, Error>.result {
  ///   let fileUrl = URL(
  ///     fileURLWithPath: NSSearchPathForDirectoriesInDomains(
  ///       .documentDirectory, .userDomainMask, true
  ///     )[0]
  ///   )
  ///   .appendingPathComponent("user.json")
  ///
  ///   let result = Result<User, Error> {
  ///     let data = try Data(contentsOf: fileUrl)
  ///     return try JSONDecoder().decode(User.self, from: $0)
  ///   }
  ///
  ///   return result
  /// }
  /// ```
  ///
  /// - Parameter attemptToFulfill: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public func eraseToEffect<T>(
    _ transform: @escaping (Output) -> T
  ) -> EffectPublisher<T, Failure> {
    self.map(transform)
      .eraseToEffect()
  }
  
  /// Turns any publisher into an ``EffectTask`` that cannot fail by wrapping its output and failure
  /// in a result.
  ///
  /// This can be useful when you are working with a failing API but want to deliver its data to an
  /// action that handles both success and failure.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return self.apiClient.fetchUser(id: 1)
  ///     .catchToEffect()
  ///     .map(ProfileAction.userResponse)
  /// ```
  ///
  /// - Returns: An effect that wraps `self`.
  public func catchToEffect() -> EffectTask<Result<Output, Failure>> {
    self.catchToEffect { $0 }
  }
  
  /// Turns any publisher into an ``EffectTask`` that cannot fail by wrapping its output and failure
  /// into a result and then applying passed in function to it.
  ///
  /// This is a convenience operator for writing ``EffectPublisher/eraseToEffect()`` followed by
  /// ``EffectPublisher/map(_:)-28ghh`.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return self.apiClient.fetchUser(id: 1)
  ///     .catchToEffect(ProfileAction.userResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - transform: A mapping function that converts `Result<Output,Failure>` to another type.
  /// - Returns: An effect that wraps `self`.
  public func catchToEffect<T>(
    _ transform: @escaping (Result<Output, Failure>) -> T
  ) -> EffectTask<T> {
    return
      self
      .map { transform(.success($0)) }
      .catch { Just(transform(.failure($0))) }
      .eraseToEffect()
  }
  
  /// Turns any publisher into an ``EffectPublisher`` for any output and failure type by ignoring
  /// all output and any failure.
  ///
  /// This is useful for times you want to fire off an effect but don't want to feed any data back
  /// into the system. It can automatically promote an effect to your reducer's domain.
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return analyticsClient.track("Button Tapped")
  ///     .fireAndForget()
  /// ```
  ///
  /// - Parameters:
  ///   - outputType: An output type.
  ///   - failureType: A failure type.
  /// - Returns: An effect that never produces output or errors.
  public func fireAndForget<NewOutput, NewFailure>(
    outputType: NewOutput.Type = NewOutput.self,
    failureType: NewFailure.Type = NewFailure.self
  ) -> EffectPublisher<NewOutput, NewFailure> {
    return
      self
      .flatMap { _ in Empty<NewOutput, Failure>() }
      .catch { _ in Empty() }
      .eraseToEffect()
  }
}

extension EffectPublisher where Failure == Error {
  /// Initializes an effect that lazily executes some work in the real world and synchronously sends
  /// that data back into the store.
  ///
  /// For example, to load a user from some JSON on the disk, one can wrap that work in an effect:
  ///
  /// ```swift
  /// EffectPublisher<User, Error>.catching {
  ///   let fileUrl = URL(
  ///     fileURLWithPath: NSSearchPathForDirectoriesInDomains(
  ///       .documentDirectory, .userDomainMask, true
  ///     )[0]
  ///   )
  ///   .appendingPathComponent("user.json")
  ///
  ///   let data = try Data(contentsOf: fileUrl)
  ///   return try JSONDecoder().decode(User.self, from: $0)
  /// }
  /// ```
  ///
  /// - Parameter work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public static func catching(_ work: @escaping () throws -> Action) -> Self {
    .future { $0(Result { try work() }) }
  }
}
