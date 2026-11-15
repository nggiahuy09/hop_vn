import Foundation

/// How a key press is read while Vietnamese typing is on.
/// SPEC: docs/spec.md — "Vietnamese typing".
public enum VietnameseTypingMethod: String, CaseIterable, Sendable {
    case telex
    case vni
}

/// One word of Vietnamese being typed: the keys go in, the text that should be
/// on screen comes out, and the difference between the two is handed back as an
/// edit. Nothing here touches the keyboard or the screen.
/// Tested by `VietnameseComposerTests`.
public struct VietnameseComposer: Sendable {

    public enum Outcome: Equatable, Sendable {
        /// The key types itself; the word goes on.
        case pass
        /// The key ends the word and types itself.
        case boundary
        /// The key is swallowed: delete this many characters, type this text.
        case replace(delete: Int, insert: String)
        /// The word was not Vietnamese: delete this many characters, type the
        /// keys as they were pressed, and then let the key that ended the word
        /// type itself.
        case fix(delete: Int, insert: String)
    }

    public var method: VietnameseTypingMethod
    /// `false` writes the tone of oa, oe and uy on the first letter (hòa, khỏe,
    /// thủy), as the spelling rules and Unikey do; `true` on the second (hoà,
    /// khoẻ, thuỷ).
    public var modernTonePlacement: Bool

    public static let maxWordLength = 32

    private enum Mark: Sendable { case none, circumflex, breve, horn, stroke }

    private enum Tone: Sendable {
        case none, acute, grave, hook, tilde, dot

        var combining: String {
            switch self {
            case .none: return ""
            case .acute: return "\u{0301}"
            case .grave: return "\u{0300}"
            case .hook: return "\u{0309}"
            case .tilde: return "\u{0303}"
            case .dot: return "\u{0323}"
            }
        }
    }

    private struct Letter: Sendable {
        var base: Character
        var mark: Mark = .none
        var upper: Bool
        /// A ư that a lone `w` made; a second `w` takes it back whole.
        var fromLoneW = false
    }

    private var letters: [Letter] = []
    private var tone: Tone = .none
    /// After a key has been taken back, the rest of the word is typed as it is.
    private var frozen = false
    /// The word cannot be Vietnamese: it is typed as it is, and whatever was
    /// made of it is put back.
    private var foreign = false
    /// The keys of the word as they were pressed.
    private var raw: [Character] = []
    /// Backspace leaves the keys and the letters out of step.
    private var rawReliable = true

    public init(method: VietnameseTypingMethod, modernTonePlacement: Bool = false) {
        self.method = method
        self.modernTonePlacement = modernTonePlacement
    }

    public var text: String { render() }
    public var isEmpty: Bool { letters.isEmpty }

    public mutating func reset() {
        letters = []
        tone = .none
        frozen = false
        foreign = false
        raw = []
        rawReliable = true
    }

    /// The app is about to delete the last character; follow it when the word
    /// can still be told, give the word up when it cannot.
    public mutating func backspace() {
        guard !letters.isEmpty else { return }
        let expected = String(text.dropLast())
        letters.removeLast()
        rawReliable = false
        if vowelRange() == nil { tone = .none }
        if letters.isEmpty || text != expected { reset() }
    }

    public mutating func push(_ char: Character) -> Outcome {
        guard let code = char.asciiValue else { return boundary(fixing: false) }
        let isUpper = code >= 65 && code <= 90
        let isLetter = isUpper || (code >= 97 && code <= 122)
        let isDigit = code >= 48 && code <= 57
        guard isLetter || isDigit else {
            // a space, a punctuation mark, return or tab: the keys that end a word
            return boundary(fixing: code == 9 || code == 10 || code == 13 || (32...126).contains(code))
        }

        if letters.count >= Self.maxWordLength { reset() }
        let key = Character(char.lowercased())
        let before = text
        raw.append(char)
        let handled = !frozen && !foreign && transform(key, upper: isUpper)
        if !handled {
            if isDigit {
                raw.removeLast()
                return boundary(fixing: true)
            }
            letters.append(Letter(base: key, upper: isUpper))
        }
        settleIfForeign()
        return outcome(from: before, typed: char)
    }

    /// A word that has ended is put back as it was typed when it is not a
    /// Vietnamese syllable; `fixing` is false for the keys that merely move on.
    private mutating func boundary(fixing: Bool) -> Outcome {
        defer { reset() }
        guard fixing, !frozen, rawReliable, !letters.isEmpty else { return .boundary }
        let shown = text
        let typed = String(raw)
        guard shown != typed, !isComplete() else { return .boundary }
        return .fix(delete: shown.count, insert: typed)
    }

