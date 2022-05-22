//
//  Timer.swift
//  Just A Simple Menu Bar Timer
//
//  Created by Ky Leggiero on 4/20/22.
//

import Combine
import Foundation
import AppKit



public final actor Timer: ObservableObject, Identifiable {
    
    public let id: UUID
    
    @Published
    @MainActor
    private var state: State = .notStarted
    
    private let kind: Kind
    
    private var wallTimeWatcher = Any?.none
    
    @MainActor
    public private(set) var stateChangePublisher: StateChangePublisher = Just(.notStarted(startingValue: .nan))
        .eraseToAnyPublisher()
    
    
    /// Creates a new `Timer`
    ///
    /// To start this timer immediately, use `Timer(kind: someKind).start()`
    ///
    /// - Parameters:
    ///   - kind: What kind of timer is this? More info in the documentation for ``Kind``
    ///   - id:   _optional_ - A universally-unique identifier for this timer. Defaults to a new UUID
    init(kind: Kind, id: UUID = UUID()) async {
        self.kind = kind
        self.id = id
        
        self.stateChangePublisher = self.$state
            .map { [self] _ in
                await self.currentValue
            }
            .share()
            .makeConnectable()
            .autoconnect()
            .eraseToAnyPublisher()
    }
}



public struct AsyncMapPublisher<Upstream: Publisher, Output>: Publisher {
    
    /// The kind of errors this publisher might publish.
    ///
    /// This publisher uses its upstream publisher's failure type.
    public typealias Failure = Upstream.Failure
    
    /// The publisher from which this publisher receives elements.
    public let upstream: Upstream
    
    /// The closure that transforms elements from the upstream publisher.
    public let transform: Transform
    
    /// Creates a publisher that transforms all elements from the upstream publisher with a provided closure asynchronously.
    /// - Parameters:
    ///   - upstream:  The publisher from which this publisher receives elements.
    ///   - transform: The async closure that transforms elements from the upstream publisher.
    public init(upstream: Upstream, transform: @escaping Transform) {
        self.upstream = upstream
        self.transform = transform
    }
    
    /// Attaches the specified subscriber to this publisher.
    ///
    /// Implementations of ``Publisher`` must implement this method.
    ///
    /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
    ///
    /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
    public func receive<S>(subscriber: S)
    where Output == S.Input,
          S : Subscriber,
          Failure == S.Failure
    {
        upstream.sink { completion in
            subscriber.receive(completion: completion)
        }
        receiveValue: { before in
            Task {
                subscriber.receive(await transform(before))
            }
        }
        .store(in: &asyncMapSinks)
    }
    
    
    
    public typealias Transform = @Sendable (Upstream.Output) async -> Output
}



private var asyncMapSinks = Set<AnyCancellable>()




public extension Publisher {
    
    /// Asynchronously maps the values in this publisher to new values
    /// - Parameter transform: The async function which will be used for mapping the values
    func map<Mapped>(_ transform: @escaping AsyncMapPublisher<Self, Mapped>.Transform)
    -> AsyncMapPublisher<Self, Mapped> {
        AsyncMapPublisher(upstream: self, transform: transform)
    }
}



public extension Timer {
    
