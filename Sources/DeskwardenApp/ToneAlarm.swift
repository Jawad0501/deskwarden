import AVFoundation
import Deskwarden
import Foundation

final class ToneAlarm: DeskAlarm {
    private(set) var requestedSeconds: [Int] = []
    private(set) var stopCount = 0
    private var player: AVAudioPlayer?
    private let sampleRate = 44_100
    private let firstTone = 880.0
    private let secondTone = 660.0
    private let amplitude = 0.6

    func start(seconds: Int) {
        requestedSeconds.append(seconds)
        guard seconds > 0, let data = wavData(seconds: seconds) else {
            return
        }
        player?.stop()
        guard let next = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue) else {
            return
        }
        next.prepareToPlay()
        next.play()
        player = next
    }

    func stop() {
        player?.stop()
        stopCount += 1
    }

    private func wavData(seconds: Int) -> Data? {
        let sampleCount = sampleRate * seconds
        guard sampleCount > 0 else {
            return nil
        }
        let dataSize = sampleCount * MemoryLayout<Int16>.size
        var data = Data(count: 44 + dataSize)
        data.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else {
                return
            }
            writeWAVHeader(base, dataSize: dataSize)
            let samples = base.advanced(by: 44).assumingMemoryBound(to: Int16.self)
            let slice = max(1, sampleRate / 4)
            let scale = amplitude * Double(Int16.max)
            for index in 0..<sampleCount {
                let frequency = (index / slice) % 2 == 0 ? firstTone : secondTone
                let time = Double(index) / Double(sampleRate)
                let value = sin((2.0 * Double.pi * frequency) * time) * scale
                samples[index] = Int16(value).littleEndian
            }
        }
        return data
    }

    private func writeWAVHeader(_ base: UnsafeMutableRawPointer, dataSize: Int) {
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        writeASCII("RIFF", at: 0, in: bytes)
        write32(UInt32(36 + dataSize), at: 4, in: bytes)
        writeASCII("WAVE", at: 8, in: bytes)
        writeASCII("fmt ", at: 12, in: bytes)
        write32(16, at: 16, in: bytes)
        write16(1, at: 20, in: bytes)
        write16(1, at: 22, in: bytes)
        write32(UInt32(sampleRate), at: 24, in: bytes)
        write32(UInt32(sampleRate * 2), at: 28, in: bytes)
        write16(2, at: 32, in: bytes)
        write16(16, at: 34, in: bytes)
        writeASCII("data", at: 36, in: bytes)
        write32(UInt32(dataSize), at: 40, in: bytes)
    }

    private func writeASCII(_ text: String, at offset: Int, in bytes: UnsafeMutablePointer<UInt8>) {
        for (index, byte) in text.utf8.enumerated() {
            bytes[offset + index] = byte
        }
    }

    private func write16(_ value: UInt16, at offset: Int, in bytes: UnsafeMutablePointer<UInt8>) {
        bytes[offset] = UInt8(value & 0xff)
        bytes[offset + 1] = UInt8((value >> 8) & 0xff)
    }

    private func write32(_ value: UInt32, at offset: Int, in bytes: UnsafeMutablePointer<UInt8>) {
        bytes[offset] = UInt8(value & 0xff)
        bytes[offset + 1] = UInt8((value >> 8) & 0xff)
        bytes[offset + 2] = UInt8((value >> 16) & 0xff)
        bytes[offset + 3] = UInt8((value >> 24) & 0xff)
    }
}
