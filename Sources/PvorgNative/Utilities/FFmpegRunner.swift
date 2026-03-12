import Foundation

struct ProcessResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum ProcessError: Error, LocalizedError {
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return message
        }
    }
}

struct FFmpegRunner {
    private static let fallbackExecutablePaths: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ]

    private final class SafeState: @unchecked Sendable {
        private let lock = NSLock()
        private var _resumed = false
        func markResumed() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if _resumed { return false }
            _resumed = true
            return true
        }
    }

    static func runProcess(executable: String, arguments: [String]) async throws -> ProcessResult {
        let startTime = Date()
        let commandString = "\(executable) \(arguments.joined(separator: " "))"
        Log.preprocess.info("Starting process: \(commandString, privacy: .public)")

        return try await withCheckedThrowingContinuation { continuation in
            let state = SafeState()
            let process = Process()
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory
            let token = UUID().uuidString
            let outURL = tempDir.appendingPathComponent("pvorg-\(token)-stdout.log")
            let errURL = tempDir.appendingPathComponent("pvorg-\(token)-stderr.log")

            guard fm.createFile(atPath: outURL.path, contents: nil),
                  fm.createFile(atPath: errURL.path, contents: nil) else {
                if state.markResumed() {
                    continuation.resume(throwing: ProcessError.executionFailed("Failed to create temporary output files for process capture"))
                }
                return
            }

            let stdoutHandle: FileHandle
            let stderrHandle: FileHandle
            do {
                stdoutHandle = try FileHandle(forWritingTo: outURL)
                stderrHandle = try FileHandle(forWritingTo: errURL)
            } catch {
                try? fm.removeItem(at: outURL)
                try? fm.removeItem(at: errURL)
                if state.markResumed() {
                    continuation.resume(throwing: ProcessError.executionFailed("Failed opening temporary output files: \(error.localizedDescription)"))
                }
                return
            }

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
            process.environment = runtimeEnvironment()
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle
            process.standardInput = nil // Prevent hang waiting for stdin

            // Timeout mechanism
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30s timeout
                if state.markResumed() {
                    Log.preprocess.error("Process timed out after 30s: \(commandString, privacy: .public)")
                    process.terminate()
                    // The terminationHandler will be called when we call terminate()
                    // but we already marked it as resumed here, so we need to resume the continuation now.

                    try? stdoutHandle.close()
                    try? stderrHandle.close()
                    try? FileManager.default.removeItem(at: outURL)
                    try? FileManager.default.removeItem(at: errURL)

                    continuation.resume(throwing: ProcessError.executionFailed("Process timed out after 30s: \(commandString)"))
                }
            }

            process.terminationHandler = { proc in
                timeoutTask.cancel()
                guard state.markResumed() else { return }

                try? stdoutHandle.close()
                try? stderrHandle.close()

                let outData = (try? Data(contentsOf: outURL)) ?? Data()
                let errData = (try? Data(contentsOf: errURL)) ?? Data()
                try? FileManager.default.removeItem(at: outURL)
                try? FileManager.default.removeItem(at: errURL)

                let out = String(data: outData, encoding: .utf8) ?? ""
                let err = String(data: errData, encoding: .utf8) ?? ""

                let duration = Date().timeIntervalSince(startTime)
                Log.preprocess.info("Process finished in \(String(format: "%.2fs", duration)): \(executable) (exit \(proc.terminationStatus))")

                continuation.resume(returning: ProcessResult(stdout: out, stderr: err, exitCode: proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                if state.markResumed() {
                    try? stdoutHandle.close()
                    try? stderrHandle.close()
                    try? fm.removeItem(at: outURL)
                    try? fm.removeItem(at: errURL)
                    continuation.resume(throwing: ProcessError.executionFailed("Failed to run \(executable): \(error.localizedDescription)"))
                }
            }
        }
    }

    static func parseFPS(_ rFrameRate: String) -> Double {
        if rFrameRate.contains("/") {
            let parts = rFrameRate.split(separator: "/")
            guard parts.count == 2,
                  let numerator = Double(parts[0]),
                  let denominator = Double(parts[1]),
                  denominator != 0 else {
                return 0
            }
            return ((numerator / denominator) * 100).rounded() / 100
        }

        return (Double(rFrameRate) ?? 0).rounded(toPlaces: 2)
    }

    private static func runtimeEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let current = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        var merged = current
        for path in fallbackExecutablePaths where !merged.contains(path) {
            merged.append(path)
        }
        environment["PATH"] = merged.joined(separator: ":")
        return environment
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        guard places >= 0 else { return self }
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
