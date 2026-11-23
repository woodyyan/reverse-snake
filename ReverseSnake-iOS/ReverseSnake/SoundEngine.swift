import Foundation
import AVFoundation

/// WebAudio OscillatorNode equivalent.
/// Generates a PCM buffer with the same waveforms and exponential gain envelope
/// used by beep() in index.html, then schedules it on AVAudioEngine.
final class SoundEngine {
    static let shared = SoundEngine()

    enum Wave {
        case sine
        case triangle
        case sawtooth
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private let lock = NSLock()
    private var ready = false
    private var graphBuilt = false

    /// AVAudioSession.setCategory / setActive are synchronous IPC calls to
    /// mediaserverd. Xcode's "AVAudioSession Hang Risk" diagnostic flags them
    /// on the main thread ("This method can lead to UI unresponsiveness...").
    /// All session and engine setup therefore runs on this serial queue;
    /// iOS 27+ additionally uses Apple's asynchronous activate API.
    private let sessionQueue = DispatchQueue(
        label: "com.woodystudio.reversesnake.audio-session", qos: .userInitiated)

    private init() {
        // Never block the caller (normally the main thread) during setup.
        sessionQueue.async { self.configure() }
    }

    private var isReady: Bool {
        lock.lock(); defer { lock.unlock() }
        return ready
    }

    private func setReady(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        ready = value
    }

    /// Runs on sessionQueue only.
    private func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        } catch {
            return
        }

        if #available(iOS 27.0, *) {
            // Recommended async activation: returns immediately, never blocks.
            session.activate(options: []) { [weak self] activated, _ in
                guard let self else { return }
                self.sessionQueue.async {
                    if !activated {
                        // Fallback if the async activation is refused.
                        try? session.setActive(true, options: [])
                    }
                    self.startEngine()
                }
            }
        } else {
            // No async API before iOS 27: the serial queue keeps the blocking
            // call off the main thread (same effect, works back to iOS 16).
            do {
                try session.setActive(true, options: [])
            } catch {
                return
            }
            startEngine()
        }
    }

    /// Runs on sessionQueue only. Safe to call again after an interruption.
    private func startEngine() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        if !graphBuilt {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            graphBuilt = true
        }
        engine.prepare()
        do {
            try engine.start()
            setReady(true)
        } catch {
            setReady(false)
        }
    }

    func beep(freq: Double, duration: Double, wave: Wave, volume: Float) {
        guard isReady, volume > 0 else { return }
        lock.lock()
        defer { lock.unlock() }

        if !engine.isRunning {
            // Recover on the audio queue, never on the calling thread.
            ready = false
            sessionQueue.async { self.startEngine() }
            return
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        let frameCount = max(1, AVAudioFrameCount(duration * sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return }

        let peak = max(volume, 0.0001)
        let decay = Double(0.0001 / peak)
        let frames = Int(frameCount)
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let phase = freq * t
            let sample: Double
            switch wave {
            case .sine:
                sample = sin(2.0 * .pi * phase)
            case .triangle:
                sample = (2.0 / .pi) * asin(sin(2.0 * .pi * phase))
            case .sawtooth:
                sample = 2.0 * (phase - floor(phase + 0.5))
            }
            let envelope = Double(peak) * pow(decay, Double(i) / Double(frames))
            channel[i] = Float(sample * envelope)
        }

        player.scheduleBuffer(buffer)
        if !player.isPlaying {
            player.play()
        }
    }
}
