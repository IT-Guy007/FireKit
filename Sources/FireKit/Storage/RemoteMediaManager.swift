//
//  RemoteMediaManager.swift
//  
//
//  Created by Jeroen den Otter on 6/20/24.
//

import FirebaseCrashlytics
import FirebaseStorage
import Kingfisher
import OSLog
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A class encapsulating all the logic required for using ``FireImage``
public class RemoteMediaManager {
    
    /// The logger of the class
    private let logger = Logger(subsystem: "com.jeroendenotter.FireKit", category: "Firebase")
    
    private let cacheDirectory: URL
    
    private var notExisting: [String] = []
    
    init() {
        self.cacheDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("images")
        
        createImagesFolderIfNeeded()
    }
    
    /// Generates the required url for downloading from Firebase storage
    /// - Parameters:
    ///   - id: Name of media
    ///   - folder: Folder in which the media is stored in the bucket
    ///   - completion: Optional url, might not exist on server
    internal func generateURL(
        id: String,
        path: String,
        completion: @escaping (_ downloadURL: URL?) -> Void)
    {
        if let url = retrieveURLFromDisk(key: id) {
            completion(url)
        } else {
            generateURLFromServer(id: id, path: path, completion: completion)
        }
    }
    
    /// Returns an in image based on the id
    /// - Parameters:
    ///   - id: The id on which it was stored
    ///   - completion: Optional NSImage value
    public func retrieveMedia(
        id: String,
        completion: @escaping (_ image: NSImage?) -> Void)
    {
        ImageCache.default.retrieveImage(forKey: id, options: nil) { result in
            switch result {
            case .success(let value):
                if let image = value.image {
                    completion(image)
                } else {
                    completion(nil)
                }
            case .failure(let error):
#if DEBUG
                self.logger.error("Error retrieving image from cache")
                self.logger.debug("\(error, privacy: .public)")
#else
                Crashlytics.crashlytics().log("Error retrieving image from cache")
                Crashlytics.crashlytics().record(error: error)
#endif
                completion(nil)
            }
        }
    }
    
    private func generateURLFromServer(
        id: String,
        path: String,
        completion: @escaping (_ downloadURL: URL?) -> Void)
    {
        guard !notExisting.contains(id) else { completion(nil); return}
        
        let storageRef = Storage.storage().reference()
        let ref = storageRef.child(path)
        
        ref.downloadURL { fetchedURL, error in
            if let error = error {
                // Check if the image just doesnt exist
                if error.localizedDescription.contains("does not exist") {
#if DEBUG
                    self.logger.error("Can't retrieve media, doesn't exist on server: \(ref.fullPath, privacy: .public)")
#endif
                    self.notExisting.append(id)
                } else {
#if DEBUG
                    self.logger.error("Error generating downloadable URL")
                    self.logger.debug("\(error)")
#else
                    Crashlytics.crashlytics().log("Error generating downloadable URL")
                    Crashlytics.crashlytics().record(error: error)
#endif
                }
            } else {
                if let url = fetchedURL {
                    self.storeURLToDisk(url: url, key: id)
                }
            }
            completion(fetchedURL)
        }
    }
    
    private func storeURLToDisk(
        url: URL,
        key: String)
    {
        let cachedURL = cacheDirectory.appendingPathComponent("\(key).url")
        do {
            try url.absoluteString.write(to: cachedURL, atomically: true, encoding: .utf8)
        } catch {
#if DEBUG
            self.logger.error("Error caching url")
            self.logger.debug("\(error, privacy: .public)")
#else
            Crashlytics.crashlytics().log("Error caching url")
            Crashlytics.crashlytics().record(error: error)
#endif
        }
    }
    
    private func retrieveURLFromDisk(
        key: String) -> URL?
    {
        let cachedURL = cacheDirectory.appendingPathComponent("\(key).url")
        if FileManager.default.fileExists(atPath: cachedURL.path),
           let urlString = try? String(contentsOf: cachedURL, encoding: .utf8) {
            return URL(string: urlString)
        }
        return nil
    }
    
