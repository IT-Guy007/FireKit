//
//  FirestoreListener.swift
//
//
//  Created by Jeroen den Otter on 6/20/24.
//

import Combine
import Foundation
import OSLog
import SwiftUI

/// A protocol that represents a listener for Firestore updates
///
///
internal protocol FirestoreListener: ObservableObject {
    
    /// A flag indicating whether the listener is currently active
    var active: Bool { get set }
    
    /// The name of the listener, dynamically created
    var listenerName: String { get }
    
    /// A closure that defines the action to take when an update is received.
    ///
    /// This optional closure is called whenever Firestore sends an update that
    /// the listener is subscribed to. Implementations should define what
    /// actions to perform, such as updating the UI or extra processing steps.
    var updateAction: (() -> Void)? { get set }
    
    /// A set of cancellable subscriptions.
    ///
    /// Used for storing the subscription of the current listener and updating the `ObservableObject`
    var subscription: Set<AnyCancellable> { get set }
    
    /// Starts the Firestore listener.
    func start()
    
    /// Stops the Firestore listener.
    func stop()
}

extension FirestoreListener {
    
    internal func updateListenerStatus(active: Bool?) {
        @AppStorage("listeners") var listenerStatus = Data()
        var listenerStatuses: [String: Bool] = [:]
        
        do {
            listenerStatuses = try JSONDecoder().decode([String: Bool].self, from: listenerStatus)
        } catch {
            guard !error.localizedDescription.contains("Unexpected end of file") else { return }
    #if DEBUG
            let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
            logger.error("Error decoding listener statuses")
            logger.debug("\(error)")
    #else
            Crashlytics.crashlytics().log("Error decoding listener statuses")
            Crashlytics.crashlytics().record(error: error)
    #endif
        }
        
        if let isActive = active {
            listenerStatuses[listenerName] = isActive
        } else {
            listenerStatuses.removeValue(forKey: listenerName)
        }
        
        do {
            let encodedData = try JSONEncoder().encode(listenerStatuses)
            listenerStatus = encodedData
        } catch {
    #if DEBUG
            let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
            logger.debug("Error encoding listener statuses")
            logger.debug("\(error)")
    #else
            Crashlytics.crashlytics().log("Error encoding listener statuses")
            Crashlytics.crashlytics().record(error: error)
    #endif
        }
    }
    
     internal func reportError(error: Error) {
#if DEBUG
        let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
        logger.error("\(self.listenerName, privacy: .public) has thrown an error")
        logger.fault("\(error, privacy: .public)")
#else
        Crashlytics.crashlytics().log("\(listenerName) has thrown an error")
        Crashlytics.crashlytics().record(error: error)
#endif
    }
}
