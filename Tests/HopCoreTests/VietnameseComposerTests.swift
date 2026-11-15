import XCTest
@testable import HopCore

final class VietnameseComposerTests: XCTestCase {

    /// Types the keys the way the app does: a swallowed key becomes an edit, any
    /// other key lands as it is. What is returned is what the screen would show.
    private func typed(_ keys: String, _ method: VietnameseTypingMethod = .telex,
                       modern: Bool = false) -> String {
        var composer = VietnameseComposer(method: method, modernTonePlacement: modern)
        var screen: [Character] = []
        for key in keys { apply(composer.push(key), key, to: &screen) }
        return String(screen)
    }

    /// The same, with a space after the last key: the word is over, and a word
    /// that is not Vietnamese is put back.
    private func typedAndEnded(_ keys: String, _ method: VietnameseTypingMethod = .telex) -> String {
        var composer = VietnameseComposer(method: method)
        var screen: [Character] = []
        for key in keys + " " { apply(composer.push(key), key, to: &screen) }
        return String(screen.dropLast())
    }

    private func apply(_ outcome: VietnameseComposer.Outcome, _ key: Character, to screen: inout [Character]) {
        switch outcome {
        case .pass, .boundary:
            screen.append(key)
        case .replace(let delete, let insert):
            screen.removeLast(delete)
            screen.append(contentsOf: insert)
        case .fix(let delete, let insert):
            screen.removeLast(delete)
            screen.append(contentsOf: insert)
            screen.append(key)
        }
    }

    // MARK: - Telex

    func testTelexToneKeys() {
        XCTAssertEqual(typed("as"), "á")
        XCTAssertEqual(typed("af"), "à")
        XCTAssertEqual(typed("ar"), "ả")
        XCTAssertEqual(typed("ax"), "ã")
        XCTAssertEqual(typed("aj"), "ạ")
        XCTAssertEqual(typed("asz"), "a")
    }

    func testTelexMarks() {
        XCTAssertEqual(typed("aa"), "â")
        XCTAssertEqual(typed("ee"), "ê")
        XCTAssertEqual(typed("oo"), "ô")
        XCTAssertEqual(typed("aw"), "ă")
        XCTAssertEqual(typed("ow"), "ơ")
        XCTAssertEqual(typed("uw"), "ư")
        XCTAssertEqual(typed("dd"), "đ")
    }

    func testTelexWords() {
        XCTAssertEqual(typed("vieetj"), "việt")
        XCTAssertEqual(typed("tieengs"), "tiếng")
        XCTAssertEqual(typed("dduwowcj"), "được")
        XCTAssertEqual(typed("nguwowfi"), "người")
        XCTAssertEqual(typed("nguoiwf"), "người")
        XCTAssertEqual(typed("khoongr"), "khổng")
        XCTAssertEqual(typed("chaof"), "chào")
        XCTAssertEqual(typed("toans"), "toán")
        XCTAssertEqual(typed("ngoaif"), "ngoài")
        XCTAssertEqual(typed("khuyeens"), "khuyến")
        XCTAssertEqual(typed("quyeenf"), "quyền")
        XCTAssertEqual(typed("muwa"), "mưa")
        XCTAssertEqual(typed("mwa"), "mưa")
        XCTAssertEqual(typed("hocj"), "học")
    }

    func testTelexPhraseResetsAtTheSpace() {
        XCTAssertEqual(typed("Vieetj Nam"), "Việt Nam")
        XCTAssertEqual(typed("xin chaof cacs banj"), "xin chào các bạn")
    }

    func testCaseFollowsTheLetters() {
        XCTAssertEqual(typed("Vieetj"), "Việt")
        XCTAssertEqual(typed("VIEETJ"), "VIỆT")
        XCTAssertEqual(typed("Ddi"), "Đi")
        XCTAssertEqual(typed("DDI"), "ĐI")
        XCTAssertEqual(typed("AS"), "Á")
    }

