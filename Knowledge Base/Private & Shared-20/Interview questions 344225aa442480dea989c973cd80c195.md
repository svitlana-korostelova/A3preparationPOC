# Interview questions

1. Imagine you have DataBase. Where would you store images ? How would you do cache?  (store name of images)
2. What is technical debt in general?
3. How effectively manage technical debt?
4. What are some best practices for improving code quality?
5. T-shirt sizing, Planning Poker, and Fibonacci-based story points
6. Could you describe a specific situation where your team had to drop or modify a Scrum ceremony or practice to meet delivery pressure? When you need to save some time for the team to meet the deadline, which ceremony would you drop or change?
7. Have you worked with biometric authentication?
8. How you done performance testing?
9. Imagine you want to have regular checkout, checkout in one click, guest(anounimus) checkout. How would you organize storing data in between steps?
10. Do you know what is binary tree? How did you use it?
11. How would you organize multi-targeting in app or white-labeling app
12. You're asked to estimate and plan a new module consisting of 4-5 screens with backend integration, data persistence, and unit test coverage. This work will span 2-3 sprints and involve 2-3 developers. Could you walk me through your planning approach step-by-step?
13. Can the compiler decides to use static dispatch for a class that has no children based on code analysis? If not, then why?
14. How does using the "final" keyword affect method dispatch in Swift?
15. Why is choosing the right data structure important in Swift?
16. Could you describe your approach to managing data flow and state synchronization between UIKit and SwiftUI components in your project?
17. How to avoid race conditions and deadlocks. Could you describe how to achieve this?
18. Could the use of locks, semaphores, and other stuff lead to bigger problems? Which approach in concurrency do you like the most or use more often?
19. What are actors in swift, and why are they useful?
20. What is the difference between Task and detached Task?
21. Walk me through a real scenario where you discovered a specific code smell in your project's codebase that was being repeatedly introduced by the team. How did you address it systematically?
22. Imagine you join a new team where code reviews are inconsistent—some PRs get approved with obvious issues, while others are blocked for minor style preferences. The CI/CD pipeline has no automated quality checks. As a Senior developer, how would you establish a systematic code review culture and supporting automation over the next 2-3 sprints?
23. What is copy-on-write?
24. When/why we should use isKnownUniquelyReferenced(_:) function?
25. Which components did you cover with unit tests versus UI tests, and why did you make that decision for each?
26. SwiftUI views are often hard to unit test directly. Did you decompose any views to make parts unit-testable? If yes, describe the approach (e.g., extracting localizers, stylers, business logic).
27. When would you still choose UIKit over SwiftUI in 2026?
    - libraries
28. Explain off-screen rendering and how it affects performance.
29. What is Metal and when would you use it over Core Animation?
30. What is crash-free rate? how to measure?
31. How to optimize memory footprint? How to reduce resource consumption?
32. What do you prefer escaping or non-escaping closure and why? escaping - capture self
33. Do we need equitable protocol  if enum with associated value?
34.  **How would you implement deep linking in a SwiftUI app?**
35. How you retrieve access token and refresh token, what do you do if expired?

