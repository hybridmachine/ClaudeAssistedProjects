import AVFoundation
import os

final class AudioManager {
    private var engine: AVAudioEngine?
    private var humNode: AVAudioSourceNode?
    private var crackleNode: AVAudioSourceNode?

    // Render-thread-only state (not shared with main thread)
    private var humPhase: Float = 0
    private var humPhase2: Float = 0

    // Shared state between main thread and audio render thread
    private struct AudioParams {
        var isEnabled: Bool = true
        var volume: Float = 0.5
        var targetHumBoost: Float = 0
        var dischargeEnvelope: Float = 0
    }
    private let params = OSAllocatedUnfairLock(initialState: AudioParams())

    private var isStarted = false
    private let sampleRate: Float = 44100

    init() {
        setupAudioSession()
    }

    deinit {
        engine?.stop()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: .mixWithOthers)
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .ended {
            try? AVAudioSession.sharedInstance().setActive(true)
            if isStarted {
                try? engine?.start()
            }
        }
    }

    func start() {
        guard !isStarted else { return }

        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1) else {
            return
        }

        // Ambient hum: 60Hz fundamental + harmonics
        // humPhase/humPhase2 are captured by value then stored locally in closure
        var localHumPhase: Float = 0
        var localHumPhase2: Float = 0
        var localHumBoost: Float = 0
        let humParams = self.params

        let humSource = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let p = humParams.withLock { $0 }
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = bufferList[0]
            let frames = Int(frameCount)
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            let sr: Float = 44100
            for i in 0..<frames {
                // Smoothly interpolate toward target touch boost
                localHumBoost += (p.targetHumBoost - localHumBoost) * 0.0005

                // Volume scales from quiet ambient (0.10) to loud touched (0.25)
                let vol = p.isEnabled ? p.volume * (0.10 + localHumBoost * 0.15) : 0

                let fundamental = sin(localHumPhase * 2 * .pi) * 0.5
                let harmonic2 = sin(localHumPhase * 4 * .pi) * 0.12
                let harmonic3 = sin(localHumPhase * 6 * .pi) * 0.03

                let mod = 1.0 + sin(localHumPhase2 * 2 * .pi) * 0.08
                let sample = (fundamental + harmonic2 + harmonic3) * mod * vol

                data[i] = sample

                localHumPhase += 60.0 / sr
                if localHumPhase > 1.0 { localHumPhase -= 1.0 }
                localHumPhase2 += 0.3 / sr
                if localHumPhase2 > 1.0 { localHumPhase2 -= 1.0 }
            }
            return noErr
        }

        // Discharge effect only (crackle removed — hum handles touch feedback)
        let dischargeParams = self.params

        let crackleSource = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            var p = dischargeParams.withLock { $0 }
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = bufferList[0]
            let frames = Int(frameCount)
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            let vol = p.isEnabled ? p.volume : 0

            for i in 0..<frames {
                if p.dischargeEnvelope > 0.001 {
                    let noise = Float.random(in: -1...1)
                    data[i] = noise * p.dischargeEnvelope * 0.6 * vol
                    p.dischargeEnvelope *= 0.9997
                } else {
                    data[i] = 0
                }
            }

            let finalEnvelope = p.dischargeEnvelope
            dischargeParams.withLock { $0.dischargeEnvelope = finalEnvelope }

            return noErr
        }

        engine.attach(humSource)
        engine.attach(crackleSource)

        let mixer = engine.mainMixerNode
        engine.connect(humSource, to: mixer, format: format)
        engine.connect(crackleSource, to: mixer, format: format)

        self.humNode = humSource
        self.crackleNode = crackleSource
        self.engine = engine

        do {
            try engine.start()
            isStarted = true
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }

    func stop() {
        engine?.stop()
        isStarted = false
    }

    func setCrackle(force: Float) {
        params.withLock { $0.targetHumBoost = min(force, 1.0) }
    }

    func stopCrackle() {
        params.withLock { $0.targetHumBoost = 0 }
    }

    func triggerDischarge() {
        params.withLock { $0.dischargeEnvelope = 1.0 }
    }

    func updateVolume(_ vol: Float) {
        params.withLock { $0.volume = vol }
    }

    func setEnabled(_ enabled: Bool) {
        params.withLock { $0.isEnabled = enabled }
    }
}
