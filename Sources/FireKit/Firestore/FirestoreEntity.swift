//
//  FirestoreEntity.swift
//  
//
//  Created by Jeroen den Otter on 6/20/24.
//

import Foundation
import FirebaseFirestore
import FirebaseCrashlytics
import OSLog


/// A protocol that represents an entity stored in Firestore.
///
/// To implement an Firestore listener class from this package, the model needs to be comforming to this protocol.
///
/// For example an user object
/// ```swift
/// struct User: FireforeEntity {
///
///     var id: String {
///         documentRef?.documentID ?? UUID().uuidString
///     }
///
///     @DocumentID var documentRef: DocumentReference?
///
///     var firstName: String
///
///     var lastName: String
///
///     enum CodingKeys: String, CodingKey {
///         case documentRef
///         case firstName = "firstname"
///         case lastname = "lastname"
///     }
///
///     func hash(into hasher: inout Hasher) {
///         hasher.combine(id)
///     }
///
///     static func == (lhs: User, rhs: User) -> Bool {
///         return lhs.hashValue == rhs.hashValue
///     }
///  }
/// ```
public protocol FirestoreEntity: Identifiable, Hashable, Codable {
    
    /// Reference to the documentID
    var id: String { get }
    
    /// Reference to the document in Firestore
    var documentRef: DocumentReference? { get }
}

extension FirestoreEntity {
    
    /// Encodes an instance of Encodable and overwrites the encoded data to the document referred by this object.
    ///
    /// If no document exists, it is created. If a document already exists, it is overwritten.
    func updateObjectInFirestore() throws {
        guard let documentRef = documentRef else {
#if DEBUG
            let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
            logger.error("Error updating object in Firestore: documentRef is nil")
#else
            Crashlytics.crashlytics().log("Error updating object in Firestore: documentRef is nil")
#endif
            return
        }
        
        try documentRef.setData(from: self, merge: true)
    }
    
    /// Updates the local object from Firestore
    func updateObjectFromFirestoreServer() async throws -> Self? {
        guard let documentRef = documentRef else {
#if DEBUG
            let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
            logger.error("Error updating object in Firestore: documentRef is nil")
#else
            Crashlytics.crashlytics().log("Error updating object in Firestore: documentRef is nil")
#endif
            return nil
        }
        
#if DEBUG
        let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
        let id = self.id
        logger.notice("Retrieving \(id) from Firestore server")
#endif
        return try await documentRef.getDocument(as: Self.self, decoder: Firestore.Decoder())
    }
    
    /// Updates the local object from Firestore, prioritizing cache
    func updateObjectFromFirestoreCacheFirst() async throws -> Self? {
        // Attempt to fetch object from cache
        if let object = try? await getObjectFromCache() {
            return object
        }
        
        // If cache retrieval fails, fetch from Firestore
        return try await updateObjectFromFirestoreServer()
    }
    
    /// Removes the object from Firestore
    func removeObjectFromFirestore() throws {
        guard let documentRef = documentRef else {
#if DEBUG
            let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
            logger.error("Error deleting object in Firestore: documentRef is nil")
#else
            Crashlytics.crashlytics().log("Error deleting object in Firestore: documentRef is nil")
#endif
            return
        }
        documentRef.delete()
    }
    
    private func getObjectFromCache() async throws -> Self? {
        guard let documentRef = documentRef else {
#if DEBUG
            let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
            logger.error("Error updating object in Firestore: documentRef is nil")
#else
            Crashlytics.crashlytics().log("Error updating object in Firestore: documentRef is nil")
#endif
            return nil
        }
        
        return try await documentRef.getDocument(source: .cache).data(as: Self.self, decoder: .init())
    }
}

extension Array where Element: FirestoreEntity {
    
    /// Returns the element that has the reference attached to it
    func getElement(ref: DocumentReference) -> Element? {
        return self.first(where: {$0.documentRef == ref})
    }
    
    /// Returns the index of the element
    func getIndex(ref: DocumentReference) -> Int? {
        return self.firstIndex(where: {$0.documentRef == ref})
    }
    
    /// Replaces the current array with the given query executed
    mutating func getObjectsFromFirestore(query: Query) async throws {
        let data = try await query.getDocuments()
        
        var result: [Element] = []
        data.documents.forEach { snapshot in
            do {
                result.append(try snapshot.data(as: Element.self))
            } catch let error {
#if DEBUG
                DispatchQueue.main.async {
                    let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
                    logger.error("Error converting document to: \(Element.Type.self)")
                    logger.debug("\(error)")
                }
#else
                Crashlytics.crashlytics().log("Error converting document to: \(Element.Type.self)")
                Crashlytics.crashlytics().record(error: error)
#endif
            }
        }
        self = result
    }
}