    /// Starts or resumes this timer.
    ///
    /// For timers which are currently running, this has no effect. 
    ///
    /// For timers which have already completed, this has no effect. Those must be explicitly `reset()` before they can be started again.
    ///
    /// - Returns: _optional_ - `self`, to chain calls
    @discardableResult
    func start() async -> Timer {
        let now = Date()
        
        // Count-DOWN timer for 5 minutes (300s):
        //
        //    EVENT  |         DATE        | secs since start | secs since pause | secs lost from pausing | secs elapsed | secs remaining
        //   Started | 2022-04-25 10:00:00 |                0 |                0 |                      0 |            0 |            300
        //    Paused | 2022-04-25 10:02:00 |              120 |                0 |                        |          120 |            180
        //           | 2022-04-25 10:03:00 |              180 |               60 |                        |          180 |            180
        //   Resumed | 2022-04-25 10:03:01 |              181 |                  |                     60 |          181 |            179
        //           | 2022-04-25 10:04:01 |              241 |                  |                     60 |          241 |            119
        //    Paused | 2022-04-25 10:05:01 |              301 |                0 |                        |          241 |             59
        //           | 2022-04-25 10:06:01 |              361 |               60 |                        |          241 |             59
        //           | 2022-04-02 10:16:01 |              961 |              660 |                        |          241 |             59
        //   Resumed | 2022-04-02 10:16:02 |              962 |                  |                    720 |          242 |             58
        //           | 2022-04-02 10:16:58 |             1018 |                  |                    720 |          298 |              2
        //           | 2022-04-02 10:16:59 |             1019 |                  |                    720 |          299 |              1
        //           | 2022-04-02 10:17:00 |             1020 |                  |                    720 |          300 |              0
        // Completed | 2022-04-02 10:17:00 |                  |                  |                        |              |
        
        return await MainActor.run { [self] in
            switch self.state {
            case .notStarted:
                self.state = .running(originalStartDate: now, timeLostFromPausing: 0)
                
            case .paused(originalStartDate: let originalStartDate,
                         pauseDate: let pauseDate,
                         totalTimeElapsedAtMomentOfPause: let totalTimeElapsedAtMomentOfPause):
                
                switch self.kind {
                case .countUp(totalTimeToCountUp: _):
                    break
                    
                case .countDown(totalTimeToCountDown: let totalTimeToCountDown):
                    guard totalTimeToCountDown > 0,
                          totalTimeToCountDown.isFitForUseInDateCalculations
                    else {
                        Task {
                            await self.stop()
                        }
                        return self
                    }
                }
                
                let timeSincePause = now.timeIntervalSince(pauseDate)
                let timeSinceStart = now.timeIntervalSince(originalStartDate)
                let secondsRemaining = (timeSinceStart - timeSincePause) - totalTimeElapsedAtMomentOfPause
                let timeLostFromPausing = timeSincePause + secondsRemaining
                
                self.state = .running(originalStartDate: originalStartDate,
                                      timeLostFromPausing: timeLostFromPausing)
                
            case .running(originalStartDate: _, timeLostFromPausing: _),
                    .completed(completionDate: _):
                break
            }
            return self
        }
    }
    
    
    /// Pauses this timer
    ///
    /// If the timer is paused, not yet started, or has completed, this has no effect.
    ///
    /// - Returns: _optional_ - `self`, to chain calls
    @discardableResult
    func pause() async -> Timer {
        let now = Date()
        
        switch await self.state {
        case .notStarted,
                .completed,
                .paused:
            break
            
        case .running(originalStartDate: let originalStartDate,
                      timeLostFromPausing: let timeLostFromPausing):
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.state = .paused(originalStartDate: originalStartDate,
                                     pauseDate: now,
                                     totalTimeElapsedAtMomentOfPause: now.timeIntervalSince(originalStartDate) - timeLostFromPausing)
            }
        }
        
        return self
    }
    
    
    /// Stops this timer permanently
    ///
    /// If the timer is already completed, this has no effect
    ///
    /// - Returns: _optional_ - `self`, to chain calls
    @discardableResult
    func stop() async -> Timer {
        let now = Date()
        
        let totalTimeElapsed: TimeInterval
        
        switch await self.state {
        case .notStarted:
            totalTimeElapsed = 0
            
        case .running(originalStartDate: let originalStartDate, timeLostFromPausing: let timeLostFromPausing):
            totalTimeElapsed = now.timeIntervalSince(originalStartDate) - timeLostFromPausing
            
        case .paused(originalStartDate: _, pauseDate: _, totalTimeElapsedAtMomentOfPause: let totalTimeElapsedAtMomentOfPause):
            totalTimeElapsed = totalTimeElapsedAtMomentOfPause
            
        case .completed(completionDate: _, totalTimeElapsed: _):
            return self
        }
        
        return await MainActor.run { [self] in
            self.state = .completed(completionDate: now, totalTimeElapsed: totalTimeElapsed)
            return self
        }
    }
    
    
    /// Describes the current value of this timer in a way that can be relyed to the user
    @MainActor
    var currentValue: Value {
        lazy var now = Date()
        
        switch state {
        case .notStarted:
            switch kind {
            case .countUp(totalTimeToCountUp: _):
                return .notStarted(startingValue: 0)
                
            case .countDown(totalTimeToCountDown: let totalTimeToCountDown):
                return .notStarted(startingValue: totalTimeToCountDown)
            }
            
        case .running(originalStartDate: let originalStartDate, timeLostFromPausing: let timeLostFromPausing): // TODO: Test
            let secondsElapsedExcludingPauses = (-originalStartDate.timeIntervalSince(now)) - timeLostFromPausing
            switch kind {
            case .countUp(totalTimeToCountUp: let totalTimeToCountUp):
                if secondsElapsedExcludingPauses >= totalTimeToCountUp {
                    self.state = .completed(completionDate: originalStartDate + totalTimeToCountUp + timeLostFromPausing,
                                            totalTimeElapsed: secondsElapsedExcludingPauses)
                    return .running(currentValue: totalTimeToCountUp)
                }
                else {
                    return .running(currentValue: secondsElapsedExcludingPauses)
                }
                
            case .countDown(totalTimeToCountDown: let totalTimeToCountDown):
                return .running(currentValue: max(0, totalTimeToCountDown - secondsElapsedExcludingPauses))
            }
            
        case .paused(originalStartDate: _,
                     pauseDate: _,
                     totalTimeElapsedAtMomentOfPause: let totalTimeElapsedAtMomentOfPause): // TODO: Test
            switch kind {
            case .countUp(totalTimeToCountUp: _):
                return .paused(currentValue: totalTimeElapsedAtMomentOfPause)
                
            case .countDown(totalTimeToCountDown: let totalTimeToCountDown):
                return .paused(currentValue: totalTimeToCountDown - totalTimeElapsedAtMomentOfPause)
            }
            
        case .completed(completionDate: _,
                        totalTimeElapsed: let totalTimeElapsed):
            return .completed(finalValue: totalTimeElapsed)
        }
    }
}



