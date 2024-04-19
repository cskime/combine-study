# Time Manipulation Operators

## Summary

- The core idea behind reactive programming is to model asynchronous event flow **over time**.
- How sequence react to and transform values over time.
- Shifting time
  - [`delay(for:scheduler:options:)`](#delayforscheduleroptions)
- Collecting values
  - [`collect(_:options:)`](#collect_options)
- Holding off on events : picking individual values over time
  - [`debounce(for:scheduler:)`](#debounceforscheduler)
  - [`throttle(for:scheduler:latest:)`](#throttleforschedulerlatest)
- Timing out : not letting time run out
  - [`timeout(_:scheduler:customError:)`](#timeout_schedulercustomerror)
- Measuring time : measuring the time between two consecutive values
  - [`measureInterval(using:)`](#measureintervalusing)

## Shifting time

### `delay(for:scheduler:options:)`

```swift
[1, 2, 3].publisher
    .delay(for: .seconds(1.5), scheduler: DispatchQueue.main)
    .sink(receiveValue: { print($0) })
    .store(&subscriptions)

// Prints
// 1    => emits after 1 seconds
// 2
// 3
```

- The `delay(for:scheduler:options:)` operator time-shifts a whole sequence of values.
- It keeps values from the upstream publisher for a while then **emits it after the delay**.

## Collecting values

### `collect(_:options:)`

```swift
let sourcePublisher = PassthroughSubject<Int, Never>()
Timer
    .publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .map { _ in
        let old = count
        count += 1
        return old
    }
    .subscribe(sourcePublisher)
    .store(in: &subscriptions)

// 1. Using .byTime(_:_:)
sourcePublisher
    .collect(.byTime(DispatchQueue.main, .seconds(4)))
    .sink(receiveValue: { print($0) })
    .store(in: &subscriptions)

// Prints
// [1, 2, 3, 4]
// [5, 6, 7]              => Value from the collected publisher doesn't always emit four values
// [8, 9, 10, 11, 12]
// [13, 14, 15, 16]

// 2. Using .byTimeOrCount(_:_:_:)

```

- The `collect(_:options:)` operator collects values from a publisher **at specified time intervals**. (buffering)
  - With `.byTime(_:_:)` strategy, the number of values collected isn't limited.
  - With `.byTimeOrCount(_:_:_:)` strategy, the number of values collected is limited by the specified count.
- When you limit the number of values collected, the publisher emits only specified number of values though it doesn't pass the specified time.
- It can be useful when you want to average a group of values **over short periods of time** and output the average.
- Every time `collect` emits a group of values it collected.

## Holding off on events

- `debounce` **waits for a pause in values it receives**, then emits the latest one after the specified interval.
- `throttle` **waits for the specified interval**, then emits either the first or the latest of the values it received during that interval. **It doesn't care about pauses**.

### `debounce(for:scheduler:)`

```swift
let typingHelloWorld: [(TimeInterval, String)] = [
  (0.0, "H"),
  (0.1, "He"),
  (0.2, "Hel"),
  (0.3, "Hell"),
  (0.5, "Hello"),
  (0.6, "Hello "),
  (2.0, "Hello W"),
  (2.1, "Hello Wo"),
  (2.2, "Hello Wor"),
  (2.4, "Hello Worl"),
  (2.5, "Hello World")
]

typingPublisher
    .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
    .share()
    ...

// Prints
// Hello            => emits the last value in 0.6s ~ 1.6s range
// Hello World      => emits the last value in 2.5s ~ 3.5s range
```

- The `debounce(for:scheduler:)` operator waits for specified time on emissions from the publisher, then **it will send the last value** sent in duration of time, if any.
- Use `share()` to **create a single subscription that will show the same results at the same time to all subscribers**.
- It can be useful if you want to receive a typing event only when the user is done typing for a while.
- If the publisher completes right after the last value was emitted, but before the time configured for debounce elapses, **the publisher doesn't emit the last value**.

### `throttle(for:scheduler:latest:)`

```swift
let typingHelloWorld: [(TimeInterval, String)] = [
  (0.0, "H"),
  (0.1, "He"),
  (0.2, "Hel"),
  (0.3, "Hell"),
  (0.5, "Hello"),
  (0.6, "Hello "),
  (2.0, "Hello W"),
  (2.1, "Hello Wo"),
  (2.2, "Hello Wor"),
  (2.4, "Hello Worl"),
  (2.5, "Hello World")
]

typingPublisher
    .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: false)
    .share()
    ...

// Prints
// H            => emits the first value immediately (at 0.0s)
// He           => emits the first value in 0.0s ~ 1.0s
// Hello W      => emits the first value in 1.0s ~ 2.0s
// Hello World  => emits the first value in 2.0s ~ 3.0s
```

- The `throttle(for:scheduler:latest:)` operator only emits the first value it received from subject during the time if the `latest` argument is set to `false`.
  - If the `latest` value is `true`, throttled publisher **emits the last value** in the interval.
  - In the above example, it will emit `H`, `Hello `, `Hello World`.
- It emits a value immediately, and then starts throttling the output.

## Timing out

### `timeout(_:scheduler:customError)`

```swift
let subject = PassthroughSubject<Void, Never>()
subject
    .timeout(.seconds(5), scheduler: DispatchQueue.main)
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )
    .store(in: &subscriptions)

// Prints
// finished    => send a completion after 5 seconds without any published values.

enum TimeOutError {
    case timedOut
}
let errorSubject = PassthroughSubject<Void, TimeoutError>()
errorSubject
    .timeout(.seconds(5), scheduler: DispatchQueue.main, customError: { .timedOut })
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )
    .store(in: &subscriptions)

// Prints
// timedOut
```

- The `timeout(_:scheduler:customError:)` operator will time-out after five seconds **without the upstream publisher emitting any value**.
- It forces a publisher completion **without any failure**.
  - If you pass an error to `customError` parameter, it will complete with error.
- If some event is emitted at less than specified time intervals, timeout publisher never completes.

## Measuring time

### `measureInterval(using:)`

```swift
let typingHelloWorld: [(TimeInterval, String)] = [
  (0.0, "H"),
  (0.1, "He"),
  (0.2, "Hel"),
  (0.3, "Hell"),
  (0.5, "Hello"),
  (0.6, "Hello "),
  (2.0, "Hello W"),
  (2.1, "Hello Wo"),
  (2.2, "Hello Wor"),
  (2.4, "Hello Worl"),
  (2.5, "Hello World")
]

typingPublisher
    .measureInterval(using: DispatchQueue.main)
    .sink(receivValue: { print($0) })
    .store(in: &subscriptions)

// Prints
// Stride(magnitude: 16818353)    => time interval between at the beginning and at the time "H" is emitted.
// Stride(magnitude: 87377323)    => time interval between "H" and "He"
// Stride(magnitude: 111515697)   => time interval between "He" and "Hel"
// ...
```

- The `measureInterval(using:)` operator measures the time that **elapsed between two consecutive values a publisher emitted**.
- The type of the value `measureInterval(using:)` emits is **the time interval of the provided scheduler**.
- **If you use `RunLoop.main` instead of `DispatchQueue.main`, the time interval can be silghtly different**.