    /// The word has gone somewhere no Vietnamese syllable goes: from here it is
    /// typed as it is, and what the keys had made of it is put back at once.
    private mutating func settleIfForeign() {
        guard !frozen, !foreign, !isViable() else { return }
        foreign = true
        guard rawReliable, text != String(raw) else { return }
        letters = raw.map { Letter(base: Character($0.lowercased()), upper: $0.isUppercase) }
        tone = .none
    }

    private func outcome(from before: String, typed: Character) -> Outcome {
        let old = Array(before)
        let new = Array(text)
        var common = 0
        while common < old.count, common < new.count, old[common] == new[common] { common += 1 }
        let insert = String(new[common...])
        if common == old.count, insert == String(typed) { return .pass }
        return .replace(delete: old.count - common, insert: insert)
    }

    // MARK: - Reading a key

    private mutating func transform(_ key: Character, upper: Bool) -> Bool {
        switch method {
        case .telex:
            switch key {
            case "s": return setTone(.acute, key, upper)
            case "f": return setTone(.grave, key, upper)
            case "r": return setTone(.hook, key, upper)
            case "x": return setTone(.tilde, key, upper)
            case "j": return setTone(.dot, key, upper)
            case "z": return clearTone()
            case "a", "e", "o": return circumflex(only: key, key, upper)
            case "w": return telexW(upper)
            case "d": return stroke(freeAfterVowels: true, key, upper)
            default: return false
            }
        case .vni:
            switch key {
            case "1": return setTone(.acute, key, upper)
            case "2": return setTone(.grave, key, upper)
            case "3": return setTone(.hook, key, upper)
            case "4": return setTone(.tilde, key, upper)
            case "5": return setTone(.dot, key, upper)
            case "0": return clearTone()
            case "6": return circumflex(only: nil, key, upper)
            case "7": return horn(allowed: "ou", pairs: true, key, upper)
            case "8": return horn(allowed: "a", pairs: false, key, upper)
            case "9": return stroke(freeAfterVowels: nil, key, upper)
            default: return false
            }
        }
    }

    /// Taking a mark or a tone back types the key that asked for it, and from
    /// there the word is left alone.
    private mutating func undo(_ key: Character, _ upper: Bool) {
        letters.append(Letter(base: key, upper: upper))
        frozen = true
    }

    private mutating func setTone(_ new: Tone, _ key: Character, _ upper: Bool) -> Bool {
        guard vowelRange() != nil else { return false }
        if tone == new {
            tone = .none
            undo(key, upper)
        } else {
            tone = new
        }
        return true
    }

    private mutating func clearTone() -> Bool {
        guard tone != .none, vowelRange() != nil else { return false }
        tone = .none
        return true
    }

    /// â ê ô. Telex asks for the same letter twice, and only the last vowel of
    /// the word may take it; VNI's 6 takes the last a, e or o.
    private mutating func circumflex(only base: Character?, _ key: Character, _ upper: Bool) -> Bool {
        guard let range = vowelRange() else { return false }
        let index: Int
        if let base {
            guard letters[range.upperBound - 1].base == base else { return false }
            index = range.upperBound - 1
        } else {
            guard let found = range.reversed().first(where: { "aeo".contains(letters[$0].base) })
            else { return false }
            index = found
        }
        switch letters[index].mark {
        case .none:
            letters[index].mark = .circumflex
        case .circumflex:
            letters[index].mark = .none
            undo(key, upper)
        default:
            return false
        }
        return true
    }

    private mutating func telexW(_ upper: Bool) -> Bool {
        if let range = vowelRange() {
            return horn(allowed: "aou", pairs: true, "w", upper, range: range)
        }
        letters.append(Letter(base: "u", mark: .horn, upper: upper, fromLoneW: true))
        return true
    }

    /// ơ ư, and ă for the a. A u beside an o takes the horn with it: ươ.
    private mutating func horn(allowed: String, pairs: Bool, _ key: Character, _ upper: Bool,
                               range given: Range<Int>? = nil) -> Bool {
        guard let range = given ?? vowelRange() else { return false }
        if pairs, let u = (range.lowerBound..<range.upperBound - 1).first(where: { pairedUO($0) }) {
            if letters[u].mark == .horn, letters[u + 1].mark == .horn {
                letters[u].mark = .none
                letters[u + 1].mark = .none
                undo(key, upper)
            } else {
                letters[u].mark = .horn
                letters[u + 1].mark = .horn
            }
            return true
        }
        // ua has no breve: a w after it is the horn of the u (mưa, đưa)
        if allowed.contains("a"), pairs,
           let u = (range.lowerBound..<range.upperBound - 1).first(where: { pairedUA($0) }) {
            if letters[u].mark == .horn {
                letters[u].mark = .none
                undo(key, upper)
            } else {
                letters[u].mark = .horn
            }
            return true
        }
        guard let index = range.reversed().first(where: { allowed.contains(letters[$0].base) })
        else { return false }
        let wanted: Mark = letters[index].base == "a" ? .breve : .horn
        if letters[index].mark == .none {
            letters[index].mark = wanted
        } else if letters[index].mark == wanted {
            if letters[index].fromLoneW {
                letters.remove(at: index)
            } else {
                letters[index].mark = .none
            }
            undo(key, upper)
        } else {
            return false
        }
        return true
    }

