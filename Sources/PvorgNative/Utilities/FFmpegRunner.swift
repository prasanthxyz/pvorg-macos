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
    static func runProcess(executable: String, arguments: [String]) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory
            let token = UUID().uuidString
            let outURL = tempDir.appendingPathComponent("pvorg-\(token)-stdout.log")
            let errURL = tempDir.appendingPathComponent("pvorg-\(token)-stderr.log")

            guard fm.createFile(atPath: outURL.path, contents: nil),
                  fm.createFile(atPath: errURL.path, contents: nil) else {
                continuation.resume(throwing: ProcessError.executionFailed("Failed to create temporary output files for process capture"))
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
                continuation.resume(throwing: ProcessError.executionFailed("Failed opening temporary output files: \(error.localizedDescription)"))
                return
            }

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle

            process.terminationHandler = { proc in
                try? stdoutHandle.close()
                try? stderrHandle.close()

                let outData = (try? Data(contentsOf: outURL)) ?? Data()
                let errData = (try? Data(contentsOf: errURL)) ?? Data()
                try? FileManager.default.removeItem(at: outURL)
                try? FileManager.default.removeItem(at: errURL)

                let out = String(data: outData, encoding: .utf8) ?? ""
                let err = String(data: errData, encoding: .utf8) ?? ""

                continuation.resume(returning: ProcessResult(stdout: out, stderr: err, exitCode: proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                try? stdoutHandle.close()
                try? stderrHandle.close()
                try? fm.removeItem(at: outURL)
                try? fm.removeItem(at: errURL)
                continuation.resume(throwing: ProcessError.executionFailed("Failed to run \(executable): \(error.localizedDescription)"))
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
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        guard places >= 0 else { return self }
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
