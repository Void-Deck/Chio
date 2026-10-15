extension ChioStyle {
    /// Insets and gaps measured in terminal cells.
    /// Input and list-row distances have a finite 0...32-cell styling bound;
    /// the original four distances retain their nonnegative contract.
    public struct Spacing {
        public let horizontalInset: Int
        public let verticalInset: Int
        public let sectionGap: Int
        public let hintGap: Int
        /// Native text-field padding, bounded to 0...32 terminal cells.
        public let inputVerticalInset: Int
        /// Padding above and below each Chio searchable-list or checklist row.
        /// Native `List` rows can apply this value through ordinary padding.
        public let listRowVerticalInset: Int

        public init(
            horizontalInset: Int = 1,
            verticalInset: Int = 0,
            sectionGap: Int = 1,
            hintGap: Int = 2,
            inputVerticalInset: Int = 0,
            listRowVerticalInset: Int = 0
        ) {
            let isHorizontalInsetNonnegative = horizontalInset >= 0
            let isVerticalInsetNonnegative = verticalInset >= 0
            let isSectionGapNonnegative = sectionGap >= 0
            let isHintGapNonnegative = hintGap >= 0
            precondition(isHorizontalInsetNonnegative && isVerticalInsetNonnegative
                         && isSectionGapNonnegative && isHintGapNonnegative,
                         "Style spacing must be nonnegative")
            let isInputInsetBounded = (0...32).contains(inputVerticalInset)
            precondition(isInputInsetBounded,
                         "Input spacing must be in 0...32 terminal cells")
            let isListRowInsetBounded = (0...32).contains(listRowVerticalInset)
            precondition(isListRowInsetBounded,
                         "List row spacing must be in 0...32 terminal cells")
            self.horizontalInset = horizontalInset
            self.verticalInset = verticalInset
            self.sectionGap = sectionGap
            self.hintGap = hintGap
            self.inputVerticalInset = inputVerticalInset
            self.listRowVerticalInset = listRowVerticalInset
        }

        /// Returns checked spacing; omitted distances retain their current values.
        public func replacing(
            horizontalInset: Int? = nil,
            verticalInset: Int? = nil,
            sectionGap: Int? = nil,
            hintGap: Int? = nil,
            inputVerticalInset: Int? = nil,
            listRowVerticalInset: Int? = nil
        ) -> Self {
            Spacing(horizontalInset: horizontalInset ?? self.horizontalInset,
                    verticalInset: verticalInset ?? self.verticalInset,
                    sectionGap: sectionGap ?? self.sectionGap, hintGap: hintGap ?? self.hintGap,
                    inputVerticalInset: inputVerticalInset ?? self.inputVerticalInset,
                    listRowVerticalInset: listRowVerticalInset ?? self.listRowVerticalInset)
        }
    }
}

extension ChioStyle.Spacing: Decodable {
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let horizontalInset = try values.decode(Int.self, forKey: .horizontalInset)
        let verticalInset = try values.decode(Int.self, forKey: .verticalInset)
        let sectionGap = try values.decode(Int.self, forKey: .sectionGap)
        let hintGap = try values.decode(Int.self, forKey: .hintGap)
        func boundedDistance(for key: CodingKeys) throws -> Int {
            let distance = values.contains(key) ? try values.decode(Int.self, forKey: key) : 0
            guard (0...32).contains(distance) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: values,
                    debugDescription: "Spacing must be in 0...32 terminal cells"
                )
            }
            return distance
        }
        let distances: [(CodingKeys, Int)] = [
            (.horizontalInset, horizontalInset), (.verticalInset, verticalInset),
            (.sectionGap, sectionGap), (.hintGap, hintGap),
        ]
        for (key, distance) in distances where distance < 0 {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: values, debugDescription: "Style spacing must be nonnegative"
            )
        }
        self.init(horizontalInset: horizontalInset, verticalInset: verticalInset,
                  sectionGap: sectionGap, hintGap: hintGap,
                  inputVerticalInset: try boundedDistance(for: .inputVerticalInset),
                  listRowVerticalInset: try boundedDistance(for: .listRowVerticalInset))
    }
}

extension ChioStyle.Spacing: Encodable {}
extension ChioStyle.Spacing: Equatable {}
extension ChioStyle.Spacing: Hashable {}
extension ChioStyle.Spacing: Sendable {}
