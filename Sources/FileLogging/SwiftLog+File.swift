import Logging
import Foundation

// Adapted from https://nshipster.com/textoutputstream/
struct FileHandlerOutputStream: TextOutputStream {
    enum FileHandlerOutputStream: Error {
        case couldNotCreateFile
    }
    
    private let fileHandle: FileHandle
    let encoding: String.Encoding

    init(localFile url: URL, encoding: String.Encoding = .utf8) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
                throw FileHandlerOutputStream.couldNotCreateFile
            }
        }
        
        let fileHandle = try FileHandle(forWritingTo: url)
        fileHandle.seekToEndOfFile()
        self.fileHandle = fileHandle
        self.encoding = encoding
    }

    mutating func write(_ string: String) {
        if let data = string.data(using: encoding) {
            fileHandle.write(data)
        }
    }
}

public struct FileLogging {
    let stream: TextOutputStream
    private var localFile: URL
    
    public init(to localFile: URL) throws {
        self.stream = try FileHandlerOutputStream(localFile: localFile)
        self.localFile = localFile
    }
    
    public func handler(label: String) -> FileLogHandler {
        return FileLogHandler(label: label, fileLogger: self)
    }
    
    public static func logger(label: String, localFile url: URL) throws -> Logger {
        let logging = try FileLogging(to: url)
        return Logger(label: label, factory: logging.handler)
    }
}

// Adapted from https://github.com/apple/swift-log.git
        
/// `FileLogHandler` is a simple implementation of `LogHandler` for directing
/// `Logger` output to a local file. Appends log output to this file, even across constructor calls.
public class FileLogHandler: LogHandler {
    
    public var logLevel: Logger.Level = .info
    
    public var metadata = Logger.Metadata() {
        didSet { prettyMetadata = prettify(metadata) }
    }
    
    private var stream: TextOutputStream
    private var label: String
    private var prettyMetadata: String?
    
    public init(label: String, fileLogger: FileLogging) {
        self.label = label
        self.stream = fileLogger.stream
    }

    public init(label: String, localFile url: URL) throws {
        self.label = label
        self.stream = try FileHandlerOutputStream(localFile: url)
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        
        var mergeMeta: String = prettyMetadata ?? ""
        if let loggedMeta = metadata, !loggedMeta.isEmpty {
            mergeMeta = prettify(self.metadata.copiedMerge(of: loggedMeta))
        }
        
        stream.write("[ \(timestamp()) ] [ \(level) ] [ \(label) ] | \(mergeMeta) | \(message)\n")
    }
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }

    private func prettify(_ metadata: Logger.Metadata) -> String {
        metadata.map { "\($0)=\($1)" }.joined(separator: " ")
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        var timestamp = time(nil)
        let localTime = localtime(&timestamp)
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}

extension Dictionary {
    func copiedMerge(of target: Self) -> Self {
        merging(target, uniquingKeysWith: { _, targetValue in targetValue } )
    }
}