private extension Timer {
    
    /// Determines the date at which this timer will complete, or `nil` if it will never complete
    func dateOfCompletion() async -> DateOfCompletion? {
        let now = Date()
        
        switch kind {
        case .countUp(totalTimeToCountUp: let totalTimeToCount),
                .countDown(totalTimeToCountDown: let totalTimeToCount):
            
//        switch kind {
//        case .countUp(totalTimeToCountUp: let totalTimeToCountUp):
//            guard totalTimeToCountUp.isFitForUseInDateCalculations else {
//                return nil
//            }
//
//            switch state {
//            case .notStarted:
//                return .paused(dateOfCompletionIfResumedNow: now + totalTimeToCountUp)
//
//            case .running(originalStartDate: let originalStartDate,
//                          timeLostFromPausing: let timeLostFromPausing):
//                return .exactly(dateOfCompletion: (originalStartDate + totalTimeToCountUp) - timeLostFromPausing) // TODO: Test
//
//            case .paused(originalStartDate: _,
//                         pauseDate: _,
//                         totalTimeElapsedAtMomentOfPause: let totalTimeElapsedAtMomentOfPause):
//                let timeRemainingAtMomentOfPause = totalTimeToCountUp - totalTimeElapsedAtMomentOfPause
//                return .paused(dateOfCompletionIfResumedNow: now + timeRemainingAtMomentOfPause) // TODO: Test
//
//            case .completed(completionDate: let completionDate, totalTimeElapsed: _):
//                return .exactly(dateOfCompletion: completionDate)
//            }
//
//
//        case .countDown(totalTimeToCountDown: let totalTimeToCountDown):
            guard totalTimeToCount.isFitForUseInDateCalculations else {
                return nil
            }
            
            switch await state {
            case .notStarted:
                return .paused(dateOfCompletionIfResumedNow: now + totalTimeToCount)
                
            case .running(originalStartDate: let originalStartDate, timeLostFromPausing: let timeLostFromPausing):
                return .exactly(dateOfCompletion: (originalStartDate + totalTimeToCount) - timeLostFromPausing) // TODO: Test
                
            case .paused(originalStartDate: _,
                         pauseDate: _,
                         totalTimeElapsedAtMomentOfPause: let totalTimeElapsedAtMomentOfPause):
                let timeRemainingAtMomentOfPause = totalTimeToCount - totalTimeElapsedAtMomentOfPause
                return .paused(dateOfCompletionIfResumedNow: now + timeRemainingAtMomentOfPause) // TODO: Test
                
            case .completed(completionDate: let completionDate, totalTimeElapsed: _):
                return .exactly(dateOfCompletion: completionDate)
            }
        }
    }
    
    
    