    func testQuAndGiAreConsonantsBeforeAVowel() {
        XCTAssertEqual(typed("quas"), "quá")
        XCTAssertEqual(typed("quys"), "quý")
        XCTAssertEqual(typed("giaf"), "già")
        XCTAssertEqual(typed("giowf"), "giờ")
        XCTAssertEqual(typed("gif"), "gì")
        XCTAssertEqual(typed("quow"), "quơ")
    }

    func testTonePlacementStyle() {
        XCTAssertEqual(typed("hoaf", modern: true), "hoà")
        XCTAssertEqual(typed("hoaf", modern: false), "hòa")
        XCTAssertEqual(typed("khoer", modern: true), "khoẻ")
        XCTAssertEqual(typed("khoer", modern: false), "khỏe")
        XCTAssertEqual(typed("thuyr", modern: true), "thuỷ")
        XCTAssertEqual(typed("thuyr", modern: false), "thủy")
        XCTAssertEqual(typed("hoanf", modern: false), "hoàn")
    }

    func testTonesSitOnTheRightVowel() {
        XCTAssertEqual(typed("masi"), "mái")
        XCTAssertEqual(typed("muas"), "múa")
        XCTAssertEqual(typed("kias"), "kía")
        XCTAssertEqual(typed("hoanf"), "hoàn")
        XCTAssertEqual(typed("huynhf"), "huỳnh")
        XCTAssertEqual(typed("cuoois"), "cuối")
        XCTAssertEqual(typed("rwowuj"), "rượu")
    }

    func testAKeyPressedAgainIsTakenBack() {
        XCTAssertEqual(typed("aaa"), "aa")
        XCTAssertEqual(typed("ass"), "as")
        XCTAssertEqual(typed("ddd"), "dd")
        XCTAssertEqual(typed("dodd"), "dod")
        XCTAssertEqual(typed("oww"), "ow")
        XCTAssertEqual(typed("ww"), "w")
        XCTAssertEqual(typed("uoww"), "uow")
    }

    func testTheSecondDMayComeAfterTheVowels() {
        XCTAssertEqual(typed("dods"), "đó")
        XCTAssertEqual(typed("ddos"), "đó")
        XCTAssertEqual(typed("dod"), "đo")
        XCTAssertEqual(typed("daud"), "đau")
        XCTAssertEqual(typed("dongd"), "đong")
        XCTAssertEqual(typed("duwowcj"), "dược")
        XCTAssertEqual(typed("duwowcdj"), "được")
        XCTAssertEqual(typed("Dods"), "Đó")
    }

    func testTheSecondDDoesNotReachPastAConsonant() {
        XCTAssertEqual(typed("drd"), "drd")
        XCTAssertEqual(typed("adding"), "adding")
        XCTAssertEqual(typed("ddod"), "dod")
    }

    func testAfterATakeBackTheWordIsLeftAlone() {
        XCTAssertEqual(typed("aaaa"), "aaa")
        XCTAssertEqual(typed("asss"), "ass")
        XCTAssertEqual(typed("asssf"), "assf")
    }

    func testAWToneAndMarkReplaceEachOther() {
        XCTAssertEqual(typed("asf"), "à")
        XCTAssertEqual(typed("asw"), "ắ")
        XCTAssertEqual(typed("awf"), "ằ")
    }

    func testWordsThatAreNotVietnameseSurviveWhereTheyCan() {
        XCTAssertEqual(typed("new"), "new")
        XCTAssertEqual(typed("adding"), "adding")
        XCTAssertEqual(typed("hello"), "hello")
        XCTAssertEqual(typed("sdf"), "sdf")
    }

    func testDigitsAndPunctuationEndTheWord() {
        XCTAssertEqual(typed("as2024"), "á2024")
        XCTAssertEqual(typed("as, as"), "á, á")
        XCTAssertEqual(typed("a.s"), "a.s")
    }

    // MARK: - VNI

