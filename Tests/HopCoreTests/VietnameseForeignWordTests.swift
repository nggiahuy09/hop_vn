import XCTest
@testable import HopCore

/// A word that cannot be Vietnamese is left as it was typed: at once when the
/// way it starts gives it away (`clear`, `show`), and when it ends for the rest
/// (`text`, `good`). Typed in Telex, where the letters themselves are the keys.
final class VietnameseForeignWordTests: XCTestCase {
    private typealias S = VietnameseSpelling

    private let commands = S.words("""
    clear show ls cd pwd git commit push pull merge branch checkout rebase stash status log
    npm install uninstall run build start dev yarn pnpm node deno bun cargo swift make cmake
    sudo brew apt docker compose kubectl helm ssh scp curl wget grep sed cat echo touch mkdir
    chmod kill ps top htop vim nano emacs code open exit history alias export source
    python pip pip3 ruby gem java mvn gradle go npx tsc eslint prettier jest vite webpack
    """)

    private let english = S.words("""
    window web file text good mouse screen class function return import const print console
    warn debug server client request response http https json xml html css react view app
    apple google youtube facebook zoom slack github hello world what where when which who why
    please thanks okay yes know knows learn school street strong sprint blue black green
    flow flower floor glass globe great group growth proud prove press price pride program project
    short shirt sheet shop shout shower shrink should shall shape share sharp shell shine ship
    smart smile smooth snake snow sport spring square stable stack stage stand star state steam
    steel step stick still stock stone stop store storm story straight street stress string
    brand bread break bridge bright bring brown brush build chrome speed spell spend split
    clean clever click clock close cloud club clue clear climb clip clothes
    plan plant plate play please plus plug plum
    wifi window windows word work worth write wrong
    zero zone zoom jazz jump just job join joke juice
    fast first fish five fix flag fly fox free from fun
    """)

    /// Words that are Vietnamese too, spelled like English: they cannot be told
    /// apart, and are not claimed here (this, test, now, how, low, her, his…).
    private func ended(_ word: String, _ method: VietnameseTypingMethod = .telex) -> String {
        S.screen(word, method)
    }

    private func live(_ word: String, _ method: VietnameseTypingMethod = .telex) -> String {
        S.screen(word, method, ended: false)
    }

    private func check(_ words: [String], _ method: VietnameseTypingMethod = .telex,
                       file: StaticString = #filePath, line: UInt = #line) {
        var failures: [String] = []
        for word in words {
            for variant in [word, word.uppercased(), word.prefix(1).uppercased() + word.dropFirst()] {
                let shown = ended(variant, method)
                if shown != variant { failures.append("\(variant) → \(shown)") }
            }
        }
        XCTAssertTrue(failures.isEmpty, "\(failures.count) not left alone:\n" + failures.joined(separator: "\n"),
                      file: file, line: line)
    }

    func testCommandsStayAsTyped() { check(commands) }
    func testEnglishWordsStayAsTyped() { check(english) }

    /// The ones the way they start gives away show right while they are typed.
    func testTheStartOfAWordGivesItAwayAtOnce() {
        for word in ["clear", "show", "screen", "slow", "know", "flow", "string", "smart", "brown", "glass"] {
            XCTAssertEqual(live(word), word, "while typing \(word)")
        }
    }

    func testEnglishInTheMiddleOfVietnamese() {
        XCTAssertEqual(S.screen("Tooi dduwowcj clear va show log", .telex), "Tôi được clear va show log")
        XCTAssertEqual(S.screen("Hoom nay tooi push code leen github", .telex), "Hôm nay tôi push code lên github")
        XCTAssertEqual(S.screen("cais nayf lafm sao: git commit -m", .telex), "cái này làm sao: git commit -m")
    }

    /// What cannot be put right: a Vietnamese word spelled like an English one
    /// (rust → rút), and the key typed twice, which in Telex takes a mark back,
    /// so a doubled s, f, r, x or j loses a letter (diff → dif), as in Unikey.
    /// A letter typed once more is typed as it is: passs → pass.
    func testWhatCannotBePutRight() {
        XCTAssertEqual(S.screen("rust", .telex), "rút")
        XCTAssertEqual(S.screen("var", .telex), "vả")
        XCTAssertEqual(S.screen("chown", .telex), "chơn")
        XCTAssertEqual(S.screen("diff", .telex), "dif")
        XCTAssertEqual(S.screen("error", .telex), "eror")
        XCTAssertEqual(S.screen("diffff", .telex), "dif" + "ff")
        XCTAssertEqual(S.screen("wow", .telex), "ươ")
        XCTAssertEqual(S.screen("awk", .telex), "ăk")
        XCTAssertEqual(S.screen("toast", .telex), "toát")
        XCTAssertEqual(S.screen("queue", .telex), "quêu", "the circumflex key reaches the first e")
    }

    func testAWordPutBackKeepsTheKeyThatEndedIt() {
        XCTAssertEqual(S.screen("text, good. what? show\n", .telex, ended: false), "text, good. what? show\n")
        XCTAssertEqual(S.screen("usb(good)", .telex), "usb(good)")
    }

    func testAbbreviationsWithAStrokeAreKept() {
        XCTAssertEqual(S.screen("ddc ddt ddm dd", .telex), "đc đt đm đ")
        XCTAssertEqual(S.screen("25.000dd", .telex), "25.000đ")
    }

    func testVniAbbreviationsWithAStrokeAreKept() {
        XCTAssertEqual(S.screen("d9c d9t d9m d9", .vni), "đc đt đm đ")
        XCTAssertEqual(S.screen("25.000d9", .vni), "25.000đ")
    }

    func testVietnameseTheUserTookBackStaysTaken() {
        XCTAssertEqual(S.screen("aaa", .telex), "aa")
        XCTAssertEqual(S.screen("ass", .telex), "as")
        XCTAssertEqual(S.screen("dduwowcjj", .telex), "đươcj")
    }

    func testVniLeavesForeignWordsAndNumbersAlone() {
        check(commands, .vni)
        check(S.words("clear show window class function hello world please thanks"), .vni)
        for text in ["covid19", "win10", "mp3", "h2o", "iphone15", "H264", "ps5", "3d"] {
            XCTAssertEqual(S.screen(text, .vni), text)
        }
    }
}
