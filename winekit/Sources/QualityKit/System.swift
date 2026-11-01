public import Foundation

/// What a command printed and how it ended.
public struct CommandResult: Equatable, Sendable {
    public var status: Int32
    /// What it wrote on standard output.
    public var output: String
    /// What it wrote on standard error.
    public var errors: String

    public init(status: Int32, output: String = "", errors: String = "") {
        self.status = status
        self.output = output
        self.errors = errors
    }

    public var succeeded: Bool { status == 0 }
}

/// Runs other programs. The gates reach the world only through this and `FileSystem`, so the tests can stand in for both.
public protocol CommandRunning: Sendable {
    /// Runs `executable` (a path, or a name looked up on PATH) with `arguments` in `directory`. With `echo`, the command's
    /// output goes to this process's output as it comes and is not captured.
    func run(_ executable: String, _ arguments: [String], in directory: URL, echo: Bool) throws -> CommandResult
}

/// The file system, as far as the gates read it.
public protocol FileSystem: Sendable {
    func fileExists(_ url: URL) -> Bool
    func contents(_ url: URL) throws -> Data
    /// Every regular file under `directory`, recursively, as paths relative to it, sorted.
    func files(under directory: URL) -> [String]
    func write(_ data: Data, to url: URL) throws
}

public enum QualityError: Error, Equatable, CustomStringConvertible {
    /// A gate held its ground: the check found something.
    case gateFailed(String)
    /// A tool is missing, couldn't be installed, or couldn't run.
    case unavailable(String)
    case usage(String)

    public var description: String {
        switch self {
            case .gateFailed(let message): message
            case .unavailable(let message): message
            case .usage(let message): message
        }
    }

    /// The exit status of the command-line tool: 1 for a failed gate, 2 for anything that kept a gate from running.
    public var exitStatus: Int32 {
        if case .gateFailed = self { return 1 }
        return 2
    }
}

/// Foundation's `Process`.
public struct ProcessRunner: CommandRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String], in directory: URL, echo: Bool) throws -> CommandResult
    {
        let process = Process()
        if executable.contains("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
        }
        process.currentDirectoryURL = directory
        // Files rather than pipes: a command that fills one stream while the other is being read can't stall.
        let capture = FileManager.default.temporaryDirectory.appendingPathComponent("winekit-\(UUID().uuidString)")
        let outURL = capture.appendingPathExtension("out")
        let errURL = capture.appendingPathExtension("err")
        defer {
            try? FileManager.default.removeItem(at: outURL)
            try? FileManager.default.removeItem(at: errURL)
        }
        if !echo {
            FileManager.default.createFile(atPath: outURL.path, contents: nil)
            FileManager.default.createFile(atPath: errURL.path, contents: nil)
            process.standardOutput = try FileHandle(forWritingTo: outURL)
            process.standardError = try FileHandle(forWritingTo: errURL)
        }
        do { try process.run() } catch { throw QualityError.unavailable("could not run \(executable): \(error)") }
        process.waitUntilExit()
        let out = echo ? Data() : (try? Data(contentsOf: outURL)) ?? Data()
        let err = echo ? Data() : (try? Data(contentsOf: errURL)) ?? Data()
        return CommandResult(
            status: process.terminationStatus, output: String(decoding: out, as: UTF8.self),
            errors: String(decoding: err, as: UTF8.self))
    }
}

/// Foundation's `FileManager`.
public struct LocalFileSystem: FileSystem {
    public init() {}

    public func fileExists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    public func contents(_ url: URL) throws -> Data { try Data(contentsOf: url) }

    public func files(under directory: URL) -> [String] {
        let base = directory.standardizedFileURL.path + "/"
        guard
            let walker = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        else { return [] }
        var found: [String] = []
        for case let url as URL in walker
        where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            let path = url.standardizedFileURL.path
            found.append(path.hasPrefix(base) ? String(path.dropFirst(base.count)) : path)
        }
        return found.sorted()
    }

    public func write(_ data: Data, to url: URL) throws { try data.write(to: url) }
}

/// Where the gates write what they do.
public protocol Reporting: Sendable {
    func step(_ message: String)
    func note(_ message: String)
}

public struct ConsoleReporter: Reporting {
    let write: @Sendable (String) -> Void

    /// Writes each line with `write`: standard output unless told otherwise.
    public init(write: @escaping @Sendable (String) -> Void = { print($0) }) { self.write = write }

    public func step(_ message: String) { write("==> \(message)") }
    public func note(_ message: String) { write(message) }
}