    func testVniWords() {
        XCTAssertEqual(typed("viet65", .vni), "việt")
        XCTAssertEqual(typed("Viet65", .vni), "Việt")
        XCTAssertEqual(typed("tie6ng1", .vni), "tiếng")
        XCTAssertEqual(typed("d9uoc75", .vni), "được")
        XCTAssertEqual(typed("ngu7o7i2", .vni), "người")
        XCTAssertEqual(typed("ngu7oi72", .vni), "người")
        XCTAssertEqual(typed("chao2", .vni), "chào")
        XCTAssertEqual(typed("toan1", .vni), "toán")
        XCTAssertEqual(typed("d9i", .vni), "đi")
        XCTAssertEqual(typed("di9", .vni), "đi")
        XCTAssertEqual(typed("xin chao2 cac1 ban5", .vni), "xin chào các bạn")
    }

    func testVniMarksAndTones() {
        XCTAssertEqual(typed("a1", .vni), "á")
        XCTAssertEqual(typed("a2", .vni), "à")
        XCTAssertEqual(typed("a3", .vni), "ả")
        XCTAssertEqual(typed("a4", .vni), "ã")
        XCTAssertEqual(typed("a5", .vni), "ạ")
        XCTAssertEqual(typed("a6", .vni), "â")
        XCTAssertEqual(typed("e6", .vni), "ê")
        XCTAssertEqual(typed("o6", .vni), "ô")
        XCTAssertEqual(typed("o7", .vni), "ơ")
        XCTAssertEqual(typed("u7", .vni), "ư")
        XCTAssertEqual(typed("a8", .vni), "ă")
        XCTAssertEqual(typed("d9", .vni), "đ")
        XCTAssertEqual(typed("a10", .vni), "a")
    }

    func testVniTakeBackAndDigitsOutsideAWord() {
        XCTAssertEqual(typed("a11", .vni), "a1")
        XCTAssertEqual(typed("a66", .vni), "a6")
        XCTAssertEqual(typed("d99", .vni), "d9")
        XCTAssertEqual(typed("2024", .vni), "2024")
        XCTAssertEqual(typed("1 + 2", .vni), "1 + 2")
    }

    func testVniCaseFollowsTheLetters() {
        XCTAssertEqual(typed("Viet65", .vni), "Việt")
        XCTAssertEqual(typed("VIET65", .vni), "VIỆT")
        XCTAssertEqual(typed("D9i", .vni), "Đi")
        XCTAssertEqual(typed("D9I", .vni), "ĐI")
        XCTAssertEqual(typed("A1", .vni), "Á")
    }

    func testVniQuAndGiAreConsonantsBeforeAVowel() {
        XCTAssertEqual(typed("qua1", .vni), "quá")
        XCTAssertEqual(typed("quy1", .vni), "quý")
        XCTAssertEqual(typed("gia2", .vni), "già")
        XCTAssertEqual(typed("gio72", .vni), "giờ")
        XCTAssertEqual(typed("gi2", .vni), "gì")
        XCTAssertEqual(typed("quo7", .vni), "quơ")
    }

    func testVniTonePlacementStyle() {
        XCTAssertEqual(typed("hoa2", .vni, modern: true), "hoà")
        XCTAssertEqual(typed("hoa2", .vni, modern: false), "hòa")
        XCTAssertEqual(typed("khoe3", .vni, modern: true), "khoẻ")
        XCTAssertEqual(typed("khoe3", .vni, modern: false), "khỏe")
        XCTAssertEqual(typed("thuy3", .vni, modern: true), "thuỷ")
        XCTAssertEqual(typed("thuy3", .vni, modern: false), "thủy")
        XCTAssertEqual(typed("hoan2", .vni), "hoàn")
    }

    func testVniTonesSitOnTheRightVowel() {
        XCTAssertEqual(typed("mai1", .vni), "mái")
        XCTAssertEqual(typed("mua1", .vni), "múa")
        XCTAssertEqual(typed("kia1", .vni), "kía")
        XCTAssertEqual(typed("huynh2", .vni), "huỳnh")
        XCTAssertEqual(typed("cuo6i1", .vni), "cuối")
        XCTAssertEqual(typed("ngoai2", .vni), "ngoài")
        XCTAssertEqual(typed("ru7o7u5", .vni), "rượu")
    }

