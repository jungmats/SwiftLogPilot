import Foundation
import Compression
import ZIPFoundation

// A class responsible for logging messages to a file, with support for log rotation and archiving.
public class FileLogger {
    // Name of the log file.
    let logFileName: String
    // Maximum size (in bytes) of the log file before rotation occurs.
    let maxFileSize: UInt64
    // Maximum number of archived log files to retain.
    let maxArchivedLogs: Int
    // URL of the current log file.
    let targetPath: URL
    // Counter used to generate unique names for archived log files.
    var logCounter = 0
    
    var debugMode: Bool = false
            
    // Initializes the FileLogger with optional parameters for the target path, log file name, max file size, and max archived logs.
    public init(targetPath: URL? = nil, logFileName: String = "app_log", maxFileSize: UInt64 = 512 * 1024, maxArchivedLogs: Int = 3, debugMode: Bool = false) {
        self.debugMode = debugMode
        self.maxFileSize = maxFileSize
        self.maxArchivedLogs = maxArchivedLogs
        self.logFileName = logFileName
        // If no target path is provided, default to the app's Application Support directory.
        if targetPath == nil {
            self.targetPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(self.logFileName).log")
        } else {
            self.targetPath = targetPath!.appendingPathComponent("\(self.logFileName).log")
        }
        // Check if log rotation is needed during initialization.
        rotateIfNeeded()
        if debugMode {
            print("LogPilot.start logging into \(self.targetPath)")
        }
    }
    
    // Logs a message to the current log file, appending a timestamp to each entry.
    public func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        do {
            // Create the log file if it doesn't exist.
            if !FileManager.default.fileExists(atPath: targetPath.path) {
                FileManager.default.createFile(atPath: targetPath.path, contents: nil)
            }
            // Open the file for writing and append the log entry.
            let handle = try FileHandle(forWritingTo: targetPath)
            handle.seekToEndOfFile()
            if let data = logEntry.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
            // Check if log rotation is needed after writing.
            rotateIfNeeded()
        } catch {
            print("LogPilot.Log error: \(error)")
        }
    }
    
    // takes all the logs with the respective log-name (including the current one and the archives) and zips them together
    public func createLogArchive() throws -> URL? {
        //determine name of archive
        let archiveUrl = targetPath.deletingLastPathComponent()
            .appendingPathComponent("\(self.logFileName).zip")

        // Remove any existing zip file with the same name.
        if FileManager.default.fileExists(atPath: archiveUrl.path) {
            try FileManager.default.removeItem(at: archiveUrl)
            if debugMode {
               print("LogPilot.Removed existing zip file at \(archiveUrl.path)")
            }
        }
        
        //identify all logs and filter out the ones with the right name
        let allLogs = (try? FileManager.default.contentsOfDirectory(at: targetPath.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
        let archiveLogs = allLogs.filter { $0.lastPathComponent.contains(self.logFileName) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if debugMode {
            print("LogPilot.\(archiveLogs.count) archivedLogs \(archiveLogs)")
        }
        
        //put all together
        do {
            let archive = try Archive(url: archiveUrl, accessMode: .create)
            for fileURL in archiveLogs {
                let fileName = fileURL.lastPathComponent
                try archive.addEntry(with: fileName, fileURL: fileURL)
            }
            return archive.url
        } catch {
            print("Failed to create archive: \(error)")
        }
        return nil
    }
    
    // Rotates the log file if its size exceeds the maximum allowed size.
    func rotateIfNeeded() {
        // Get the current file size.
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: targetPath.path)[.size] as? UInt64 else {
            return
        }
        // If the file size is within the limit, no rotation is needed.
        guard fileSize > maxFileSize else { return }
        if debugMode {
            print("LogPilot.current file size = \(fileSize) > max file size = \(maxFileSize), rotating log file...")
        }
        
        // Archive the current log file by renaming it.
        let archiveURL = targetPath.deletingLastPathComponent()
            .appendingPathComponent(calcAchiveFileName())
        try? FileManager.default.moveItem(at: targetPath, to: archiveURL)
        if debugMode {
            print("LogPilot.archive into \(archiveURL.description)")
        }
        
        // Clean up old archived logs if the number exceeds the maximum allowed.
        let allLogs = (try? FileManager.default.contentsOfDirectory(at: targetPath.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
        let archiveLogs = allLogs.filter { $0.lastPathComponent.contains(self.logFileName) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if debugMode {
            print("LogPilot.\(archiveLogs.count) archivedLogs \(archiveLogs)")
        }
        
        let excess = archiveLogs.count - maxArchivedLogs
        
        if debugMode {
            print("LogPilot.with maxArchive = \(maxArchivedLogs) identified \(excess) old logs to delete")
        }
        
        // Delete the oldest logs if there are more than the allowed number of archived logs.
        if excess > 0 {
            for url in archiveLogs.prefix(excess) {
                if debugMode {
                    print("LogPilot.try delete \(url.description)")
                }
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    // Returns the URL of the current log file.
    func getCurrentLogFileURL() -> URL {
        return targetPath
    }
    
    // Generates a unique name for an archived log file using the log counter.
    private func calcAchiveFileName() -> String {
        logCounter += 1
        return "\(self.logFileName)_\(logCounter).log"
    }
}
