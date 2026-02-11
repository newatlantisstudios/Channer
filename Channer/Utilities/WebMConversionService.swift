import Foundation
import ffmpegkit

/// Service responsible for converting WebM videos to MP4 on Mac Catalyst
/// using FFmpegKit for transcoding. On iOS/iPadOS, no conversion is needed
/// as VLCKit handles WebM playback directly.
final class WebMConversionService {

    static let shared = WebMConversionService()

    // MARK: - Properties

    /// Cache of completed conversions: source URL hash -> local MP4 file URL
    private var conversionCache: [String: URL] = [:]

    /// Currently active FFmpeg session (for cancellation)
    private var activeSession: FFmpegSession?

    /// Lock for thread-safe cache access
    private let cacheLock = NSLock()

    /// Temp directory for converted files
    private let tempDirectory: URL = {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ChannerWebMConversion")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    // MARK: - Public API

    /// Returns true only on Mac Catalyst when the URL has a .webm extension
    func needsConversion(url: URL) -> Bool {
        #if targetEnvironment(macCatalyst)
        return url.pathExtension.lowercased() == "webm"
        #else
        return false
        #endif
    }

    /// Returns true only on Mac Catalyst when the URL string has a .webm extension
    func needsConversion(urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return needsConversion(url: url)
    }

    /// Main conversion API. Downloads remote WebM if needed, converts to MP4.
    /// - Parameters:
    ///   - source: The source WebM URL (local or remote)
    ///   - progress: Called with conversion progress (0.0 to 1.0)
    ///   - completion: Called with the converted MP4 URL on success, or error on failure
    func convertWebMToMP4(source: URL, progress: ((Double) -> Void)? = nil, completion: @escaping (Result<URL, Error>) -> Void) {
        let cacheKey = source.absoluteString.hashValue.description

        // Check cache first
        cacheLock.lock()
        if let cached = conversionCache[cacheKey], FileManager.default.fileExists(atPath: cached.path) {
            cacheLock.unlock()
            completion(.success(cached))
            return
        }
        cacheLock.unlock()

        // Output path
        let outputURL = tempDirectory.appendingPathComponent("\(cacheKey).mp4")

        // If output already exists from a previous session, return it
        if FileManager.default.fileExists(atPath: outputURL.path) {
            cacheLock.lock()
            conversionCache[cacheKey] = outputURL
            cacheLock.unlock()
            completion(.success(outputURL))
            return
        }

        if source.isFileURL {
            // Local file - convert directly
            runConversion(input: source, output: outputURL, cacheKey: cacheKey, progress: progress, completion: completion)
        } else {
            // Remote file - download first
            downloadRemoteFile(url: source) { [weak self] result in
                switch result {
                case .success(let localURL):
                    self?.runConversion(input: localURL, output: outputURL, cacheKey: cacheKey, progress: progress, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Pre-convert a video in the background (fire-and-forget)
    func preconvertIfNeeded(url: URL) {
        guard needsConversion(url: url) else { return }
        let cacheKey = url.absoluteString.hashValue.description

        cacheLock.lock()
        let alreadyCached = conversionCache[cacheKey] != nil
        cacheLock.unlock()

        if alreadyCached { return }

        let outputURL = tempDirectory.appendingPathComponent("\(cacheKey).mp4")
        if FileManager.default.fileExists(atPath: outputURL.path) { return }

        // Run in background without blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            if url.isFileURL {
                self.runConversion(input: url, output: outputURL, cacheKey: cacheKey, progress: nil) { _ in }
            } else {
                self.downloadRemoteFile(url: url) { [weak self] result in
                    if case .success(let localURL) = result {
                        self?.runConversion(input: localURL, output: outputURL, cacheKey: cacheKey, progress: nil) { _ in }
                    }
                }
            }
        }
    }

    /// Cancel the currently active conversion
    func cancelConversion() {
        activeSession?.cancel()
        activeSession = nil
    }

    /// Remove all converted files from the temp directory
    func cleanupTemporaryFiles() {
        cacheLock.lock()
        conversionCache.removeAll()
        cacheLock.unlock()

        try? FileManager.default.removeItem(at: tempDirectory)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private Methods

    /// Download a remote file to the temp directory
    private func downloadRemoteFile(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let localPath = tempDirectory.appendingPathComponent(url.lastPathComponent)

        // If already downloaded, reuse
        if FileManager.default.fileExists(atPath: localPath.path) {
            completion(.success(localPath))
            return
        }

        var request = URLRequest(url: url)
        // Add referer header for 4chan compatibility
        if let host = url.host, host.contains("4chan") {
            request.setValue("https://boards.4chan.org/", forHTTPHeaderField: "Referer")
        }

        let task = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let tempURL = tempURL else {
                completion(.failure(ConversionError.downloadFailed))
                return
            }
            do {
                // Remove any existing file at destination
                try? FileManager.default.removeItem(at: localPath)
                try FileManager.default.moveItem(at: tempURL, to: localPath)
                completion(.success(localPath))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    /// Run the FFmpeg conversion from WebM to MP4
    private func runConversion(input: URL, output: URL, cacheKey: String, progress: ((Double) -> Void)?, completion: @escaping (Result<URL, Error>) -> Void) {
        // Remove any existing output file
        try? FileManager.default.removeItem(at: output)

        // Use VideoToolbox hardware acceleration on macOS for H.264 encoding
        // Falls back to libx264 software encoding if VideoToolbox unavailable
        let command = "-i \"\(input.path)\" -c:v h264_videotoolbox -b:v 2M -c:a aac -b:a 128k -movflags +faststart -y \"\(output.path)\""

        print("DEBUG: WebMConversionService - Starting conversion: \(command)")

        // Get input duration for progress calculation using FFprobe
        var inputDurationMs: Double = 0
        if let probeSession = FFprobeKit.execute("-v quiet -show_entries format=duration -of csv=p=0 \"\(input.path)\"") {
            if let outputStr = probeSession.getAllLogsAsString(),
               let duration = Double(outputStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                inputDurationMs = duration * 1000.0
            }
        }

        let session = FFmpegKit.executeAsync(command, withCompleteCallback: { [weak self] session in
            guard let self = self, let session = session else { return }

            let returnCode = session.getReturnCode()

            if ReturnCode.isSuccess(returnCode) {
                print("DEBUG: WebMConversionService - Conversion successful")
                self.cacheLock.lock()
                self.conversionCache[cacheKey] = output
                self.cacheLock.unlock()

                DispatchQueue.main.async {
                    completion(.success(output))
                }
            } else if ReturnCode.isCancel(returnCode) {
                print("DEBUG: WebMConversionService - Conversion cancelled")
                try? FileManager.default.removeItem(at: output)
                DispatchQueue.main.async {
                    completion(.failure(ConversionError.cancelled))
                }
            } else {
                let logs = session.getAllLogsAsString() ?? "No logs"
                print("DEBUG: WebMConversionService - Conversion failed: \(logs)")
                try? FileManager.default.removeItem(at: output)

                // Try software encoding fallback
                self.runSoftwareConversion(input: input, output: output, cacheKey: cacheKey, progress: progress, completion: completion)
            }

            self.activeSession = nil

        }, withLogCallback: { log in
            if let message = log?.getMessage() {
                print("DEBUG: FFmpeg: \(message)")
            }
        }, withStatisticsCallback: { statistics in
            guard let statistics = statistics, inputDurationMs > 0 else { return }
            let time = statistics.getTime()
            if time > 0 {
                let progressValue = min(time / inputDurationMs, 1.0)
                DispatchQueue.main.async {
                    progress?(progressValue)
                }
            }
        })

        activeSession = session
    }

    /// Fallback to software encoding if hardware acceleration fails
    private func runSoftwareConversion(input: URL, output: URL, cacheKey: String, progress: ((Double) -> Void)?, completion: @escaping (Result<URL, Error>) -> Void) {
        try? FileManager.default.removeItem(at: output)

        let command = "-i \"\(input.path)\" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart -y \"\(output.path)\""

        print("DEBUG: WebMConversionService - Trying software encoding fallback: \(command)")

        let session = FFmpegKit.executeAsync(command, withCompleteCallback: { [weak self] session in
            guard let self = self, let session = session else { return }

            let returnCode = session.getReturnCode()

            if ReturnCode.isSuccess(returnCode) {
                print("DEBUG: WebMConversionService - Software conversion successful")
                self.cacheLock.lock()
                self.conversionCache[cacheKey] = output
                self.cacheLock.unlock()

                DispatchQueue.main.async {
                    completion(.success(output))
                }
            } else {
                let logs = session.getAllLogsAsString() ?? "No logs"
                print("DEBUG: WebMConversionService - Software conversion also failed: \(logs)")
                try? FileManager.default.removeItem(at: output)
                DispatchQueue.main.async {
                    completion(.failure(ConversionError.conversionFailed))
                }
            }

            self.activeSession = nil

        }, withLogCallback: nil, withStatisticsCallback: { statistics in
            guard let statistics = statistics else { return }
            let time = statistics.getTime()
            if time > 0 {
                DispatchQueue.main.async {
                    progress?(min(time / 30000.0, 0.99)) // Estimate ~30s video
                }
            }
        })

        activeSession = session
    }

    // MARK: - Error Types

    enum ConversionError: LocalizedError {
        case downloadFailed
        case conversionFailed
        case cancelled

        var errorDescription: String? {
            switch self {
            case .downloadFailed: return "Failed to download WebM file"
            case .conversionFailed: return "Failed to convert WebM to MP4"
            case .cancelled: return "Conversion was cancelled"
            }
        }
    }
}
