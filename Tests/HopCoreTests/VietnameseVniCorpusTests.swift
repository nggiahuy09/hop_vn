import XCTest
@testable import HopCore

/// The same A/B check for VNI: an encoder that knows nothing about the engine
/// types the corpus with numbers, in the several ways people type VNI.
final class VietnameseVniCorpusTests: XCTestCase {
    private typealias S = VietnameseSpelling
    private typealias Piece = S.Piece

    private enum Style: CaseIterable {
        /// vie6t5 — marks as they come, tone at the end.
        case toneAtEnd
        /// vie65t — tone right after the last vowel, before the final consonant.
        case toneAfterNucleus
        /// the tone typed straight after the letter that carries it.
        case toneAfterToned
        /// viet65 — the marks put on after the whole word, then the tone.
        case marksAtEnd
        /// dau9 — the stroke of đ typed as a 9 after the word.
        case strokeAtEnd
    }

    private func toneKey(_ tone: UInt32?) -> String {
        switch tone {
        case S.acute: return "1"
        case S.grave: return "2"
        case S.hook: return "3"
        case S.tilde: return "4"
        case S.dot: return "5"
        default: return ""
        }
    }

    private func markKey(_ mark: S.Mark) -> String {
        switch mark {
        case .none: return ""
        case .circumflex: return "6"
        case .horn: return "7"
        case .breve: return "8"
        case .stroke: return "9"
        }
    }

    private func inline(_ piece: Piece) -> String { String(piece.letter) + markKey(piece.mark) }

    /// Can the marks go after the word without the engine having to guess which
    /// letter they mean? 6 takes the last a, e or o of the vowels, 7 the last o
    /// or u (or an adjacent u and o together), 8 the last a.
    private func marksCanWait(_ p: [Piece]) -> Bool {
        guard let range = S.nucleus(p) else { return p.allSatisfy { $0.mark == .none || $0.mark == .stroke } }
        let indexes = Array(range)
        func last(of letters: String) -> Int? { indexes.last { letters.contains(S.lower(p[$0].letter)) } }
        let circumflex = indexes.filter { p[$0].mark == .circumflex }
        if circumflex.count > 1 || (circumflex.count == 1 && circumflex[0] != last(of: "aeo")) { return false }
        let breve = indexes.filter { p[$0].mark == .breve }
        if breve.count > 1 || (breve.count == 1 && breve[0] != last(of: "a")) { return false }
        let horn = indexes.filter { p[$0].mark == .horn }
        if horn.count == 2 {
            return horn[1] == horn[0] + 1 && S.lower(p[horn[0]].letter) == "u" && S.lower(p[horn[1]].letter) == "o"
        }
        if horn.count == 1 { return horn[0] == last(of: "ou") }
        return horn.isEmpty
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
                let pairsWithNext = p[i].mark == .horn && i + 1 < p.count && p[i + 1].mark == .horn
                    && S.lower(p[i].letter) == "u" && S.lower(p[i + 1].letter) == "o"
                keys += markKey(p[i].mark)
                if pairsWithNext { i += 1 }
                i += 1
            }
            keys += tone
        case .strokeAtEnd:
            guard p.first?.mark == .stroke else { return nil }
            var rest = p
            rest[0].mark = .none
            keys = rest.map(inline).joined() + "9" + tone
        }
        return keys
    }

    private func encode(_ text: String, style: Style) -> String? {
        S.encode(text) { syllable($0, style: style) }
    }

    private func check(_ words: [String], file: StaticString = #filePath, line: UInt = #line) {
        var failures: [String] = []
        var typed = 0
        for word in words {
            for variant in [word, word.uppercased(), word.prefix(1).uppercased() + word.dropFirst()] {
                for style in Style.allCases {
                    guard let keys = encode(variant, style: style) else { continue }
                    typed += 1
                    let shown = S.screen(keys, .vni)
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
    func testWordsWhoseLettersAreTelexKeys() { check(S.keyLetters) }
    func testPlacesNamesAndPhrases() { check(S.phrases) }
    func testSentencesWithNumbersAndPunctuation() { check(S.sentences) }

    /// In VNI the digits ARE the keys, so a number must survive the engine.
    func testNumbersAreLeftAlone() {
        for text in ["2024", "1 + 2 = 3", "3.14", "0912 345 678", "12/5/2024", "50%", "25.000", "mp3", "h2o", "H264",
                     "iPhone 15", "Quyết định số 1", "Điều 5, khoản 3", "tầng 7", "phòng 305", "#1", "(2)", "1-2-3"] {
            guard let keys = encode(text, style: .toneAtEnd) else { XCTFail("cannot encode \(text)"); continue }
            XCTAssertEqual(S.screen(keys, .vni), text, "typed as \(keys)")
        }
    }

    func testTheEncoderTypesTheWordsTheWayItClaims() {
        XCTAssertEqual(encode("việt", style: .toneAtEnd), "vie6t5")
        XCTAssertEqual(encode("việt", style: .toneAfterNucleus), "vie65t")
        XCTAssertEqual(encode("việt", style: .marksAtEnd), "viet65")
        XCTAssertEqual(encode("được", style: .toneAtEnd), "d9u7o7c5")
        XCTAssertEqual(encode("đó", style: .strokeAtEnd), "do91")
        XCTAssertEqual(encode("người", style: .marksAtEnd), "nguoi72")
    }
}