    /// The date at which a timer has or will have completed
    enum DateOfCompletion {
        
        /// If a timer is completed, this is the date at which it did complete. If a timer is not started or still running, this is the date at which it will complete if it is not paused between now and then.
        ///
        /// If a timer is paused, then `.paused` is used to represent that instead
        case exactly(dateOfCompletion: Date)
        
        /// If a timer is paused, this is the date at which it would complete if it were resumed when this was returned.
        ///
        /// If a timer is not started, running, or completed, then `.exactly` is sent instead
        case paused(dateOfCompletionIfResumedNow: Date)
    }
    
    
    
    /// The current state of a timer object
    enum State {
        
        /// The timer has not yet been started, or has been reset
        case notStarted
        
        /// The timer is running
        ///
        /// - Parameters:
        ///    - originalStartDate:   The date when the timer was first started
        ///    - timeLostFromPausing: How long the timer has been paused in total since it was first started
        case running(originalStartDate: Date, timeLostFromPausing: TimeInterval)
        
        /// The timer is paused
        ///
        /// - Parameters:
        ///    - originalStartDate:               The date when the timer was first started
        ///    - pauseDate:                       The date at which the timer enterd this particular pause state. Any previous pause dates are forgotten, as they are not necessary
        ///    - totalTimeElapsedAtMomentOfPause: The total amount of time which elapsed in the timer at the moment that it entered this pause state. This is calculated with previous pauses in-mind, so multiple pauses are always reflected correctly.
        case paused(originalStartDate: Date, pauseDate: Date, totalTimeElapsedAtMomentOfPause: TimeInterval)
        
        /// The timer has reached completion! In this state it cannot be interacted with except for `reset()`
        ///
        /// - Parameters:
        ///    - completionDate:   A trivial bit of information regarding the date the timer completed
        ///    - totalTimeElapsed: The total time which had elapsed on the timer at the moment it had completed
        case completed(completionDate: Date, totalTimeElapsed: TimeInterval)
    }
}



public extension Timer {
    
    /// The kind of a timer. See documentation for each case for more nuance
    enum Kind {
        
        /// A timer which starts at zero and counts upwards, optionally with an end time where it automatically stops
        /// - Parameter totalTimeToCountUp: _optional_ - The highest value this timer can have before it automatically stops.
        ///                                 Any non-finite value (e.g. `.infinity`, `.nan`, etc.) is considered to mean "do not stop counting up automatically"
        case countUp(totalTimeToCountUp: TimeInterval = .infinity)
        
        /// A timer which starts at some non-zero value and counts down to zero, at which point it automatically stops
        /// - Parameter totalTimeToCountDown: The starting (highest) value of the timer.
        ///                                   A value of `0` is considered to mean "immedately complete once started".
        ///                                   Any non-finite (e.g. `.infinity`, `.nan`, etc.) or negative value is considered to mean `0`.
        case countDown(totalTimeToCountDown: TimeInterval)
    }
    
    
    
    /// The value of a timer
    enum Value {
        
        /// A timer which has not yet been started
        /// - Parameter startingValue: The value the timer will have at the very moment it is started. For count-up timers this is always zero. For count-down timers this is always the total time it can count down
        case notStarted(startingValue: TimeInterval)
        
        /// A timer which is currently running and is not paused
        case running(currentValue: TimeInterval)
        
        /// A timer which is currently paused
        case paused(currentValue: TimeInterval)
        
        /// A timer which has reached its target end time, or which has been manually stopped
        case completed(finalValue: TimeInterval)
    }
    
    
    
    typealias StateChangePublisher = AnyPublisher<Value, Never>
}



// MARK: - Conformances

extension Timer.Value: Equatable {
    
}



// MARK: - Internal utilities

private extension Timer {
    
    static var _dummy: Timer! = nil
    
    static func dummy() async -> Timer {
        if let dummy = _dummy {
            return dummy
        }
        else {
            self._dummy = await Timer(kind: .countDown(totalTimeToCountDown: .nan))
                .stop()
            return _dummy
        }
    }
}



// MARK: - External Conveneinces

private extension TimeInterval {
    /// Determines whether this time interval is fit to be used when performing date-based calculations.
    ///
    /// For example, `.infinity` and `.NaN` would be unfit for performing calculations on a date
    var isFitForUseInDateCalculations: Bool {
        isFinite
    }
}
