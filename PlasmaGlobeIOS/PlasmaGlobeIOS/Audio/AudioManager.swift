import AVFoundation
import os

final class AudioManager {
    private var engine: AVAudioEngine?
    private var humNode: AVAudioSourceNode?
    private var crackleNode: AVAudioSourceNode?

    // Render-thread-only state (not shared with main thread)
    private var humPhase: Float = 0
    private var humPhase2: Float = 0
    private var crackleGain: Float = 0

    // Shared state between main thread and audio render thread
    private struct AudioParams {
        var isEnabled: Bool = true
        var volume: Float = 0.5
        var targetCrackleGain: Float = 0
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
        let humParams = self.params

        let humSource = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let p = humParams.withLock { $0 }
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = bufferList[0]
            let frames = Int(frameCount)
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            let vol = p.isEnabled ? p.volume * 0.15 : 0
            let sr: Float = 44100
            for i in 0..<frames {
                let fundamental = sin(localHumPhase * 2 * .pi) * 0.4
                let harmonic2 = sin(localHumPhase * 4 * .pi) * 0.2
                let harmonic3 = sin(localHumPhase * 6 * .pi) * 0.1
                let harmonic5 = sin(localHumPhase * 10 * .pi) * 0.05

                let mod = 1.0 + sin(localHumPhase2 * 2 * .pi) * 0.15
                let sample = (fundamental + harmonic2 + harmonic3 + harmonic5) * mod * vol

                data[i] = sample

                localHumPhase += 60.0 / sr
                if localHumPhase > 1.0 { localHumPhase -= 1.0 }
                localHumPhase2 += 0.5 / sr
                if localHumPhase2 > 1.0 { localHumPhase2 -= 1.0 }
            }
            return noErr
        }

        // Crackle + discharge: band-filtered noise
        var localCrackleGain: Float = 0
        let crackleParams = self.params

        let crackleSource = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            var p = crackleParams.withLock { $0 }
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = bufferList[0]
            let frames = Int(frameCount)
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            let vol = p.isEnabled ? p.volume : 0

            for i in 0..<frames {
                localCrackleGain += (p.targetCrackleGain - localCrackleGain) * 0.001

                let noise = Float.random(in: -1...1)

                var crackleSample: Float = 0
                if localCrackleGain > 0.01 {
                    let burstProb = Float.random(in: 0...1)
                    if burstProb > 0.92 {
                        crackleSample = noise * localCrackleGain * 0.4
                    }
                }

                var dischargeSample: Float = 0
                if p.dischargeEnvelope > 0.001 {
                    dischargeSample = noise * p.dischargeEnvelope * 0.6
                    p.dischargeEnvelope *= 0.9997
                }

                data[i] = (crackleSample + dischargeSample) * vol
            }

            // Write back the decayed discharge envelope
            let finalEnvelope = p.dischargeEnvelope
            crackleParams.withLock { $0.dischargeEnvelope = finalEnvelope }

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
        params.withLock { $0.targetCrackleGain = force }
    }

    func stopCrackle() {
        params.withLock { $0.targetCrackleGain = 0 }
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
