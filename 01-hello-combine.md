# Hello Combine

- The Combine framework is a declarative, reactive framework for processing asynchronous events over time.
  - publishers : emit events over time
  - operators : process and manipulate upstream events asynchronously
  - subscribers : consume the results and do something
- With the Combine, you can create **a single processing chain for a given events source** instead of implementing multiple delegates or completion handler clousre callbacks.

## Asynchronous programming

- When the code is running concurrently on different cores, it's difficult to say **which part of the code is going to modify the shared state first**.
- Managin mutable state in your app becomes a loaded task once you run asynchronous concurrent code.
- The Combine framework introduces a common, **high-level language to the Swift ecosystem to design and write asynchronous code**.
- Various system frameworks, from Foundation all the way up to SwiftUI, depend on Combine and offer Combine integrations as an alternative to their more "traditional" APIs.
  - `NotificationCenter`
  - The delegate pattern
  - GCD and Operations
  - Closures

## Swift's Modern Concurrency

- Swift 5.5 introduces a range of APIs for developing asynchronous and concurrent code allows your code to safely and quickly suspend and resume asynchronous work at will.
- But, Combine's strength lays in its rich set of **operators**.
- The operators that Combine offers for processing events over time make a lot of complex, common scenarios easy to address.

## Foundation of Combine

- Combine implements a standard that is different but similar to Rx, called **Reactive Streams**.
- The three key moving pieces in Combine are **publishers, operators, subscribers**.

### Publishers

- Publishers are types that **can emit values over time** to one or more interested parties, such as subscribers.
- Every publisher can emit multiple events of these three types:
  - An output value (`Output` type)
  - A successful completion
  - A completion with an error (`Failure` type)
- A publisher can emit zero or more output values, and **if it ever completes, either successfully or due to a failure, it will not emit any other events**.
- These three events can represent any kind of dynamic data in your program. That's why you can address any task in your app using Combine publishers.
  - crunching numbers
  - making network calls
  - reacting to user gestures
  - displaying data on-screen
- The `Publisher` protocol is generic over two types:
  - `Publisher.Output` : the type of the output values of the publisher
  - `Publisher.Failure` : the type of error the publisher can throw if it fails
    - It will be `Never` type if the publisher can **never fail**.

### Operators

- Operators are method declared on the `Publisher` protocol that **return either the same or a new publisher**.
- They can be chained together.
- The operators are **highly decoupled and composable**, they **can be combined** to implement ver complex logic over the execution of a single subscription.
- They cannot be mistakenly put in the wrong order or fit together if one's output doesn't match the next one's input type.
  - You can define the order with **the correct input/output types and built-in error handlings**.
  - _It can know some mistakes at a compile-time._
- Operators focus on **working with the data they receive from the previous operator** and **provide their output to the next one** in the chain.
- No other asynchronously-running piece of code can "jump in" and change the data you're working on.

### Subscribers

- Every subscription ends witha subscriber.
- Subscribers generally do something with the emitted output or completion events.
- Combine provides two built-in subscribers:
  - The `sink` subscriber : provide closures with your code that will **receive output values and completions**.
  - The `assign` subscriber : **bind the resulting output to some property on your data model or on UI control** to display the data directly on-screen **via a key path**.

### Subscriptions

- When the subscriber is added at the end of a subscription, it **activates the publisher** all the way at the beginning of the chain.
- **Publishers don't emit any values if there are no subscribers** to potentially receive the output.
- Once the subscription code compiles, **the subscriptions will asynchronously fire each time some event**.
- You don't need to specifically memory manage a subscription, thanks to the `Cancellable` protocol provided by Combine.
- Both system-provided subscribers conform to `Cancellable`, which means that **your subscription code returns a `Cancellable` object**.
- Whenever you release that object from memory, **it cancels the whole subscription and releases its resources from memory**.
  - It means you can bind the lifespan of a subscription **by storing it in a property** on your view controller.
  - Anytime the user dismisses the view controller, that will deinitialize its properties and **will also cancel your subscription**.
  - To automate this process, you can just have an **`[AnyCancellable]` collection property** and throw as many subscriptions inside it as you want.

## The benefix of Combine code over "standard" code?

- Using the combine framework is more convenient, safe and efficient.
  - Safety : it's already well tested and a safe-bet technology.
  - Convenience and Efficiency
    - Composition and reusability become extremely powerful.
    - The operators are highly composable.
- Combine aim to add another abstraction on the system level to your async code.

## App architecture

- Combine deals with asynchronous data events and unified communication contract.
- It doesn't alter how you would separate responsibilities in your project.
  - It doesn't affect how you structure your apps.
- You can add Combine code iteratively and selectively, **using it only in the parts you wish** to improve in your codebase.
