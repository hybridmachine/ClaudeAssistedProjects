import AVFoundation
import os

final class AudioManager {
    private var engine: AVAudioEngine?
    private var humNode: AVAudioSourceNode?
    private var crackleNode: AVAudioSourceNode?

    private static let sinLUTSize = 4096
    private static let sinLUT: [Float] = {
        (0..<sinLUTSize).map { i in
            sinf(Float(i) / Float(sinLUTSize) * 2 * .pi)
        }
    }()

    @inline(__always)
    private static func fastSin(phase: Float) -> Float {
        let wrapped = phase - floorf(phase)
        let indexF = wrapped * Float(sinLUTSize)
        let i0 = Int(indexF) & (sinLUTSize - 1)
        let i1 = (i0 + 1) & (sinLUTSize - 1)
        let frac = indexF - floorf(indexF)
        return sinLUT[i0] + (sinLUT[i1] - sinLUT[i0]) * frac
    }

    // Shared state between main thread and audio render thread
    private struct AudioParams {
        var isEnabled: Bool = true
        var volume: Float = 0.5
        var targetHumBoost: Float = 0
        var dischargeEnvelope: Float = 0
        var dischargeSoundStyle: Int = 1  // crystallineChime default
        var humFrequency: Float = 60.0
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

                let fundamental = AudioManager.fastSin(phase: localHumPhase) * 0.5
                let harmonic2 = AudioManager.fastSin(phase: localHumPhase * 2) * 0.12
                let harmonic3 = AudioManager.fastSin(phase: localHumPhase * 3) * 0.03

                let mod = 1.0 + AudioManager.fastSin(phase: localHumPhase2) * 0.08
                let sample = (fundamental + harmonic2 + harmonic3) * mod * vol

                data[i] = sample

                localHumPhase += p.humFrequency / sr
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

        // Cached synthesizer to avoid per-buffer allocation
        var cachedSynthStyleId: Int = -1
        var cachedSynth: any DischargeSoundSynthesizer = CrystallineChimeSynthesizer()

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
            if p.dischargeSoundStyle != cachedSynthStyleId {
                cachedSynthStyleId = p.dischargeSoundStyle
                cachedSynth = DischargeSoundStyle.from(intValue: p.dischargeSoundStyle).synthesizer
            }
            var synth = cachedSynth

            for i in 0..<frames {
                if p.dischargeEnvelope > 0.001 {
                    let result = synth.synthesize(phase: localPhase, phase2: localPhase2,
                                                  envelope: p.dischargeEnvelope, sampleRate: sr)
                    data[i] = result.sample * vol
                    p.dischargeEnvelope = result.newEnvelope
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

    func setHumFrequency(_ freq: Float) {
        params.withLock { $0.humFrequency = freq }
    }
}
