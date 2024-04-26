# Debugging

## Summary

- Use [`print(_:to:)`](#print_to) to print the lifecycle of a publisher in a console.
- Use [`handleEvents()`](#handleevents) to intercept lifecycle events and perform side effects.
- Use [`breakpointOnError`, `breakpoint()`](#breakpointonerror-breakpoint) to let Xcode to break on specific events.

## `print(_:to:)`

```swift
class TimeLogger: TextOutputStream {
    private var previous = Date()
    private let formatter = NumberFormatter()

    init() {
        formatter.maximumFractionDigits = 5
        formatter.minimumFractionDigits = 5
    }

    func write(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaceAndNewlines)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        let interval = formatter.string(for: now.timeIntervalSince(previous))!
        print("+\(interval)s: \(string)"); // print a custom string
        previous = now
    }
}

(1...3).publisher
    .print("My publisher", to: TimeLogger())
    .sink { _ in }
    .store(in: &subscriptions)

// Prints
// +0.03485s: publisher: request unlimited
// +0.00111s: publisher: receive subscription: (1...3)
// +0.00035s: publisher: receive value: (1)
// +0.00025s: publisher: receive value: (2)
// +0.00027s: publisher: receive value: (3)
// +0.00024s: publisher: receive finished
```

- The `print(_:to:)` operator prints the information about the upstream publisher
  1. A received subscription
  2. The subscriber's demand request
  3. Every emitted value
- Use `TextOutputStream` object to customize the printing strings.

## `handleEvents()`

```swift
URLSession.shared
    .dataTaskPublisher(for: URL(string: "https://google.com")!)
    .handleEvents(
        receiveSubscriptions: { print("Network request will start") },
        receiveOutput: { print("Network request data received") },
        receiveCancel: { print("Network request cancelled") }
    )
    .sink(
        receiveCompletion: { print("Sink received completion: \($0)") },
        receiveValue: { print("Sink received value: \($0)") }
    )
    .store(in: &subscriptions)

// Prints
// Network request will start          ===> from the `handleEvents`
// Network request data received
// Sink received data: 303094 bytes    ===> from the `sink`
// Sink received completion: finished
```

- The `handleEvents()` operator **performs side effects** upon specific events.
- **It intercepts any and all events in the lifecycle of a publisher** and then take action at seach step.

## `breakpointOnError()`, `breakpoint()`

- The `breakpointOnError()` operator lets Xcode to break in the debugger **if any of the upstream publisher emits an error**.
- The `breakpoint(receiveSubscription:receiveOutput:receiveCompletion:)` operator **intercepts all events and decides whether the Xcode break in the debugger**. (returns `Bool` in the closure)
  ```swift
  // break if the integer value is 11 ~ 14
  .breakpoint(receiveOutput: { $0 > 10 && $0 < 15 })
  ```
