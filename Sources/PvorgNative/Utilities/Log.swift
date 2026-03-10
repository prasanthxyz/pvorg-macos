import OSLog

enum Log {
    static let app = Logger(subsystem: "com.pvorg.native", category: "app")
    static let pipeline = Logger(subsystem: "com.pvorg.native", category: "pipeline")
    static let io = Logger(subsystem: "com.pvorg.native", category: "io")
    static let preprocess = Logger(subsystem: "com.pvorg.native", category: "preprocess")
}
