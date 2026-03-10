actor PipelineGuard {
    private var isRunning = false

    func claim() -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        return true
    }

    func release() {
        isRunning = false
    }
}
