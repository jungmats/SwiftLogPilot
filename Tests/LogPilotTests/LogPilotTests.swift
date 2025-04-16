import Testing
import Foundation
@testable import LogPilot

func numberOfFiles(startingWith name: String, for targetPath: URL) throws -> Int {
    let allLogs = (try? FileManager.default.contentsOfDirectory(at: targetPath.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
    let archiveLogs = allLogs.filter { $0.lastPathComponent.contains(name) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    print("\(archiveLogs.count) log files with prefix \(name): \(archiveLogs)")
    return archiveLogs.count
}

func cleanUp(startingWith name: String, for targetPath: URL) throws {
    let allLogs = (try? FileManager.default.contentsOfDirectory(at: targetPath.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
    let archiveLogs = allLogs.filter { $0.lastPathComponent.contains(name) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    for url in archiveLogs {
        print("delete \(url.description)")
        try? FileManager.default.removeItem(at: url)
    }
}

@Test func testInitialization() async throws {
    let pilot = FileLogger(logFileName: "hubertus", debugMode: true)
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    pilot.log("Hello, World!")
    #expect(pilot.targetPath.description == "file:///Users/majung/Library/Application%20Support/hubertus.log")
}
    
@Test func testRotation() async throws {
    print ("rotation start ------------------------------------")
    let logFileName = "log_rotation_test"
    let targetPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(logFileName).log")
    
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    let pilot = FileLogger(logFileName: logFileName, maxFileSize: 7000, debugMode: true)
    for i in 0..<15 {
        //500+ per loop
        pilot.log("\(i)-1-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-2-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-3-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-4-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-5-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
    }
    pilot.rotateIfNeeded()
    let nff = try numberOfFiles(startingWith: logFileName, for: pilot.targetPath)
    print ("rotation end with nff=\(nff) ------------------------------------")
    #expect(nff == 2)
}

@Test func testArchival() async throws {
    let logFileName = "log_archive_test"
    let maxArchivedLogs = 5
    let targetPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(logFileName).log")
    
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    let pilot = FileLogger(logFileName: logFileName, maxFileSize: 7000, maxArchivedLogs: maxArchivedLogs, debugMode: true)
    for i in 0..<1000 {
        //500+ per loop
        pilot.log("\(i)-1-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-2-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-3-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-4-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-5-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
    }
    let nff = try numberOfFiles(startingWith: logFileName, for: pilot.targetPath)
    #expect(nff == maxArchivedLogs + 1)//including the current log file
}

@Test func testLoggingWithoutRotation() async throws {
    let logFileName = "no_rotation_test"
    let targetPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(logFileName).log")
    
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    let pilot = FileLogger(logFileName: logFileName, maxFileSize: 10_000, debugMode: true) // Set a high maxFileSize to avoid rotation.
    pilot.log("This is a test log entry.")
    pilot.log("Another log entry.")
    
    // Verify that the log file exists and contains the expected content.
    let logContent = try String(contentsOf: pilot.getCurrentLogFileURL())
    #expect(logContent.contains("This is a test log entry."))
    #expect(logContent.contains("Another log entry."))
}

@Test func testErrorHandlingWhenFileCannotBeWritten() async throws {
    let logFileName = "error_handling_test"
    let targetPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(logFileName).log")
    
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    // Create a read-only log file to simulate a write error.
    FileManager.default.createFile(atPath: targetPath.path, contents: nil)
    try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: targetPath.path) // Read-only permissions.
    
    let pilot = FileLogger(logFileName: logFileName, debugMode: true)
    pilot.log("This log entry should fail.")
    
    // Verify that the log file is still empty due to the write error.
    let logContent = try String(contentsOf: targetPath)
    #expect(logContent.isEmpty)
    
    // Clean up by restoring write permissions.
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: targetPath.path)
}

@Test func testCustomTargetPath() async throws {
    let logFileName = "custom_path_test"
    let customDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("CustomLogs")
    let targetPath = customDirectory.appendingPathComponent("\(logFileName).log")
    
    // Ensure the custom directory exists.
    try? FileManager.default.createDirectory(at: customDirectory, withIntermediateDirectories: true)
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    let pilot = FileLogger(targetPath: customDirectory, logFileName: logFileName, debugMode: true)
    pilot.log("Log entry in custom path.")
    
    // Verify that the log file exists in the custom directory and contains the expected content.
    let logContent = try String(contentsOf: pilot.getCurrentLogFileURL())
    #expect(logContent.contains("Log entry in custom path."))
}

@Test func testLargeLogMessages() async throws {
    let logFileName = "large_message_test"
    let maxFileSize:UInt64 = 5000 // Small size to trigger rotation quickly.
    let targetPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(logFileName).log")
    
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    let pilot = FileLogger(logFileName: logFileName, maxFileSize: maxFileSize, debugMode: true)
    let largeMessage = String(repeating: "A", count: 6000) // Message larger than maxFileSize.
    pilot.log(largeMessage)
    pilot.log("log this too") //otherwise there's no current log file shown
    
    // Verify that rotation occurred and the large message was archived.
    let nff = try numberOfFiles(startingWith: logFileName, for: pilot.targetPath)
    #expect(nff == 2) // One archived file and one current log file.
}

@Test func testRotationWhenLogFileDoesNotExist() async throws {
    let logFileName = "missing_log_file_test"
    let maxFileSize: UInt64 = 5000
    let targetPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(logFileName).log")
    
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    let pilot = FileLogger(logFileName: logFileName, maxFileSize: maxFileSize, debugMode: true)
    pilot.log("This is a test log entry.")
    
    // Simulate the log file being deleted before rotation.
    //try FileManager.default.removeItem(at: pilot.getCurrentLogFileURL())
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    // Call rotateIfNeeded() and ensure it handles the missing file gracefully.
    pilot.rotateIfNeeded()
    
    //problem expected to be gracefully handled
    let fileNumber = try numberOfFiles(startingWith: logFileName, for: targetPath)
    #expect(fileNumber == 0)
    
    pilot.log("This is a test log entry.")
    //now the current log file must have been recreated
    #expect(try numberOfFiles(startingWith: logFileName, for: targetPath) == 1) // A new log file should be created.
}

@Test func testDisableDebug() async throws {
    let pilot = FileLogger(logFileName: "debug", maxFileSize: 5000, maxArchivedLogs: 2, debugMode: false)
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    pilot.log("Hello, World!")
    for i in 0..<1000 {
        //500+ per loop
        pilot.log("\(i)-1-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-2-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-3-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-4-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
        pilot.log("\(i)-5-01234567890012345678900123456789001234567890012345678900123456789001234567890012345678900123456789001234567890")
    }
    #expect(pilot.targetPath.description == "file:///Users/majung/Library/Application%20Support/debug.log")
}

@Test func testFilterAndSortInRotateIfNeeded() async throws {
    let logFileName = "filter_sort_test"
    let maxArchivedLogs = 5
    let targetPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(logFileName).log")
    
    try cleanUp(startingWith: logFileName, for: targetPath)
    
    let pilot = FileLogger(logFileName: logFileName, maxFileSize: 5000, maxArchivedLogs: maxArchivedLogs)
    
    // Create multiple files in the directory, some matching the logFileName prefix and some not.
    let directory = targetPath.deletingLastPathComponent()
    let matchingFiles = [
        directory.appendingPathComponent("\(logFileName)_3.log"),
        directory.appendingPathComponent("\(logFileName)_1.log"),
        directory.appendingPathComponent("\(logFileName)_2.log")
    ]
    let nonMatchingFiles = [
        directory.appendingPathComponent("unrelated_file_1.log"),
        directory.appendingPathComponent("another_file.log")
    ]
    
    for file in matchingFiles + nonMatchingFiles {
        FileManager.default.createFile(atPath: file.path, contents: nil)
    }
    
    // Call rotateIfNeeded to trigger the filter and sort logic.
    pilot.rotateIfNeeded()
    
    // Verify that only the matching files are considered for archiving.
    let allLogs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    let filteredLogs = allLogs.filter { $0.lastPathComponent.contains(logFileName) }
    #expect(filteredLogs.count == matchingFiles.count) // Only matching files should be considered.
    
    // Verify that the files are sorted correctly.
    let sortedLogs = filteredLogs.sorted { $0.lastPathComponent < $1.lastPathComponent }
    #expect(sortedLogs.map { $0.lastPathComponent } == matchingFiles.map { $0.lastPathComponent }.sorted())
}
