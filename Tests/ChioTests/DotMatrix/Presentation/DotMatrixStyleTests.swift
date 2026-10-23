import Chio
import Foundation
import SwiftTUIRuntime
import Testing

struct DotMatrixStyleTests {
    @Test("Style defaults and checked gap endpoints remain immutable values")
    func values() throws {
        let style = try DotMatrixStyle()
        #expect(style.shape == .round)
        #expect(style.horizontalGap == 1)
        #expect(style.verticalGap == 0)
        #expect(style.unlitColor == nil)
        let override = try DotMatrixStyle(shape: .square, horizontalGap: 0, verticalGap: 8,
                                          unlitColor: .cyan)
        let decoded = try JSONDecoder().decode(DotMatrixStyle.self, from: JSONEncoder().encode(override))
        #expect(decoded == override)
        #expect(Set([decoded, override]).count == 1)
        #expect(style.horizontalGap == 1)
        #expect(try JSONDecoder().decode(DotMatrixStyle.self, from: JSONEncoder().encode(style)) == style)
        func requiresSendable<Value: Sendable>(_: Value) {}
        requiresSendable(override)
    }

    @Test("Each gap rejects negative, excessive and extreme distances")
    func invalidGaps() {
        for invalid in [-1, 9, Int.min, Int.max] {
            #expect(throws: DotMatrixStyle.ValidationError.horizontalGapOutOfRange) {
                try DotMatrixStyle(horizontalGap: invalid)
            }
            #expect(throws: DotMatrixStyle.ValidationError.verticalGapOutOfRange) {
                try DotMatrixStyle(verticalGap: invalid)
            }
        }
    }

    @Test("Decoded styles cannot bypass either gap bound")
    func invalidDecoding() throws {
        for key in ["horizontalGap", "verticalGap"] {
            for invalid in [-1, 9, Int.min, Int.max] {
                let json = "{\"shape\":\"round\",\"horizontalGap\":1,\"verticalGap\":0}"
                let valid = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
                var malformed = valid
                malformed[key] = invalid
                let encoded = try JSONSerialization.data(withJSONObject: malformed)
                #expect(throws: DecodingError.self) {
                    try JSONDecoder().decode(DotMatrixStyle.self, from: encoded)
                }
            }
        }
    }
}
