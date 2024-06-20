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

/// A class representing a listener with its logic for a query of documents from Firestore
///
///```swift
///class ContentStore: ObservableObject {
///
///    @Published var notJohns: FirestoreArrayListener<User>
///
///    init() {
///        let query = Firestore.firestore()
///            .collection("User")
///            .whereField("firstName", isNotEqualTo: "John")
///
///        self.notJohns = FirestoreArrayListener(query: query)
///        self.notJohns.start()
///
///        // Or
///
///        self.notJohns = FirestoreArrayListener(ref: query) {
///            // Some extra action
///        }
///        notJohns.start()
///    }
///}
///```
///
///### Accessing the status
///The status of the listener for loading purposes is stored in AppStorage, accessing it can be as simply as:
///```swift
///@AppStorage("listeners") var listenersStatusData = Data()
///let status = try? JSONDecoder().decode([String: Bool].self, from: listenersStatusData)
///```
public class FirestoreArrayListener<T>: FirestoreListener where T: FirestoreEntity {
    
    /// The logger of the class
    private let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
    
    /// The registraion of the listener
    private var registration: ListenerRegistration?
    
    /// The query used for this instance
    let query: Query
    
    /// Bool indicating if the first retrieval is done
    @Published public var active = false
    
    /// The objects that is being listened to
    @Published public var storage: [T] = []
    
    /// Listener associated with this instance
    public let listenerName: String
    
    /// Action needed to be taken whenever the handler is called
    public var updateAction: (() -> Void)?
    
    /// Upstream subscription
    public var subscription = Set<AnyCancellable>()
    
    init(query: Query, update: (() -> Void)? = nil) {
        self.query = query
        self.updateAction = update
        
        let typeName = String(describing: T.self).components(separatedBy: ".").last ?? "Unknown"
        self.listenerName = "Listener-\(typeName)-\(Int.random(in: 100...900))"
    }
    
    deinit {
        if !active {
            updateAction = nil
            stop()
            updateListenerStatus(active: nil)
        }
        subscription.first?.cancel()
    }
    /// Starts the listener
    public func start() {
        guard !active && query != Firestore.firestore().collection(" ") else {
#if DEBUG
            logger.info("\(self.listenerName, privacy: .public) has been called to start, but is already active")
#else
            Crashlytics.crashlytics().log("\(self.listenerName) has been called to start, but is already active")
#endif
            return
        }
        updateListenerStatus(active: false)
        
        self.registration = query.addSnapshotListener({ snapshot, error in
            if let error = error {
#if DEBUG
                self.logger.error("\(self.listenerName, privacy: .public) has thrown an error")
                self.logger.fault("\(error, privacy: .public)")
#else
                Crashlytics.crashlytics().log("\(self.listenerName) has thrown an error")
                Crashlytics.crashlytics().record(error: error)
#endif
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
    
    public func stop() {
        self.active = false
        if let registration = registration {
            registration.remove()
#if DEBUG
            logger.debug("Stopping: \(self.listenerName)")
#endif
        } else {
            if query != Firestore.firestore().collection(" ") {
#if DEBUG
                logger.error("\(self.listenerName, privacy: .public) has been called to stop, but isn't active")
#else
                Crashlytics.crashlytics().log("\(self.listenerName) has been called to stop, but isn't active")
#endif
            }
        }
    }
    
    private func handleSnapshot(snapshot: QuerySnapshot) {
        snapshot.documentChanges.forEach { documentChange in
            do {
                switch documentChange.type {
                case .added:
                    try handleDocumentAdded(document: documentChange.document)
                case .modified:
                    try handleDocumentModified(document: documentChange.document)
                case .removed:
                    try handleDocumentRemoved(document: documentChange.document)
                }
            } catch let error {
#if DEBUG
                logger.error("\(self.listenerName, privacy: .public) has thrown an error")
                logger.debug("\(error, privacy: .public)")
#else
                Crashlytics.crashlytics().log("\(listenerName) has thrown an error")
                Crashlytics.crashlytics().record(error: error)
#endif
                return
            }
        }
#if DEBUG
        logger.debug("\(self.listenerName): Successfully updated")
#endif
    }
    
    private func handleDocumentAdded(document: QueryDocumentSnapshot) throws {
        let data = try document.data(as: T.self)
        storage.append(data)
    }
    
    private func handleDocumentModified(document: QueryDocumentSnapshot) throws {
        guard let index = storage.getIndex(ref: document.reference) else {
            throw FirestoreErrorCode(.notFound)
        }
        
        let newData = try document.data(as: T.self)
        storage[index] = newData
    }
    
    private func handleDocumentRemoved(document: QueryDocumentSnapshot) throws {
        guard let index = storage.getIndex(ref: document.reference) else {
            throw FirestoreErrorCode(.notFound)
        }
        
        storage.remove(at: index)
    }
}
