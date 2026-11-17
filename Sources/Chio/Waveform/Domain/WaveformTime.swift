/// Converts relative waveform durations while retaining subsecond offsets.
enum WaveformTime {
    static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
