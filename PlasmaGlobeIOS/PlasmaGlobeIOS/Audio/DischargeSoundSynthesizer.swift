import Foundation

protocol DischargeSoundSynthesizer {
    mutating func synthesize(phase: Float, phase2: Float, envelope: Float, sampleRate: Float) -> (sample: Float, newEnvelope: Float)
}

struct CrackleSynthesizer: DischargeSoundSynthesizer {
    mutating func synthesize(phase: Float, phase2: Float, envelope: Float, sampleRate: Float) -> (sample: Float, newEnvelope: Float) {
        let noise = Float.random(in: -1...1)
        let sample = noise * envelope * 0.6
        return (sample, envelope * 0.9997)
    }
}

struct CrystallineChimeSynthesizer: DischargeSoundSynthesizer {
    mutating func synthesize(phase: Float, phase2: Float, envelope: Float, sampleRate: Float) -> (sample: Float, newEnvelope: Float) {
        let d6: Float = 1174.66   // D6
        let d7: Float = 2349.32   // D7
        let a6: Float = 1760.0    // A6
        let a7: Float = 3520.0    // A7
        let t1 = sin(phase * d6 * 2 * .pi) * 0.35
        let t2 = sin(phase * d7 * 2 * .pi) * 0.25
        let t3 = sin(phase * a6 * 2 * .pi) * 0.25
        let t4 = sin(phase * a7 * 2 * .pi) * 0.15
        let sample = (t1 + t2 + t3 + t4) * envelope * 0.5
        return (sample, envelope * 0.99985)
    }
}

struct HarmonicShimmerSynthesizer: DischargeSoundSynthesizer {
    mutating func synthesize(phase: Float, phase2: Float, envelope: Float, sampleRate: Float) -> (sample: Float, newEnvelope: Float) {
        let tp = phase * 2 * .pi
        let s0 = sin(tp * 1800)
        let s1 = sin(tp * 1803)
        let s2 = sin(tp * 1807)
        let s3 = sin(tp * 1811)
        let s4 = sin(tp * 1815)
        let sample = ((s0 + s1 + s2 + s3 + s4) / 5.0) * envelope * 0.5
        return (sample, envelope * 0.9999)
    }
}

struct SingingBowlSynthesizer: DischargeSoundSynthesizer {
    mutating func synthesize(phase: Float, phase2: Float, envelope: Float, sampleRate: Float) -> (sample: Float, newEnvelope: Float) {
        let fundamental: Float = 293.0
        let wobble = 1.0 + sin(phase2 * 5.0 * 2 * .pi) * 0.003
        var sum: Float = 0
        var envPow: Float = 1.0
        for h in 1...5 {
            let hf = Float(h)
            envPow *= envelope
            sum += sin(phase * fundamental * hf * wobble * 2 * .pi) * envPow / hf
        }
        let sample = sum * 0.4
        return (sample, envelope * 0.99995)
    }
}

struct ElectricArcSweepSynthesizer: DischargeSoundSynthesizer {
    mutating func synthesize(phase: Float, phase2: Float, envelope: Float, sampleRate: Float) -> (sample: Float, newEnvelope: Float) {
        let freq = 2500.0 * envelope + 80.0 * (1.0 - envelope)
        let sine = sin(phase * freq * 2 * .pi)
        let noise = Float.random(in: -1...1) * 0.1
        let tremolo = 1.0 + sin(phase2 * 30.0 * 2 * .pi) * 0.3
        let sample = (sine + noise) * tremolo * envelope * 0.5
        return (sample, envelope * 0.9998)
    }
}
