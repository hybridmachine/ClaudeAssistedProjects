import AVFoundation
import os

final class AudioManager {
    private var engine: AVAudioEngine?
    private var humNode: AVAudioSourceNode?
    private var crackleNode: AVAudioSourceNode?

    // Shared state between main thread and audio render thread
    private struct AudioParams {
        var isEnabled: Bool = true
        var volume: Float = 0.5
        var targetHumBoost: Float = 0
        var dischargeEnvelope: Float = 0
        var dischargeSoundStyle: Int = 1  // crystallineChime default
        var dischargeTriggered: Bool = false
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

                localHumPhase += 240.0 / sr
                if localHumPhase > 1.0 { localHumPhase -= 1.0 }
                localHumPhase2 += 0.3 / sr
                if localHumPhase2 > 1.0 { localHumPhase2 -= 1.0 }
            }
            return noErr
        }

        // Discharge effect with selectable sound styles
        let dischargeParams = self.params
        let sr = self.sampleRate

        // Phase accumulators for tonal discharge styles (captured by closure)
        var localPhase: Float = 0
        var localPhase2: Float = 0

        let crackleSource = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            var p = dischargeParams.withLock {
                let snapshot = $0
                $0.dischargeTriggered = false
                return snapshot
            }
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = bufferList[0]
            let frames = Int(frameCount)
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            // Reset phases on new discharge trigger
            if p.dischargeTriggered {
                localPhase = 0
                localPhase2 = 0
            }

            let vol = p.isEnabled ? p.volume : 0
            let style = p.dischargeSoundStyle

            for i in 0..<frames {
                if p.dischargeEnvelope > 0.001 {
                    let sample: Float

                    switch style {
                    case 0: // Crackle — white noise burst
                        let noise = Float.random(in: -1...1)
                        sample = noise * p.dischargeEnvelope * 0.6
                        p.dischargeEnvelope *= 0.9997

                    case 1: // Crystalline Chime — harmonic sine tones
                        let d6: Float = 1174.66   // D6
                        let d7: Float = 2349.32   // D7
                        let a6: Float = 1760.0    // A6
                        let a7: Float = 3520.0    // A7
                        let t1 = sin(localPhase * d6 * 2 * .pi) * 0.35
                        let t2 = sin(localPhase * d7 * 2 * .pi) * 0.25
                        let t3 = sin(localPhase * a6 * 2 * .pi) * 0.25
                        let t4 = sin(localPhase * a7 * 2 * .pi) * 0.15
                        sample = (t1 + t2 + t3 + t4) * p.dischargeEnvelope * 0.5
                        p.dischargeEnvelope *= 0.99985

                    case 2: // Harmonic Shimmer — detuned beating sines
                        let tp = localPhase * 2 * .pi
                        let s0 = sin(tp * 1800)
                        let s1 = sin(tp * 1803)
                        let s2 = sin(tp * 1807)
                        let s3 = sin(tp * 1811)
                        let s4 = sin(tp * 1815)
                        sample = ((s0 + s1 + s2 + s3 + s4) / 5.0) * p.dischargeEnvelope * 0.5
                        p.dischargeEnvelope *= 0.9999

                    case 3: // Singing Bowl — rich harmonics with wobble
                        let fundamental: Float = 293.0
                        let wobble = 1.0 + sin(localPhase2 * 5.0 * 2 * .pi) * 0.003
                        var sum: Float = 0
                        for h in 1...5 {
                            let hf = Float(h)
                            let envPow = powf(p.dischargeEnvelope, hf)
                            sum += sin(localPhase * fundamental * hf * wobble * 2 * .pi) * envPow / hf
                        }
                        sample = sum * 0.4
                        p.dischargeEnvelope *= 0.99995

                    case 4: // Electric Arc Sweep — frequency sweep with tremolo
                        let freq = 2500.0 * p.dischargeEnvelope + 80.0 * (1.0 - p.dischargeEnvelope)
                        let sine = sin(localPhase * freq * 2 * .pi)
                        let noise = Float.random(in: -1...1) * 0.1
                        let tremolo = 1.0 + sin(localPhase2 * 30.0 * 2 * .pi) * 0.3
                        sample = (sine + noise) * tremolo * p.dischargeEnvelope * 0.5
                        p.dischargeEnvelope *= 0.9998

                    default:
                        sample = 0
                    }

                    data[i] = sample * vol
                    localPhase += 1.0 / sr
                    if localPhase > 1.0 { localPhase -= 1.0 }
                    localPhase2 += 1.0 / sr
                    if localPhase2 > 1.0 { localPhase2 -= 1.0 }
                } else {
                    data[i] = 0
                }
            }

            dischargeParams.withLock {
                $0.dischargeEnvelope = p.dischargeEnvelope
            }

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
        params.withLock {
            $0.dischargeEnvelope = 1.0
            $0.dischargeTriggered = true
        }
    }

    func setDischargeSoundStyle(_ style: DischargeSoundStyle) {
        params.withLock { $0.dischargeSoundStyle = style.intValue }
    }

    func updateVolume(_ vol: Float) {
        params.withLock { $0.volume = vol }
    }

    func setEnabled(_ enabled: Bool) {
        params.withLock { $0.isEnabled = enabled }
    }
}
