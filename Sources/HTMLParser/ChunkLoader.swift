import Foundation

/**
 A utility class that loads data from a URL in chunks.
 
 This class is useful for processing large files or streaming data without loading
 everything into memory at once. It provides an async stream of data chunks as they
 are received from the network.
 */
public final class ChunkLoader: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The URL to load data from
    private let url: URL
    
    /// The URL session to use for loading data
    private let session: URLSession
    
    // MARK: - Initialization
    
    /**
     Creates a new ChunkLoader instance.
     
     - Parameters:
       - url: The URL to load data from
       - session: The URL session to use for loading data (defaults to .shared)
     */
    public init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }
    
    // MARK: - Public Methods
    
    /**
     Loads data from the URL in chunks and returns an async stream of data.
     This version uses URLSession's delegate API to receive data incrementally.
     
     - Returns: An async stream that yields data chunks as they are received
     - Throws: An error if the URL is invalid or if there's a network error
     */
    public func loadChunks() -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            // Create a delegate to handle incremental data
            final class Delegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
                let continuation: AsyncThrowingStream<Data, Error>.Continuation
                
                init(continuation: AsyncThrowingStream<Data, Error>.Continuation) {
                    self.continuation = continuation
                    super.init()
                }
                
                func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
                    continuation.yield(data)
                }
                
                func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
                    if let error = error {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
                
                func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
                    // Check for valid response
                    guard let httpResponse = response as? HTTPURLResponse else {
						
                        continuation.finish(throwing: URLError(.badServerResponse))
                        completionHandler(.cancel)
                        return
                    }
                    
                    // Check for successful status code
                    guard (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: URLError(.badServerResponse))
                        completionHandler(.cancel)
                        return
                    }
                    
                    // Continue with the request
                    completionHandler(.allow)
                }
            }
            
            // Create a delegate
            let delegate = Delegate(continuation: continuation)
            
            // Create a session with the delegate
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            
            // Create a data task
            let task = session.dataTask(with: url)
            
            // Start the task
            task.resume()
            
            // Set up cancellation
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
} 
