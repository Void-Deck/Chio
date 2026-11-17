/// Signed zero-axis or lower-bound magnitude drawing.
public enum WaveformMode {
    case bipolar, magnitude
}

extension WaveformMode: Hashable {}
extension WaveformMode: Sendable {}
