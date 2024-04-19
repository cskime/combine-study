# Publishers & Subscribers

## Summary

- Publishers transmit a sequence of values over time to one or more subscribers. (either sync or async)
  - Use [`Just`](#just) to receive a single value synchronously and then finishes.
  - Use [`Future`](#future) to receive a single value asynchronously at a later time.
- A subscriber can subscribe to a publisher to receive values.
  - There are two built-in operators to subscribe to publishers
  - [`sink(_:_:)`](#subscribing-with-sink__)
  - [`assign(to:on:)`](#subscribing-with-assigntoon)
- A subscriber may increase the demand for values each time it receives a value(`receive(_:)`), but it cannot decrease demand.
- To free up resources and prevent unwanted side effects,
  - cancel each subscription when a task is done.
  - store a subscription in an instance or collection of `AnyCancellable` **to receive automatic cancelation upon deinitialization**.
- Subjects are publishers that **enables outside callers to send multiple values** asynchronously to subscribers.
  - `PassthroughSubject`
  - `CurrentValueSubject`
- Type erasure prevents callers from being able to access additional details of **the underlying type**.

## Publisher

- `Publisher` protocol defines the requirements for a type to be able to transmit a sequence of values over time to one or more subscribers.
- A publisher "publishes" or emits events that can include values of interest.
- A publisher can emit zero or more values but **only one completion event**, which can either be a normal completion event or an error.
- Once a publisher emits a completion event, it's finished and **can no longer emit any more events**.
- What's difference between Swift iterator?
  - A publisher is somewhat similar to a Swift iterator.
  - You need to actively **pull values** from iterator.
  - A publisher **pushes values** to its consumer.

### Just

```swift
let justPublisher = Just("Hello world")
let subscription = justPublisher
    .sink {
        print("Receive completion :", $0)
    } receiveValue: { value in
        print("Receive value :", $0)
    }

// Prints
// Hello world
// finished
```

- `Just` publisher emits its output to each subscriber **exactly once** and then finishes.

### Future

```swift
func futureIncrement(integer: Int, afterDelay delay: TimeInterval) -> Future<Int, Never> {
    Future<Int, Never> { promise in
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            promise(.success(integer + 1))
        }
    }
}

let futurePublisher = futureIncrement(integer: 1, afterDelay: 3)
var subscriptions = Set<AnyCancellable>()
let subscription = futurePublisher
    .sink(receiveCompletion: { print($0) },
          receiveValue: { print($0) })
    .store(in: &subscriptions)
```

- A `Future` is a publisher that will eventually produce a single value and finish, or it will fail.
- A `Future` can be used to **asynchronously produce a single result** and then complete.
- `Promise` is a type alias to a closure that receives a `Result` containing either a single value published by the `Future`, or an error.
  ```swift
  final public class Future<Output, Failure> : Publisher where Failure : Error {
      public typealias Promise = (Result<Output, Failure>) -> Void
  }
  ```
- If you don't store the subscription, it'll be canceled as soon as the current code scope ends.
- the future doesn't re-execute its promise; instead, **it shares or replays its output** to all subscribers.
- **A future executes as soon as it's created**.
  - Regular publishers don't emit events until a subscriber subscribe the publisher.
  - A future **doesn't require a subscriber like regular publishers that are lazy**.

## Subscriber

- `Subscriber` protocol defines the requirements for a type to be able to **receive input from a publisher**.
- A subscriber consum values from a publisher.
- A publisher doesn't emit values unti a subscriber consumes them.

### Subscribing with `sink(_:_:)`

```swift
let subscription = publisher.sink(
    receiveCompletion: { completion in
        print("Received completion :", completion)
    },
    receiveValue: { value in
        print("Received value :", value)
    }
)
```

- `sink(_:_:)` provides an easy way **to attach a subscriber with closures** to handle output from a publisher.
- The `sink` operator will continue to receive as many values as the publisher emits (**unlimited demand**).
- The `sink` operator provides two closures:
  1. one to handle **receiving a completion** event(a success or a failure)
  2. one to handle **receiving values**.

### Subscribing with `assign(to:on:)`

```swift
class SomeObject {
    var value = "" {
        didSet { print(value) }
    }
}

let object = SomeObject()
let publisher = ["Hello", "world!"].publisher
let subscription = publisher.assign(to: \.value, on: object)
```

- `assign(to:on:)` is the built-in operator that enables you to assign the received value to a **KVO-compliant** property of an object.
- It's especially useful when working on UIKit or AppKit apps because you can assign values directly to UI components.

### Republishing with `assign(to:)`

```swift
class SomeObject {
    @Published var value = 0
}

let object = SomeObject()
let valuePublisher = object.$value
valuePublisher.sink { print($0) }

(0..<10).publisher.assign(to: &valuePublisher)
```

- `assign(to:)` republish values emitted by a publisher through another property marked with the `@Published` property wrapper.
  - `@Published` creates a publisher for the property in addition to being accessible as a regular property.
  - Use the `$` prefix on the `@Published` property to gain access to its underlying publisher.
- The `assign(to:)` operator doesn't return an `AnyCancellable` token, because it manages the lifecycle internally and **cancels the subscription when the `@Published` property deinitializes**.

```swift
class SomeObject {
    @Published var word = 0
    var subscriptions = Set<AnyCancellable>()

    init() {
        let publisher = ["A", "B", "C"].publisher

        // ❌ : Storing in `subscriptions` results in a string reference cycle.
        publisher
            .assign(to: \.word, on: self)
            .store(in: &subscriptions)

        // ✅ : This code can prevent strong reference cycle problem.
        publisher
            .assign(to: &$word)
    }
}
```

## Cancellable

- When a subscriber **finishes its work and no longer wants to receive values from a publisher**, it's a good idea to **cancel the subscription** to free up resources and stop any corresponding activities from occuring.
- Subscriptions return an instance of `AnyCancellable` which makes it possible to cancel the subscription.
- `AnyCancellable` conforms to the `Cancellable` protocol, which requires the `cancel()` method.
- If you don't explicitly call `cancel()` on a subscription, it will continue until **the publisher completes**, or until **normal memory management causes a stored subscription ot deinitialize**.

## Subject

- A subject acts as a go-between **to enable non-Combine imperative code to send values to Combine subscribers**.
- `PassthroughSubject` publishes new values on demand.
- `CurrentValueSubject` publishes new values **with an initial value**.
  - Subscribers which subscribe the `CurrentValueSubject` immediately get that value or the latest value.
  - You can get a `CurrentValueSubject`'s current value by accessing its `value` property.

## Behind the scene

### `Publisher` protocol

```swift
public protocol Publisher {
    associatedtype Output
    associatedtype Failure : Error

    func receive<S>(subscriber: S)
        where S : Subscriber,
        Self.Failure == S.Failure,
        Self.Output == S.Input
}

extension Publisher {
    public func subscribe<S>(_ subscriber: S)
        where S : Subscriber,
        Self.Failure == S.Failure,
        Self.Output == S.Input
}
```

- A subscriber calls `subscribe(_:)` on a publisher **to attach to it**.
- The implementation of `subscribe(_:)` will call `receive(subscriber:)` **to attach the subscriber to the publisher**.

### `Subscriber` protocol

```swift
public protocol Subscriber: CustomCombineIdentifierConvertible {
    associatedtype Input
    associatedtype Failure: Error

    func receive(subscription: Subscription)
    func receive(_ input: Self.Input) -> Subscribers.Demand
    func receive(completion: Subscribers.Completion<Self.Failure>)
}
```

- The publisher calls `receive(subscription:)` **to give it the subscription**.
- The publisher calls `receive(_:)` **to send it a new value**.
- The publisher calls `receive(completion:)` **to tell it that it has finished producing values**.

### `Subsription` protocol

```swift
public protocol Subscription: Cancellable, CustomCombineIdentifierConvertible {
    func request(_ demand: Subscribers.Demand)
}
```

- The connection between the publisher and the subscriber is the **subscription**.
- The subscriber calls `request(_:)` **to indicate it is willing to receive more values**.
  - In `Subscriber`, `receive(_:)` returns a `Demand` too.
  - Even though `subscription.request(_:)` sets the initial max number of values a subscriber is willing to receive, **you can adjust that max each time a new value is received**.
  - It's additive; the new `max` value is added to the current `max` which is set by `request(_:)`.
  - `max` value only can be increased each time a new value is changed.
- A publisher doesn't send a completion when **a subscriber requests values less than the publisher produces**.
  - Even the subscriber requests values less than the publisher provides, if the subscriber return additional `Demand` enough to receive all values on the publisher in `receive(_:)` method, the publisher will send completion event.

### How does it work?

1. The subscriber subscribes to the publisher calling `subscribe(_:)` on the publisher.
2. The publisher creates a subscription and gives it to the subscriber calling `receive(subscription:)` on the subscriber.
3. The subscriber requests values calling `request(_:)` on the subscription.
   - Requests the number of values the subscriber is willing to receive. (unlimited, maximum, or none)
4. The publisher sends values calling `receive(_:)` on the subscriber.
5. The publisher sends a completion calling `receive(completion:)` on the subscriber.

```swift
final class IntSubscriber: Subscriber {
    typealias Input = Int
    typealias Failure = Never // There's no error

    // 2.
    func receive(subscription: Subscription) {
        // 3.
        subscription.request(.max(3))
    }

    // 4.
    func receive(_ input: Int) -> Subscribers.Demand {
        print("Received value", input)
        return .none
    }

    // 5.
    func receive(completion: Subscribers.Completion<Never>) {
        print("Received completion", completion)
    }
}

let publisher = (1...6).publisher
let subscriber = IntSubscriber()

// 1.
publisher.subscribe(subscriber)
```

## Type erasure

- `AnyPublisher`
  - Hiding details about a publisher from subscribers.
  - It's a type-erased struct that conforms the `Publisher` protocol.
  - It **hides details about the publisher** that you may not want to expose the subscribers.
  - Outside callers only access the public publisher for subscribing but **not be able to send values**.
  - The `eraseToAnyPublisher()` operator wraps the provided publisher in an instance of `AnyPublisher`.
- `AnyCancellable`
  - It's a type-erased class that conforms to `Cancellable` protocol.
  - It lets callers cancel the subscription **without being able to access the underlying subscription**.

## Bridging Combine publishers to async/await

```swift
Task {
    for await element in subject.values {
        print("Element: \(element)")
    }
    print("Completed.")
}
```

- The `values` property returns **an asynchronous sequence** with the elements emitted by the subject or publisher.
- **Once the publisher completes, the loop ends** and the execution continues on the next line.
- Sending the `finished` event will also end the llop in your asynchronous task.
