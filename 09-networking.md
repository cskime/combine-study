# Networking

## Summary

- Combine offers a publisher-based abstraction for its `dataTask(with:completionHandler:)` method called `dataTaskPublisher(for:)`.
- Decode a resulting data with the `Codable`-conforming models using the `decode(type:decoder:)` operator that emits `Data` values.
- While there's no operator to share a replay of a subscription with multiple subscribers, you can recreate this behavior using a `ConnectablePublisher` and the `multicast()` operator.

## URLSession extensions and Codable support

- `URLSession` provides `dataTaskPublisher(for:)` API which takes a `URL` or `URLRequest` as a parameter and returns `Data` and `URLResponse`.
- Use `decode(type:decoder:)` to decode `Data` to specified `Codable` type.
  - Since `dataTaskPublisher(for:)` emits a tuple, this operator cannot be used directly without first using a `map(_:)` that only emits the `Data` part of the result.

```swift
let subscription = URLSession.shared
    .dataTaskPublisher(for: url)  // perform a request to the URL
    .map(\.data)
    .decode(type: MyType.self, decoder: JSONDecoder())  // decode resulting data into MyType
```

## Publishing network data to multiple subscribers

- Everytime a subscriber is attached to a publisher, a request starts.
- This means sending the same request multiple times if multiple subscribers need the request.
- It's tricky to use the `share()` operator because **you need to subscribe all your subscribers before the result comes back**.
- One solution is to use the **`multicast()` operator**, which creates a `ConnectablePublisher` that publishes values through a `Subject`.
  - Use `multicast()` with a closure which returns a subject.
  - Use `multicast(subject:)` to use an existing subject.
- `multicast()` operator allows to subscribe multiple times to the subject, then call the publisher's `connect()` method when it's ready.
- With this operator, **a request is sended one time and share the outcome with all subscribers**.

```swift
let publisher = URLSession.shared
    .dataTaskPublisher(for: url)
    .map(\.data)
    .multicast { PassthroughSubject<Data, URLError>() }

publisher
    .sink(
        receiveCompletion: { print("Sink 1 completion : \($0)") },
        receiveValue: { print("Sink 1 receive value : \($0)") }
    )
    .store(in: &subscriptions)

publisher
    .sink(
        receiveCompletion: { print("Sink 2 completion : \($0)") },
        receiveValue: { print("Sink 2 receive value : \($0)") }
    )
    .store(in: &subscriptions)

publisher
    .connect()  // starts data task
    .store(in: &subscriptions)
```