    private func createImagesFolderIfNeeded() {
        guard !FileManager.default.fileExists(atPath: cacheDirectory.path()) else { return }
        
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
#if DEBUG
            self.logger.error("Error creating image folder")
            self.logger.debug("\(error, privacy: .public)")
#else
            Crashlytics.crashlytics().log("Error creating image folder on disk")
            Crashlytics.crashlytics().record(error: error)
#endif
        }
    }
    
    /// Removes a specific cached URL by key
    public func removeCachedURL(
        forKey key: String)
    {
        let cachedURL = cacheDirectory.appendingPathComponent("\(key).url")
        do {
            if FileManager.default.fileExists(atPath: cachedURL.path) {
                try FileManager.default.removeItem(at: cachedURL)
            } else {
#if DEBUG
                self.logger.error("No cached URL found for key \(key)")
#endif
            }
            if let index = self.notExisting.firstIndex(of: key) {
                self.notExisting.remove(at: index)
            }
        } catch {
#if DEBUG
            self.logger.error("Error removing cached url for key \(key)")
            self.logger.debug("\(error, privacy: .public)")
#else
            Crashlytics.crashlytics().log("Error removing cached url for key \(key)")
            Crashlytics.crashlytics().record(error: error)
#endif
        }
    }
    
    /// Clears all cached URL's stored
    public func clearAllCachedURLs() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles])
            for fileURL in contents {
                try FileManager.default.removeItem(at: fileURL)
            }
            self.notExisting = []
        } catch {
#if DEBUG
            self.logger.error("Error clearing cached url's")
            self.logger.debug("\(error, privacy: .public)")
#else
            Crashlytics.crashlytics().log("Error clearing cached ur'sl")
            Crashlytics.crashlytics().record(error: error)
#endif
        }
    }
    
    /// Uploads an image to a firebase.
    ///
    /// - Parameters:
    /// - image: The UIImage object to be uploaded.
    /// - imageName: The name of the image file.
    /// - imageFolder: The folder in the remote storage where the image will be uploaded.
    /// - completion: A closure that is called when the upload operation is complete. It takes a boolean parameter indicating whether the upload was successful or not.
    public func uploadImage(
        image: CIImage,
        imageName: String,
        imageFolder: String,
        completion: ((Bool) -> Void)?)
    {
#if DEBUG
        logger.info("Uploading image \(imageName, privacy: .private) to Firebase")
#else
        Crashlytics.crashlytics().log("Uploading image to Firebase")
#endif
        let storage = Storage.storage()
        let storageReference = storage.reference().child("\(imageFolder)/\(imageName).png")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let context = CIContext()
        guard let imageData = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 1.0]) else {
#if DEBUG
            self.logger.error("Failed to create JPEG data from CIImage")
#else
            Crashlytics.crashlytics().log("Failed to create JPEG data from CIImage")
#endif
            completion?(false)
            return
        }
        
        let uploadTask = storageReference.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
#if DEBUG
                self.logger.error("Error uploading photo")
                self.logger.debug("\(error)")
#else
                Crashlytics.crashlytics().log("Error uploading photo")
                Crashlytics.crashlytics().record(error: error)
#endif
                return
            }
        }
        uploadTask.observe(.success) { _ in
#if DEBUG
            self.logger.info("Successfull uploaded the image \(imageName, privacy: .private)")
#else
            Crashlytics.crashlytics().log("Successfull")
#endif
            completion?(true)
        }
        uploadTask.observe(.failure) { error in
#if DEBUG
            self.logger.error("Error uploading image to Firebase \(imageName, privacy: .private)")
            self.logger.debug("\(error)")
#else
            Crashlytics.crashlytics().log("Error uploading image to Firebase")
            if let error = error.error {
                Crashlytics.crashlytics().record(error: error)
            }
#endif
            
            completion?(false)
        }
    }
    
}


/// Simple async image view with placeholder
///
/// Example:
/// ```swift
/// FireImage(id: "123456789", path: "User/123456789.png") {
///    Image("PersonPlaceHolder")
///     .resizable() // Important to add
/// }
/// ```
public struct FireImage: View {
    
    @State private var url: URL?
    
    private let id: String
    
    /// The id of the media
    private let path: String
    
    /// The placeholder view for when the view is loading
    private let placeholder: () -> any View
    
    init(id: String, path: String, placeholder: @escaping () -> any View) {
        self.id = id
        self.path = path
        self.placeholder = placeholder
    }
    
    public var body: some View {
        KFImage
            .url(url, cacheKey: id)
            .diskCacheExpiration(.days(14))
            .resizable()
            .fade(duration: 0.25)
            .placeholder {
                AnyView(placeholder())
            }
            .task {
                RemoteMediaManager().generateURL(id: id, path: path) { downloadURL in
                    url = downloadURL
                }
            }
    }
}
