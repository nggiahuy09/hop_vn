import XCTest
@testable import HopCore

/// A/B check of the Telex engine: A is the keys a person types, B is the
/// Vietnamese they meant. An encoder that knows nothing about the engine types
/// each word of the corpus in the several ways people really type Telex; the
/// engine has to give the word again, whatever the way.
final class VietnameseTelexCorpusTests: XCTestCase {
    private typealias S = VietnameseSpelling
    private typealias Piece = S.Piece

    private enum Style: CaseIterable {
        /// vieetj — marks as they come, tone at the end.
        case toneAtEnd
        /// vieejt — tone right after the last vowel, before the final consonant.
        case toneAfterNucleus
        /// the tone typed straight after the letter that carries it.
        case toneAfterToned
        /// the marks put on after the whole word, then the tone.
        case marksAtEnd
        /// dods — the stroke of đ typed as a d after the word.
        case strokeAtEnd
    }

    private func toneKey(_ tone: UInt32?) -> String {
        switch tone {
        case S.acute: return "s"
        case S.grave: return "f"
        case S.hook: return "r"
        case S.tilde: return "x"
        case S.dot: return "j"
        default: return ""
        }
    }

    private func inline(_ piece: Piece) -> String {
        var keys = String(piece.letter)
        switch piece.mark {
        case .none: break
        case .circumflex: keys.append(S.lower(piece.letter))
        case .breve, .horn: keys.append("w")
        case .stroke: keys.append("d")
        }
        return keys
    }

    /// Can the marks go after the word without the engine having to guess which
    /// letter they mean? The engine takes a circumflex only on the last vowel,
    /// and a w on the last a, o or u (or on an adjacent u and o together).
    private func marksCanWait(_ p: [Piece]) -> Bool {
        guard let range = S.nucleus(p) else { return p.allSatisfy { $0.mark == .none || $0.mark == .stroke } }
        let indexes = Array(range)
        for i in indexes where p[i].mark == .circumflex {
            // it goes to the last unmarked vowel of its letter
            if indexes.contains(where: { $0 > i && p[$0].mark == .none && S.lower(p[$0].letter) == S.lower(p[i].letter) }) {
                return false
            }
        }
        let hornLike = indexes.filter { p[$0].mark == .horn || p[$0].mark == .breve }
        if hornLike.count > 1 {
            let pair = hornLike.count == 2 && hornLike[1] == hornLike[0] + 1
                && S.lower(p[hornLike[0]].letter) == "u" && S.lower(p[hornLike[1]].letter) == "o"
            if !pair { return false }
        }
        if hornLike.count == 1, let only = hornLike.first {
            let targets = indexes.filter { "aou".contains(S.lower(p[$0].letter)) }
            let hornOfUa = S.lower(p[only].letter) == "u" && only + 1 < p.count
                && S.lower(p[only + 1].letter) == "a" && p[only + 1].mark == .none
            if only != targets.last && !hornOfUa { return false }
        }
        return true
    }

    private func syllable(_ source: String, style: Style) -> String? {
        guard let p = S.pieces(source) else { return nil }
        let tone = toneKey(p.compactMap(\.tone).first)
        let tonedIndex = p.firstIndex { $0.tone != nil }
        var keys = ""
        switch style {
        case .toneAtEnd:
            keys = p.map(inline).joined() + tone
        case .toneAfterNucleus:
            let end = S.nucleus(p)?.upperBound
            for (i, piece) in p.enumerated() {
                keys += inline(piece)
                if i + 1 == end { keys += tone }
            }
        case .toneAfterToned:
            for (i, piece) in p.enumerated() {
                keys += inline(piece)
                if i == tonedIndex { keys += tone }
            }
        case .marksAtEnd:
            guard marksCanWait(p) else { return p.map(inline).joined() + tone }
            keys = String(p.map(\.letter))
            var i = 0
            while i < p.count {
                switch p[i].mark {
                case .circumflex: keys.append(S.lower(p[i].letter))
                case .breve: keys.append("w")
                case .horn:
                    let pairsWithNext = i + 1 < p.count && p[i + 1].mark == .horn
                        && S.lower(p[i].letter) == "u" && S.lower(p[i + 1].letter) == "o"
                    keys.append("w")
                    if pairsWithNext { i += 1 }
                case .stroke: keys.append("d")
                case .none: break
                }
                i += 1
            }
            keys += tone
        case .strokeAtEnd:
            guard p.first?.mark == .stroke else { return nil }
            var rest = p
            rest[0].mark = .none
            keys = rest.map(inline).joined() + "d" + tone
        }
        return keys
    }

    private func encode(_ text: String, style: Style) -> String? {
        S.encode(text) { syllable($0, style: style) }
    }

    /// Every style and the three casings; one failure message lists what went
    /// wrong instead of a hundred.
    private func check(_ words: [String], file: StaticString = #filePath, line: UInt = #line) {
        var failures: [String] = []
        var typed = 0
        for word in words {
            for variant in [word, word.uppercased(), word.prefix(1).uppercased() + word.dropFirst()] {
                for style in Style.allCases {
                    guard let keys = encode(variant, style: style) else { continue }
                    typed += 1
                    let shown = S.screen(keys, .telex)
                    if shown != variant { failures.append("\(style) \(keys) → \(shown) (want \(variant))") }
                }
            }
        }
        XCTAssertGreaterThan(typed, words.count, "the encoder produced almost nothing", file: file, line: line)
        XCTAssertTrue(failures.isEmpty,
                      "\(failures.count) of \(typed) failed:\n" + failures.prefix(60).joined(separator: "\n"),
                      file: file, line: line)
    }

    func testSingleVowelsAndEveryTone() { check(S.singleVowels) }
    func testDiphthongsAndTriphthongs() { check(S.vowelGroups) }
    func testEveryFinalConsonant() { check(S.finalConsonants) }
    func testConsonantClustersAndInitials() { check(S.initials) }
    func testWordsWhoseLettersAreToneOrMarkKeys() { check(S.keyLetters) }
    func testPlacesNamesAndPhrases() { check(S.phrases) }
    func testSentences() { check(S.sentences) }

    func testTheEncoderTypesTheWordsTheWayItClaims() {
        XCTAssertEqual(encode("việt", style: .toneAtEnd), "vieetj")
        XCTAssertEqual(encode("việt", style: .toneAfterNucleus), "vieejt")
        XCTAssertEqual(encode("đó", style: .strokeAtEnd), "dods")
        XCTAssertEqual(encode("được", style: .toneAtEnd), "dduwowcj")
        XCTAssertEqual(encode("tiếng", style: .marksAtEnd), "tienges")
        XCTAssertEqual(encode("người", style: .marksAtEnd), "nguoiwf")
        XCTAssertEqual(encode("ĐƯỢC", style: .toneAtEnd), "DdUwOwCj")
    }
}
