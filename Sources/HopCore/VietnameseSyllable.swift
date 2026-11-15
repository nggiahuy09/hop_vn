import Foundation

/// What a Vietnamese syllable can be made of: an onset, a vowel group and a
/// final consonant, with a tone that the final consonant may rule out. It
/// decides whether a word that is being typed can still be Vietnamese, so that
/// the one that cannot (`clear`, `show`, `good`) is left as it was typed.
///
/// Lenient on purpose: taking a Vietnamese word for a foreign one costs the
/// person their word, the other mistake costs a word of English a stray mark.
/// SPEC: docs/spec.md — "Vietnamese typing", words that are not Vietnamese.
/// Tested by `VietnameseSyllableTests`.
public enum VietnameseSyllable {

    static let onsets: Set<String> = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh", "nh",
        "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
    ]

    static let onsetPrefixes: Set<String> = {
        var all: Set<String> = [""]
        for onset in onsets {
            for length in 1...max(onset.count, 1) { all.insert(String(onset.prefix(length))) }
        }
        return all
    }()

    /// Written with its marks and without a tone: `ươ`, `uyê`. `uă` is no
    /// native vowel group; it is let through all the same, because a name or a
    /// slip of the finger should not lose its mark.
    static let nuclei: [String] = [
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
        "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iê", "iu", "oa", "oă", "oe", "oi", "ôi",
        "ơi", "ua", "uă", "uâ", "uê", "ui", "uô", "uơ", "uy", "ưa", "ươ", "ưi", "ưu", "yê",
        "iêu", "yêu", "oai", "oay", "oeo", "uây", "uôi", "uya", "uyê", "uyu", "ươi", "ươu",
    ]

    /// Vowel groups that end the syllable.
    static let openOnly: Set<String> = [
        "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iu", "oi", "ôi", "ơi", "ua", "ui", "uơ",
        "ưa", "ưi", "ưu", "iêu", "yêu", "oai", "oay", "oeo", "uây", "uôi", "uya", "uyu", "ươi", "ươu",
    ]

    private static let stopCodas: Set<String> = ["c", "ch", "p", "t"]

    static func base(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil)
    }

    private static func allowedCodas(_ nucleus: String) -> Set<String> {
        if openOnly.contains(nucleus) { return [] }
        var codas: Set<String> = ["c", "m", "n", "p", "t"]
        if ["a", "e", "i", "y", "oa", "oe", "uy", "ue"].contains(base(nucleus)) { codas.formUnion(["ch", "nh"]) }
        if !["i", "y", "ơ", "uy", "uê", "yê"].contains(nucleus) { codas.insert("ng") }
        if nucleus == "ă" { codas.insert("k") }
        return codas
    }

    /// Could this still become a Vietnamese syllable with more keys? A mark
    /// that has not been typed yet is allowed for: `tuan` may become `tuân`.
    /// `stopSafeTone` is whether the tone is one a final c, ch, p or t takes.
    public static func isViable(onset: String, nucleus: String, coda: String, stopSafeTone: Bool) -> Bool {
        // đc, đt, đ (for đồng): a consonant with a stroke on it is an abbreviation
        if nucleus.isEmpty { return coda.isEmpty && (onsetPrefixes.contains(onset) || onset.hasPrefix("đ")) }
        let typed = base(nucleus)
        guard onsets.contains(onset) || (onset == "q" && typed == "u" && coda.isEmpty) else { return false }
        let candidates = nuclei.filter { base($0).hasPrefix(typed) }
        guard !candidates.isEmpty else { return false }
        if coda.isEmpty { return true }
        if stopCodas.contains(coda), !stopSafeTone { return false }
        return candidates.contains { candidate in
            base(candidate) == typed && allowedCodas(candidate).contains { $0.hasPrefix(coda) }
        }
    }

    /// Is this a whole Vietnamese syllable?
    public static func isComplete(onset: String, nucleus: String, coda: String, stopSafeTone: Bool) -> Bool {
        // letters with no vowel can only have been changed by the stroke of đ
        if nucleus.isEmpty { return true }
        guard onsets.contains(onset), nuclei.contains(nucleus) else { return false }
        if coda.isEmpty { return true }
        if stopCodas.contains(coda), !stopSafeTone { return false }
        return allowedCodas(nucleus).contains(coda)
    }
}
