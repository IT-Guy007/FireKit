//
//  File.swift
//  
//
//  Created by Jeroen den Otter on 6/20/24.
//

import Combine
import FirebaseCrashlytics
import FirebaseFirestore
import Foundation
import OSLog

/// A class representing a listener to a specific query of documents
///
/// Listenening to a single object is as simple as 3 lines of code.
/// ```swift
///class ContentStore: ObservableObject {
///
///    @Published var currentUser: FirestoreObjectListener<User>
///
///    init() {
///        let ref = Firestore.firestore()
///            .collection("User").document("1234567890")
///
///        currentUser = FirestoreObjectListener(ref: ref, defaultValue: User())
///        currentUser.start()
///
///        // Or
///
///        currentUser = FirestoreObjectListener(ref: ref, defaultValue: User()) {
///             // Some extra action, for example authenticaton or image retrieval
///         }
///         currentUser.start()
///     }
///}
///```
///### Accessing the status
///The status of the listener for loading purposes is stored in AppStorage, accessing it can be as simply as:
///```swift
///@AppStorage("listeners") var listenersStatusData = Data()
///let status = try? JSONDecoder().decode([String: Bool].self, from: listenersStatusData)
///```
public class FirestoreObjectListener<T>: FirestoreListener where T: FirestoreEntity {
    
    /// The logger of the class
    private let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
    
    /// The registraion of the listener
    private var registration: ListenerRegistration?
    
    /// The document to listen to
    private (set) var documentRef: DocumentReference
    
    /// Bool indicating if the first retrieval is done
    @Published public var active = false
    
    /// The objects that is being listened to
    @Published var storage: T
    
    /// Listener associated with this instance
    public let listenerName: String
    
    /// Action needed to be taken whenever the handler is called
    public var updateAction: (() -> Void)?
    
    /// Upstream subscription
    public var subscription = Set<AnyCancellable>()
    
    init(ref: DocumentReference, defaultValue: T, update: (() -> Void)? = nil) {
        self.documentRef = ref
        self.storage = defaultValue
        self.updateAction = update
        
        let typeName = String(describing: T.self).components(separatedBy: ".").last ?? "Unknown"
        self.listenerName = "Listener-\(typeName)-\(Int.random(in: 100...900))"
    }
    
    deinit {
        if !active {
            updateAction = nil
            stop()
        }
        updateListenerStatus(active: nil)
        subscription.first?.cancel()
    }
    
    /// Starts the listener
    public func start() {
        guard !active && documentRef != Firestore.firestore().collection(" ").document("empty") else {
#if DEBUG
            logger.info("\(self.listenerName, privacy: .public) has been called to start, but is already active")
#else
            Crashlytics.crashlytics().log("\(self.listenerName) has been called to start, but is already active")
#endif
            return
        }
        updateListenerStatus(active: false)
        
        self.registration = documentRef.addSnapshotListener({ snapshot, error in
            if let error = error {
                self.reportError(error: error)
            }
            if let snapshot = snapshot {
                self.handleSnapshot(snapshot: snapshot)
            }
            if let updateAction = self.updateAction {
                updateAction()
            }
            self.updateListenerStatus(active: true)
        })
    }
    
    /// Stops the listener
    public func stop() {
        self.active = false
        if let registration = registration {
            registration.remove()
#if DEBUG
        logger.debug("Stopping: \(self.listenerName)")
#endif
        } else {
#if DEBUG
            logger.error("\(self.listenerName, privacy: .public) has been called to stop, but isn't active")
#else
            Crashlytics.crashlytics().log("\(self.listenerName) has been called to stop, but isn't active")
#endif
        }
    }
    
    private func handleSnapshot(snapshot: DocumentSnapshot) {
        do {
            self.storage = try snapshot.data(as: T.self)
#if DEBUG
            logger.debug("\(self.listenerName, privacy: .public): Successfully updated")
#endif
        } catch let error {
#if DEBUG
            logger.error("\(self.listenerName, privacy: .public) was called but the data retrieved was invalid")
            logger.debug("\(error)")
#else
            Crashlytics.crashlytics().log("\(self.listenerName) was called but the data retrieved was invalid")
            Crashlytics.crashlytics().record(error: error)
#endif
        }
        self.objectWillChange.send()
    }
}
