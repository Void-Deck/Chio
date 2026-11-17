import Foundation

/// An application-labelled event range without interpretation.
public struct WaveformEvent {
    public static let maximumLabelLength = 16
    public enum Tone {
        case muted, warning, error
    }
    public let start: Duration
    public let duration: Duration
    public let label: String
    public let tone: Tone
    public enum ValidationError {
        case startOutOfRange, nonPositiveDuration, emptyLabel, invalidLabel
    }

    public init(start: Duration, duration: Duration, label: String, tone: Tone) throws(ValidationError) {
        guard start >= .zero, start <= .seconds(Int64.max) else { throw .startOutOfRange }
        guard duration > .zero else { throw .nonPositiveDuration }
        guard !label.isEmpty else { throw .emptyLabel }
        let hasInvalidScalar = label.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0)
        }
        guard label.count <= Self.maximumLabelLength, !hasInvalidScalar else { throw .invalidLabel }
        self.start = start
        self.duration = duration
        self.label = label
        self.tone = tone
    }
}

extension WaveformEvent: Hashable {}
extension WaveformEvent: Sendable {}
extension WaveformEvent.Tone: CaseIterable {}
extension WaveformEvent.Tone: Hashable {}
extension WaveformEvent.Tone: Sendable {}
extension WaveformEvent.ValidationError: Error {}
extension WaveformEvent.ValidationError: Hashable {}
extension WaveformEvent.ValidationError: Sendable {}
