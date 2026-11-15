import XCTest
@testable import HopCore

final class VietnameseSyllableTests: XCTestCase {
    private func complete(_ onset: String, _ nucleus: String, _ coda: String = "", stop: Bool = true) -> Bool {
        VietnameseSyllable.isComplete(onset: onset, nucleus: nucleus, coda: coda, stopSafeTone: stop)
    }

    private func viable(_ onset: String, _ nucleus: String, _ coda: String = "", stop: Bool = true) -> Bool {
        VietnameseSyllable.isViable(onset: onset, nucleus: nucleus, coda: coda, stopSafeTone: stop)
    }

    func testRealSyllablesAreComplete() {
        XCTAssertTrue(complete("ngh", "iê", "ng"))
        XCTAssertTrue(complete("qu", "yê", "n"))
        XCTAssertTrue(complete("", "ươ", "ng"))
        XCTAssertTrue(complete("kh", "uy", "nh"))
        XCTAssertTrue(complete("qu", "y", "nh"))
        XCTAssertTrue(complete("gi", "ê", "ng"))
        XCTAssertTrue(complete("đ", "ă", "k"))
        XCTAssertTrue(complete("", "oă", "c"))
        XCTAssertTrue(complete("đ", "uă"), "not native, but let through")
        XCTAssertTrue(complete("đ", "uă", "n"))
    }

    func testWhatIsNotVietnameseIsNotComplete() {
        XCTAssertFalse(complete("cl", "ea", "r"))
        XCTAssertFalse(complete("sh", "ơ"))
        XCTAssertFalse(complete("g", "ô", "d"))
        XCTAssertFalse(complete("w", "i", "n"))
        XCTAssertFalse(complete("t", "i", "ng"))
        XCTAssertFalse(complete("t", "ai", "n"), "ai ends the syllable")
        XCTAssertFalse(complete("t", "ẽ", "t", stop: false))
    }

    func testAFinalStopTakesOnlyTheAcuteAndTheDot() {
        XCTAssertTrue(complete("h", "o", "c", stop: true))
        XCTAssertFalse(complete("h", "o", "c", stop: false))
        XCTAssertTrue(complete("h", "o", "ng", stop: false))
    }

    func testAWordCanBeViableBeforeItIsComplete() {
        XCTAssertTrue(viable("", "", ""))
        XCTAssertTrue(viable("n", "", ""))
        XCTAssertTrue(viable("ng", "", ""))
        XCTAssertTrue(viable("q", "u", ""), "qu is waiting for its vowel")
        XCTAssertTrue(viable("t", "ua", "n"), "tuan may become tuân")
        XCTAssertTrue(viable("t", "ie", "ng"), "tieng may become tiêng")
        XCTAssertTrue(viable("", "ưo", ""), "ưo may become ươ")
        XCTAssertTrue(viable("đ", "", "") && viable("đc", "", ""), "đc, đt")
    }

    func testWhatCannotBecomeVietnameseIsNotViable() {
        XCTAssertFalse(viable("c", "", "") && viable("cl", "", ""))
        XCTAssertFalse(viable("sh", "", ""))
        XCTAssertFalse(viable("f", "", ""))
        XCTAssertFalse(viable("h", "e", "l"))
        XCTAssertFalse(viable("w", "i", "n"))
        XCTAssertFalse(viable("t", "ai", "n"))
        XCTAssertFalse(viable("t", "e", "t", stop: false))
    }
}