    private func pairedUA(_ i: Int) -> Bool {
        let u = letters[i], a = letters[i + 1]
        return u.base == "u" && a.base == "a" && (u.mark == .none || u.mark == .horn) && a.mark == .none
    }

    private func pairedUO(_ i: Int) -> Bool {
        let u = letters[i], o = letters[i + 1]
        return u.base == "u" && o.base == "o"
            && (u.mark == .none || u.mark == .horn)
            && (o.mark == .none || o.mark == .horn)
    }

    /// đ. Telex takes the second d right after the first, or after the vowels
    /// that follow it (`dods` → đó), but not after a consonant; VNI's 9 may
    /// come anywhere in the word (`freeAfterVowels` nil). Pressing it again takes
    /// the stroke back.
    private mutating func stroke(freeAfterVowels: Bool?, _ key: Character, _ upper: Bool) -> Bool {
        guard let first = letters.first, first.base == "d" else { return false }
        if let strict = freeAfterVowels, strict, letters.count > 1, vowelRange()?.lowerBound != 1 {
            return false
        }
        switch first.mark {
        case .none:
            letters[0].mark = .stroke
        case .stroke:
            letters[0].mark = .none
            undo(key, upper)
        default:
            return false
        }
        return true
    }

    // MARK: - Where the tone goes

    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]

    /// The vowels of the syllable being typed. The u of qu and the i of gi are
    /// consonants while a vowel follows them.
    private func vowelRange() -> Range<Int>? {
        var isVowel = letters.map { Self.vowels.contains($0.base) }
        var i = 1
        while i + 1 < letters.count {
            if isVowel[i], isVowel[i + 1] {
                let previous = letters[i - 1].base
                if (letters[i].base == "u" && previous == "q") || (letters[i].base == "i" && previous == "g") {
                    isVowel[i] = false
                }
            }
            i += 1
        }
        guard let last = isVowel.lastIndex(of: true) else { return nil }
        var first = last
        while first > 0, isVowel[first - 1] { first -= 1 }
        return first..<last + 1
    }

    private func tonePosition(_ range: Range<Int>) -> Int {
        let indexes = Array(range)
        if indexes.count == 1 { return indexes[0] }
        if let marked = indexes.last(where: { letters[$0].mark != .none }) { return marked }
        if indexes.count == 2 {
            if range.upperBound < letters.count { return indexes[1] }
            let pair = String([letters[indexes[0]].base, letters[indexes[1]].base])
            if modernTonePlacement, ["oa", "oe", "uy"].contains(pair) { return indexes[1] }
            return indexes[0]
        }
        return indexes[1]
    }

    // MARK: - The text

    private func render() -> String {
        let range = vowelRange()
        let toneIndex = tone == .none ? nil : range.map(tonePosition)
        var out = ""
        for (index, letter) in letters.enumerated() {
            var piece = glyph(letter)
            if index == toneIndex { piece = (piece + tone.combining).precomposedStringWithCanonicalMapping }
            out += letter.upper ? piece.uppercased() : piece
        }
        return out
    }

    /// The letter with its mark and without a tone, in lower case.
    private func glyph(_ letter: Letter) -> String {
        var piece = String(letter.base)
        switch letter.mark {
        case .none: return piece
        case .circumflex: piece += "\u{0302}"
        case .breve: piece += "\u{0306}"
        case .horn: piece += "\u{031B}"
        case .stroke: return "đ"
        }
        return piece.precomposedStringWithCanonicalMapping
    }

    // MARK: - Is it Vietnamese

    private func parts() -> (onset: String, nucleus: String, coda: String) {
        func plain(_ slice: ArraySlice<Letter>) -> String { slice.map(glyph).joined() }
        guard let range = vowelRange() else { return (plain(letters[...]), "", "") }
        return (plain(letters[..<range.lowerBound]), plain(letters[range]), plain(letters[range.upperBound...]))
    }

    private var toneSuitsAStop: Bool { tone == .none || tone == .acute || tone == .dot }

    private func isViable() -> Bool {
        let (onset, nucleus, coda) = parts()
        return VietnameseSyllable.isViable(onset: onset, nucleus: nucleus, coda: coda, stopSafeTone: toneSuitsAStop)
    }

    private func isComplete() -> Bool {
        let (onset, nucleus, coda) = parts()
        return VietnameseSyllable.isComplete(onset: onset, nucleus: nucleus, coda: coda, stopSafeTone: toneSuitsAStop)
    }
}