- From Ira
    
    **Memory management**
    
    Method dispatch
    
    Core Data
    
    SwiftUI
    
    what is a View - protocol
    
    hidden
    
    some vs any
    
    [some View] = Text, Icon, List -
    
    [AnyView] = [Text, Text] -
    
    ![image.png](Interview%20questions/image.png)
    
    - Use **`[AnyView]`** for an array of mixed views.
    - **`[some View]`** cannot be used as an array element type.
    
    Architecture
    
    MVVM vs MVP - same, but VMMV but VC has VM and bindings, VM does not have VC. In MVP has 2-sided connection, presenter has VC
    
    Patterns - which did you use
    
    builder vs factory - swiftui
    
    builder builds inside, UIKit -
    
    SUI encapsulated
    
    singleton anti pattern - if used not correctly
    
    thread safe mechanisms - dispatch queue, operation(надбудова над GCD), swift concurrency
    
    semaphors - not mention, is not mechanism
    
    actor - main thread, thread-safe.like class but does not have inheritance
    
    how to make your own thread-safe - Sendable
    
    structs - no need to add sth, is thread-safe, stored in stack
    
    thread-safe class should be sendable, all properties …… *sth else
    
    if sendable does not work
    
    custom serial queue -
    
    **Collections** - array, set, dictionary
    
    why key hashable - because it has hash table, array under the hood
    
    array has 1st element address and size
    
    but dictionary - like array but instead of index you have hash
    
    collision resolving
    
    **big o** notation
    
    get the most effective - array, just index
    
    get vs find - get by index, find by hash
    
    array - if sorted then find logN - if not sorted N
    
    add - is difficult
    
    Where to store logs - many values which are being added - List - each next element has link to next one
    
    Optimisation
    
    COW - applied to structures(but not custom ones)
    
    **CI/CD**
    
    - push code, merge - CI
    - create release - upload to app store - CD
    
    **provisioning profile**
    
    includes certificate so that app store knows the developer
    
    entitlements - payments, push etc
    
    list of devices for testing - in profile. UUID
    
    Test Flight
    
    is free
    
    in apple developer
    
    **REST - stateless**
    
    each request includes all data
    
    new request is self-contained
    
    What is REST???
    
    1 endpoint with different methods does different things
    
    **Background processing** - must have!!!
    
    Examples: location update, music, fetch data
    
    **Tests**
    
    need to check all test and edge cases
    
    up to 80%
    
    without tests you need to do regression after each
    
    what are snapshots -
    
    UI tests - to revise
    
    Integration
    
    Mock - Stub - Fake - Spy - difference
    
    **Last interview**
    
    ❗️Sendable
    
    Collections
    
    AI - how do you use, what you think
    
    Copilot or Claude - try to implement own CI
    
    Claude Code - pro
    
    **Soft skills**
    
    scrum kanban!!!
    
    scrum ceremonies - required and optional. in scrum all ceremonies are required
    
    scrum - methodology
    
    kanban - board, has ticket limitation
    
    scrum ban
    
    scrumbat - scrum BUT
    
    scrum metrics - velocity etc
    
    estimations
    
    estimate is absolute. task is 3 task: risk, complexity and size
    
    technichs - positive, negative and realistic - formula
    
    spike -
    
    time management - priorities
    
    TM technichs - pomodoro
    
    eat that frog
    
    conflict resolution - is not bad,
    
    different opinions, how to choose one
    
    what if client does not know technical details but wants some feature, what to do
    
    clue: discussion !
    
    different views
    
    3rd person - mediator, referee, so that
    
    if not helps - escalate
    
    important to document conflicts
    
    delegation vs assignment - in delegation you’re responsible, in assignment - other person is
    
    _
    
    if you don’t know - tell at least sth
    

# **Interview Questions — Navigation State Restoration (Senior iOS / SwiftUI)**

## **Conceptual Understanding**

1. Why does **`NavigationPath`** not expose its contents directly, and how does that impact your state restoration strategy?
2. What is the difference between **`@SceneStorage`** and **`UserDefaults`** for persisting navigation state, and when would you choose one over the other?
3. Why must navigation destination types conform to both **`Hashable`** and **`Codable`**, and what breaks if they don't?
4. What are the tradeoffs between using **`NavigationPath`** vs a typed array **`[AppDestination]`** as your navigation state?

---

## **Problem Solving**

1. A user drills 5 levels deep, backgrounds the app, iOS kills it due to memory pressure, and relaunches — walk me through exactly how you'd restore their position.
2. Your app ships an update that renames a navigation destination type. How do you prevent restored state from crashing on launch?
3. How would you handle state restoration when your navigation stack contains a mix of types, some of which are not **`Codable`**?
4. You have a **`NavigationSplitView`** with a **`NavigationStack`** inside the detail column. What state do you need to persist, and how does that differ from a standalone **`NavigationStack`**?

---

## **Architecture**

1. How would you design a **`Router`** object to centralize navigation state across a large app, and how would persistence fit into that design?
2. How does state restoration interact with deep linking — if the app receives a deep link while restoring saved state, how do you resolve the conflict?
3. Where in the SwiftUI lifecycle (**`.task`**, **`.onAppear`**, scene phase changes) do you trigger save and restore, and why does the choice matter?

---

## **Edge Cases & Senior-Level Traps**

1. **`path.codable`** returns **`nil`** at runtime even though all your types conform to **`Codable`** — what are the possible causes?
2. A user has two windows open on iPad, each with different navigation state — how does your persistence layer handle that without them overwriting each other?
3. How would you write a unit test to verify that your navigation path survives a full encode → decode round trip?
4. State restoration works perfectly in development but silently fails in production for some users — what would you investigate first?