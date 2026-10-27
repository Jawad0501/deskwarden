import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Deskwarden
import Foundation

func capturesDirectoryURL() -> URL? {
    guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return nil
    }
    return base
        .appendingPathComponent("deskwarden", isDirectory: true)
        .appendingPathComponent("captures", isDirectory: true)
}

private final class HeldFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer

    init(_ pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
    }
}

final class InstantCamera: NSObject, DeskCamera, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private(set) var readyCount = 0
    private(set) var captureCount = 0
    private(set) var restCount = 0

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "deskwarden.camera.session")
    private let videoQueue = DispatchQueue(label: "deskwarden.camera.video")
    private let stateLock = NSLock()
    private var latestFrame: CVPixelBuffer?
    private var generation = 0
    private var acceptsFrames = false
    private var didLogUnavailable = false

    func becomeReady() {
        readyCount += 1
        stateLock.lock()
        generation += 1
        let startedGeneration = generation
        stateLock.unlock()
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else {
                return
            }
            guard granted else {
                self.logUnavailable()
                return
            }
            self.sessionQueue.async {
                self.startSession(generation: startedGeneration)
            }
        }
    }

    func captureInstant() {
        captureCount += 1
        stateLock.lock()
        let frame = latestFrame
        stateLock.unlock()
        guard let frame else {
            return
        }
        let held = HeldFrame(frame)
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }
            guard let copy = self.copyPixelBuffer(held.pixelBuffer) else {
                return
            }
            self.writeJPEG(copy)
        }
    }

    func rest() {
        restCount += 1
        stateLock.lock()
        generation += 1
        acceptsFrames = false
        latestFrame = nil
        stateLock.unlock()
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        stateLock.lock()
        let accepts = acceptsFrames
        stateLock.unlock()
        guard accepts, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        guard let copy = copyPixelBuffer(pixelBuffer) else {
            return
        }
        stateLock.lock()
        if acceptsFrames {
            latestFrame = copy
        }
        stateLock.unlock()
    }

    private func startSession(generation startedGeneration: Int) {
        guard isCurrent(startedGeneration) else {
            return
        }
        if session.inputs.isEmpty || session.outputs.isEmpty {
            guard configureSession() else {
                return
            }
        }
        guard isCurrent(startedGeneration) else {
            return
        }
        stateLock.lock()
        acceptsFrames = generation == startedGeneration
        stateLock.unlock()
        if !session.isRunning {
            session.startRunning()
            if !isCurrent(startedGeneration) {
                session.stopRunning()
            }
        }
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        if session.inputs.isEmpty {
            guard let device = AVCaptureDevice.default(for: .video) else {
                session.commitConfiguration()
                logUnavailable()
                return false
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else {
                    session.commitConfiguration()
                    logUnavailable()
                    return false
                }
                session.addInput(input)
            } catch {
                session.commitConfiguration()
                logUnavailable()
                return false
            }
        }
        if session.outputs.isEmpty {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                logUnavailable()
                return false
            }
            session.addOutput(output)
        }
        session.commitConfiguration()
        return true
    }

    private func isCurrent(_ startedGeneration: Int) -> Bool {
        stateLock.lock()
        let current = generation
        stateLock.unlock()
        return current == startedGeneration
    }

    private func logUnavailable() {
        stateLock.lock()
        let shouldLog = !didLogUnavailable
        didLogUnavailable = true
        stateLock.unlock()
        if shouldLog {
            NSLog("The camera is unavailable.")
        }
    }

    private func writeJPEG(_ pixelBuffer: CVPixelBuffer) {
        guard let directory = capturesDirectoryURL() else {
            return
        }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let url = directory.appendingPathComponent(captureFileName())
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try CIContext().writeJPEGRepresentation(of: image, to: url, colorSpace: colorSpace)
        } catch {
            return
        }
    }

    private func captureFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmssSSS'Z'"
        return formatter.string(from: Date()) + ".jpg"
    }

    private func copyPixelBuffer(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let format = CVPixelBufferGetPixelFormatType(source)
        guard width > 0, height > 0 else {
            return nil
        }
        var destination: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            nil,
            &destination
        )
        guard status == kCVReturnSuccess, let destination else {
            return nil
        }
        guard CVPixelBufferGetPlaneCount(source) == 0 else {
            return nil
        }
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        defer {
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
            CVPixelBufferUnlockBaseAddress(destination, [])
        }
        guard let sourceBase = CVPixelBufferGetBaseAddress(source),
            let destinationBase = CVPixelBufferGetBaseAddress(destination)
        else {
            return nil
        }
        let sourceRow = CVPixelBufferGetBytesPerRow(source)
        let destinationRow = CVPixelBufferGetBytesPerRow(destination)
        let rowBytes = min(sourceRow, destinationRow)
        _ = destinationBase.initializeMemory(as: UInt8.self, repeating: 0, count: destinationRow * height)
        for row in 0..<height {
            destinationBase.advanced(by: row * destinationRow).copyMemory(
                from: sourceBase.advanced(by: row * sourceRow),
                byteCount: rowBytes
            )
        }
        return destination
    }
}