    func testVniAToneAndAMarkReplaceEachOther() {
        XCTAssertEqual(typed("a12", .vni), "à")
        XCTAssertEqual(typed("a18", .vni), "ắ")
        XCTAssertEqual(typed("a81", .vni), "ắ")
        XCTAssertEqual(typed("a82", .vni), "ằ")
    }

    func testVniAfterATakeBackTheWordIsLeftAlone() {
        XCTAssertEqual(typed("a111", .vni), "a11")
        XCTAssertEqual(typed("a666", .vni), "a66")
        XCTAssertEqual(typed("a1112", .vni), "a112")
        XCTAssertEqual(typed("o77", .vni), "o7")
        XCTAssertEqual(typed("uo77", .vni), "uo7")
    }

    func testVniWordsThatAreNotVietnameseAreLeftAlone() {
        for word in ["clear", "show", "window", "hello", "git", "sudo", "brew", "text", "good"] {
            XCTAssertEqual(typedAndEnded(word, .vni), word)
        }
    }

    func testVniDigitsBetweenWordsAreNumbers() {
        XCTAssertEqual(typed("a1 2 3", .vni), "á 2 3")
        XCTAssertEqual(typed("xin chao2 12/5", .vni), "xin chào 12/5")
        XCTAssertEqual(typed("d9i 5 phut1", .vni), "đi 5 phút")
    }

    func testVniUoWithAHornIsAlwaysUoUo() {
        XCTAssertEqual(typed("thuo73", .vni), "thưở")
    }

    func testVniDoesNotReadTelexLetters() {
        XCTAssertEqual(typed("vieetj", .vni), "vieetj")
        XCTAssertEqual(typed("dd", .vni), "dd")
    }

    func testTelexDoesNotReadVniDigits() {
        XCTAssertEqual(typed("viet65"), "viet65")
        XCTAssertEqual(typed("a1"), "a1")
    }

    // MARK: - Edits and backspace

    /// Known limit: a u and an o with a w are read as ươ, which is right for người
    /// and được and wrong for the few words that are uơ (thuở, huơ).
    func testUowIsAlwaysUoUo() {
        XCTAssertEqual(typed("thuowr"), "thưở")
        XCTAssertEqual(typed("quow"), "quơ")
    }

    /// ua has no breve, so a w after it is the horn of the u, as in Unikey.
    func testAWAfterUaIsTheHornOfTheU() {
        XCTAssertEqual(typedAndEnded("dduaw"), "đưa")
        XCTAssertEqual(typedAndEnded("muaw"), "mưa")
        XCTAssertEqual(typedAndEnded("thuaw"), "thưa")
        XCTAssertEqual(typedAndEnded("Dduaw"), "Đưa")
        XCTAssertEqual(typedAndEnded("luawr"), "lửa")
        XCTAssertEqual(typedAndEnded("suawr"), "sửa")
        XCTAssertEqual(typedAndEnded("dduwa"), "đưa")
        XCTAssertEqual(typedAndEnded("muaww"), "muaw", "a second w takes the horn back")
        XCTAssertEqual(typedAndEnded("hoaw"), "hoă", "oa still takes the breve")
        XCTAssertEqual(typedAndEnded("quaw"), "quă", "the u of qu is a consonant")
        XCTAssertEqual(typedAndEnded("xoawn"), "xoăn")
    }

    /// The circumflex key may come after the other letters of the vowel group.
    func testACircumflexKeyAfterTheRestOfTheVowels() {
        XCTAssertEqual(typedAndEnded("ddaya"), "đây")
        XCTAssertEqual(typedAndEnded("dday"), "đay")
        XCTAssertEqual(typedAndEnded("daua"), "dâu")
        XCTAssertEqual(typedAndEnded("ddauaf"), "đầu")
        XCTAssertEqual(typedAndEnded("yeue"), "yêu")
        XCTAssertEqual(typedAndEnded("tieue"), "tiêu")
        XCTAssertEqual(typedAndEnded("cuoios"), "cuối")
        XCTAssertEqual(typedAndEnded("tuayas"), "tuấy")
        XCTAssertEqual(typedAndEnded("toio"), "tôi")
        XCTAssertEqual(typedAndEnded("Ddaya"), "Đây")
        XCTAssertEqual(typedAndEnded("ddayaa"), "ddayaa", "no longer Vietnamese, so left as typed")
    }

