# Firestore
Encapsulation of data retieval

## Overview

Using Firestore to store data is an easy and powerful way, but as an app grows so does the amount of queries and variables. Structuring this is therefore essential.

A lot of the logic for retrieval of a single or group of documents is the same, this is the same for the data that is stored in each document. Therefore is the protocol ``FirestoreEntity`` created. 

### Object listener
Listenening to a single object is as simple as 3 lines of code.
```swift
class ContentStore: ObservableObject {

    @Published var currentUser: FirestoreObjectListener<User>

    init() {
        let ref = Firestore.firestore()
            .collection("User").document("1234567890")

        self.currentUser = FirestoreObjectListener(ref: ref, defaultValue: User())
        self.currentUser.start()

        // Or

        self.currentUser = FirestoreObjectListener(ref: ref, defaultValue: User()) {
            // Some extra action
        }
        self.currentUser.start()
    }
}
```

### Array listener
The code for listening to a query is almost exactly the same
```swift
class ContentStore: ObservableObject {

    @Published var notJohns: FirestoreArrayListener<User>

    init() {
        let query = Firestore.firestore()
            .collection("User")
            .whereField("firstName", isNotEqualTo: "John")

        self.notJohns = FirestoreArrayListener(query: query)
        self.notJohns.start()

        // Or

        self.notJohns = FirestoreArrayListener(ref: query) {
            // Some extra action
        }
        notJohns.start()
    }
}
```

### Accessing the status
The status of the listener for loading purposes is stored in AppStorage, accessing it can be as simply as:
```swift
@AppStorage("listeners") var listenersStatusData = Data()
let status = try? JSONDecoder().decode([String: Bool].self, from: listenersStatusData)
```
