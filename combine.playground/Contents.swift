import UIKit
import Combine

func example(of description: String, action: () -> Void) {
    print("\n--- Example of:", description, "---")
    action()
}

example(of: "Publisher and Subscriber") {
    let name = Notification.Name("My Notification")
    let center = NotificationCenter.default
    let publisher = center.publisher(for: name)
    let subscription = publisher.sink { _ in print("Received") }
    center.post(name: name, object: nil)
}

example(of: "Subscribing using sink(_:_:)") {
    let publisher = Just("Hello world!")
    let subscription = publisher.sink { completion in
        print("Received completion", completion)
    } receiveValue: { value in
        print("Received value", value)
    }
}

example(of: "Subscribing using assign(to:on:)") {
    class SomeObject {
        var value = "" {
            didSet { print(value) }
        }
    }
    
    let object = SomeObject()
    let publisher = ["Hello", "world!"].publisher
    let subscription = publisher.assign(to: \.value, on: object)
}

example(of: "Republishing using assign(to:)") {
    class SomeObject {
        @Published var value = 0
    }
    
    let object = SomeObject()
    object.$value.sink { print($0) }
    (0..<10).publisher.assign(to: &object.$value)
}

example(of: "Custom Subscriber") {
    final class IntSubscriber: Subscriber {
        typealias Input = Int
        typealias Failure = Never
        
        func receive(subscription: any Subscription) {
            subscription.request(.max(3))
        }
        
        func receive(_ input: Int) -> Subscribers.Demand {
            print("Received value", input)
            //            return .none
            return .max(1)
        }
        
        func receive(completion: Subscribers.Completion<Never>) {
            print("Received completion", completion)
        }
    }
    
    let publisher = (1...6).publisher
    let subscriber = IntSubscriber()
    
    // It takes only three values though the publisher emits six values.
    publisher.subscribe(subscriber)
}

//example(of: "Future") {
//    func futureIncrement(integer: Int, afterDelay delay: TimeInterval) -> Future<Int, Never> {
//        Future<Int, Never> { promise in
//            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
//                promise(.success(integer + 1))
//            }
//        }
//    }
//
//    var subscriptions = Set<AnyCancellable>()
//    let future = futureIncrement(integer: 1, afterDelay: 3)
//    future.sink {
//        print($0)
//    } receiveValue: {
//        print($0)
//    }
//    .store(in: &subscriptions)
//}

example(of: "PassthroughSubject") {
    enum MyError: Error {
        case test
    }
    
    final class StringSubscriber: Subscriber {
        typealias Input = String
        typealias Failure = MyError
        
        func receive(subscription: any Subscription) {
            subscription.request(.max(2))
        }
        
        func receive(_ input: String) -> Subscribers.Demand {
            print("Received value", input)
            return input == "World" ? .max(1) : .none
        }
        
        func receive(completion: Subscribers.Completion<MyError>) {
            print("Received completion", completion)
        }
    }
    
    let subscriber = StringSubscriber()
    let subject = PassthroughSubject<String, MyError>()
    subject.subscribe(subscriber)
    let subscription = subject.sink { completion in
        print("Received completion (sink)", completion)
    } receiveValue: { value in
        print("Received value (sink)", value)
    }
    subject.send("Hello")
    subject.send("World")
    subscription.cancel()
    subject.send("Still there?")
    subject.send(completion: .finished)
    subject.send("How about another one?")
}

example(of: "CurrentValueSubject") {
    var subscriptions = Set<AnyCancellable>()
    let subject = CurrentValueSubject<Int, Never>(0)
    subject
        .print()
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
    subject.send(1)
    subject.send(2)
    print(subject.value)
    subject
        .sink(receiveValue: { print("Second subscription:", $0) })
        .store(in: &subscriptions)
}

example(of: "Dynamically adjusting Demand") {
    final class IntSubscriber: Subscriber {
        typealias Input = Int
        typealias Failure = Never
        
        func receive(subscription: any Subscription) {
            subscription.request(.max(2))
        }
        
        func receive(_ input: Int) -> Subscribers.Demand {
            print("Received value", input)
            switch input {
            case 1:
                return .max(2)
            case 3:
                return .max(1)
            default:
                return .none
            }
        }
        
        func receive(completion: Subscribers.Completion<Never>) {
            print("Received completion", completion)
        }
    }
    
    let subscriber = IntSubscriber()
    let subject = PassthroughSubject<Int, Never>()
    subject.subscribe(subscriber)
    
    subject.send(1) // 4
    subject.send(2) // 4
    subject.send(3) // 5
    subject.send(4) // 5
    subject.send(5) // 5
    subject.send(6)
    
    // It won't be finished because the subscriber demands only five values from the publisher.
}

example(of: "Type erasure") {
    var subscriptions = Set<AnyCancellable>()
    let subject = PassthroughSubject<Int, Never>()
    let publisher = subject.eraseToAnyPublisher()
    publisher
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
    subject.send(0)
}

example(of: "async/await") {
    let subject = CurrentValueSubject<Int, Never>(0)
    Task {
        for await element in subject.values {
            print("Element: \(element)")
        }
        print("Completed.")
    }
    
    subject.send(1)
    subject.send(2)
    subject.send(3)
    subject.send(completion: .finished)
}

example(of: "merge(with:)") {
    var subscriptions = Set<AnyCancellable>()
    
    // 1
    let publisher1 = PassthroughSubject<Int, Never>()
    let publisher2 = PassthroughSubject<Int, Never>()
    
    // 2
    publisher1
        .merge(with: publisher2)
        .sink(
            receiveCompletion: { _ in print("Completed") },
            receiveValue: { print($0) }
        )
        .store(in: &subscriptions)
    
    // 3
    publisher1.send(1)
    publisher1.send(2)
    
    publisher2.send(3)
    
    publisher1.send(4)
    
    publisher2.send(5)
    
    // 4
    publisher1.send(completion: .finished)
    publisher2.send(completion: .finished)
}