    /// A vowel group the letters already make is not turned into another.
    func testACircumflexKeyLeavesAWordThatIsAlreadyAVowelGroup() {
        XCTAssertEqual(typedAndEnded("ngoeo"), "ngoeo")
        XCTAssertEqual(typedAndEnded("ngoeos"), "ngoéo")
        XCTAssertEqual(typedAndEnded("hoai"), "hoai")
    }

    /// uă is no native vowel group; VNI can still ask for it with the 8.
    func testVniCanAskForUaWithABreve() {
        XCTAssertEqual(typedAndEnded("d9ua8", .vni), "đuă")
        XCTAssertEqual(typedAndEnded("d9u7a", .vni), "đưa")
        XCTAssertEqual(typedAndEnded("mua7", .vni), "mưa")
    }

    func testAKeyThatChangesNothingBehindItPasses() {
        var composer = VietnameseComposer(method: .telex)
        XCTAssertEqual(composer.push("v"), .pass)
        XCTAssertEqual(composer.push("i"), .pass)
        XCTAssertEqual(composer.push("e"), .pass)
        XCTAssertEqual(composer.push("e"), .replace(delete: 1, insert: "ê"))
        XCTAssertEqual(composer.push("t"), .pass)
        XCTAssertEqual(composer.push("j"), .replace(delete: 2, insert: "ệt"))
        XCTAssertEqual(composer.text, "việt")
    }

    func testALoneWIsReplacedNotAppended() {
        var composer = VietnameseComposer(method: .telex)
        XCTAssertEqual(composer.push("w"), .replace(delete: 0, insert: "ư"))
    }

    func testBackspaceFollowsTheWordWhileItCan() {
        var composer = VietnameseComposer(method: .telex)
        for key in "vieetj" { _ = composer.push(key) }
        composer.backspace()
        XCTAssertEqual(composer.text, "việ")
        XCTAssertEqual(composer.push("c"), .pass)
        XCTAssertEqual(composer.text, "việc")
    }

    func testBackspaceGivesTheWordUpWhenTheToneWouldMove() {
        var composer = VietnameseComposer(method: .telex, modernTonePlacement: true)
        for key in "hoaf" { _ = composer.push(key) }
        XCTAssertEqual(composer.text, "hoà")
        composer.backspace()
        XCTAssertTrue(composer.isEmpty)

        var traditional = VietnameseComposer(method: .telex)
        for key in "hoaf" { _ = traditional.push(key) }
        traditional.backspace()
        XCTAssertEqual(traditional.text, "hò", "the tone stays on the o, so the word can be followed")
    }

    func testBackspaceOnAnEmptyWordDoesNothing() {
        var composer = VietnameseComposer(method: .vni)
        composer.backspace()
        XCTAssertTrue(composer.isEmpty)
    }

    func testBackspaceDropsAToneThatHasNoVowelLeft() {
        var composer = VietnameseComposer(method: .telex)
        for key in "tas" { _ = composer.push(key) }
        composer.backspace()
        XCTAssertEqual(composer.text, "t")
        XCTAssertEqual(composer.push("a"), .pass)
        XCTAssertEqual(composer.text, "ta")
    }

    func testAnOverlongWordStartsAgain() {
        var composer = VietnameseComposer(method: .telex)
        for _ in 0..<VietnameseComposer.maxWordLength { _ = composer.push("b") }
        XCTAssertEqual(composer.push("a"), .pass)
        XCTAssertEqual(composer.text, "a")
    }

    func testNonAsciiEndsTheWord() {
        var composer = VietnameseComposer(method: .telex)
        _ = composer.push("a")
        XCTAssertEqual(composer.push("é"), .boundary)
        XCTAssertTrue(composer.isEmpty)
    }
}
