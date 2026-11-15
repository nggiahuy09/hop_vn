import Foundation
@testable import HopCore

/// What the Telex and VNI corpus tests share: taking a Vietnamese word apart
/// without the engine's help, the screen the keys land on, and the corpus.
/// The words are spelled the traditional way (hòa, khỏe, thủy), which is the
/// engine's default.
enum VietnameseSpelling {

    enum Mark { case none, circumflex, breve, horn, stroke }

    struct Piece {
        var letter: Character      // as written in the source: case kept, base letter
        var mark: Mark
        var tone: UInt32?          // the combining scalar of the tone this letter carries
        var isVowel: Bool { "aeiouyAEIOUY".contains(letter) }
    }

    static let grave: UInt32 = 0x0300
    static let acute: UInt32 = 0x0301
    static let hook: UInt32 = 0x0309
    static let tilde: UInt32 = 0x0303
    static let dot: UInt32 = 0x0323

    static func lower(_ c: Character) -> Character { Character(String(c).lowercased()) }

    /// Splits a word into letters, each with its mark and tone.
    static func pieces(_ word: String) -> [Piece]? {
        var out: [Piece] = []
        for character in word {
            if character == "đ" || character == "Đ" {
                out.append(Piece(letter: character == "đ" ? "d" : "D", mark: .stroke, tone: nil))
                continue
            }
            let scalars = Array(String(character).decomposedStringWithCanonicalMapping.unicodeScalars)
            guard let first = scalars.first, first.isASCII, first.properties.isAlphabetic else { return nil }
            var piece = Piece(letter: Character(first), mark: .none, tone: nil)
            for scalar in scalars.dropFirst() {
                switch scalar.value {
                case 0x0302: piece.mark = .circumflex
                case 0x0306: piece.mark = .breve
                case 0x031B: piece.mark = .horn
                case grave, acute, hook, tilde, dot: piece.tone = scalar.value
                default: return nil
                }
            }
            out.append(piece)
        }
        return out
    }

    /// The vowels of the syllable, as a person counts them: the u of qu and the
    /// i of gi belong to the consonant while a vowel follows.
    static func nucleus(_ p: [Piece]) -> Range<Int>? {
        var vowel = p.map(\.isVowel)
        var i = 1
        while i + 1 < p.count {
            let before = lower(p[i - 1].letter)
            let here = lower(p[i].letter)
            if vowel[i], vowel[i + 1], (here == "u" && before == "q") || (here == "i" && before == "g") {
                vowel[i] = false
            }
            i += 1
        }
        guard let last = vowel.lastIndex(of: true) else { return nil }
        var first = last
        while first > 0, vowel[first - 1] { first -= 1 }
        return first..<last + 1
    }

    /// Runs of letters become syllables, everything else is typed as it is.
    static func encode(_ text: String, syllable: (String) -> String?) -> String? {
        var out = ""
        var run = ""
        func flush() -> Bool {
            guard !run.isEmpty else { return true }
            guard let keys = syllable(run) else { return false }
            out += keys
            run = ""
            return true
        }
        for character in text {
            if character.isLetter {
                run.append(character)
            } else {
                guard flush() else { return nil }
                out.append(character)
            }
        }
        return flush() ? out : nil
    }

    /// The keys typed the way the app handles them: a swallowed key becomes an
    /// edit, any other key lands as it is. A space follows the last key, so a
    /// word that was wrongly taken for foreign shows up as put back.
    static func screen(_ keys: String, _ method: VietnameseTypingMethod, ended: Bool = true) -> String {
        var composer = VietnameseComposer(method: method)
        var shown: [Character] = []
        for key in keys + (ended ? " " : "") {
            switch composer.push(key) {
            case .pass, .boundary: shown.append(key)
            case .replace(let delete, let insert):
                shown.removeLast(delete)
                shown.append(contentsOf: insert)
            case .fix(let delete, let insert):
                shown.removeLast(delete)
                shown.append(contentsOf: insert)
                shown.append(key)
            }
        }
        return ended ? String(shown.dropLast()) : String(shown)
    }

    static func words(_ block: String) -> [String] {
        block.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
    }

    // MARK: - The corpus

    /// One or more words for every vowel, with every tone.
    static let singleVowels = words("""
    ba bá bà bả bã bạ ăn bắt bằng bẳn bẵn bặt cân bấm bầm bẩm bẫm bậm
    xe xé xè xẻ xẽ xẹ bê kể thế nghề đêm tên hết mệt lệnh bếp đế ễnh
    đi mì chị tí bị vĩ lịch nghĩ thích mít gì gìn giữ giá
    to cò mỏ nõ họ con cọp bóng long mọc học góc
    ông cổ tối hồ nhộn sống cộng tốt một bốc đồng không mộng
    mơ bờ nhớ tờ ở cơm lớn cờ hơn chờ lời mớ
    cu mũ tù củ vụ mũi bụi túi cúi chùm cúp
    chư thư từ nữ ưu hưu mười người được nước lưng cứng sức thức
    ý kỳ quý quỳ tuy tay máy vậy này dạy chạy suy
    """)

    /// Every vowel group the language has, with its tones. `thuở` and `huơ`
    /// are left out on purpose: a u and an o with a horn key are always ươ.
    static let vowelGroups = words("""
    mái hai bài tai sai cao báo sào sau báu màu đau cháu
    tay máy hay chạy ngày đầu sâu hậu cây dây mấy đấy thầy
    kéo béo đèo mèo trèo heo nếu kêu trêu lều
    mía kia bìa đĩa chia tía chịu dịu níu
    tiên biển miền viết tiếng yêu chiều hiểu kiểu điều niềm nghiệp tiệm thiếu
    hoa họa tòa hóa xóa toán hoàn khoa loan ngoan xoăn khỏe xòe
    ngoài hoài loại khoai quái thoải xoay ngoáy ngoéo ngoèo
    nói gọi cói mỏi đòi hỏi tôi rồi đối nổi cối ngồi bối thổi
    mới đời bơi tới chơi lợi ơi rơi đợi
    mùa cua của rùa múa chúa thua lùa bùa đũa
    quân tuần xuân huân luật quần
    huế tuệ quê thuê khuê huệ tuế quơ
    tuy quy huy thủy thúy tùy khuya
    tuyên quyền khuyên huyền chuyện chuyển nguyệt tuyệt xuyên thuyền luyện quyết duyên
    cuối muối chuối tuổi suối nuôi buổi đuối buôn cuốn muốn chuồn luôn cuộc thuốc nuốt uống quốc buồng muộn cuống chuột đuôi
    mươi rượu hươu bướu người cười tươi mười lười tưới bưởi
    hưu lưu bưu cứu hữu lựu mưu sưu mưa chưa thưa lửa sữa giữa vừa cưa dưa ưa đưa trưa gửi ngửi
    yêu chiều hiểu kiểu thiếu tiêu nhiều miêu điêu kiêu siêu biếu liều tiếu yên yếu
    nghiêng nghiêm nghiệm nghiền
    """)

    static let finalConsonants = words("""
    các cách cám cạn cảng cảnh cập cắt cực lịch tích trích bịch
    mặc mặt mạnh mạng mật đẹp đạp đáp đập đất đặc đảng
    thắng thắc thấm thấp thấy thấu thiếc thiệp thiện thiên thiết thiêng
    lắp lắm lắng lặng lạc lạnh lạng lận lập lấy
    bác bách bán bản bảng bánh báp bát bắc bắp bắn
    chúc chúng chính chỉnh chim chìm chiếc chiến chiếu chữ chữa
    """)

    static let initials = words("""
    nghe nghề nghĩa nghỉ nghèo nghiêng nghiên nghệ nghiệp
    ngày ngủ ngon người ngõ ngang ngắn ngọt ngạc ngọc ngực
    nhà nhớ nhanh nhiều nhưng như nhân nhẹ nhật nhỏ nhóm nhìn
    không khó khi khác khuya khỏe khách khẩu khóa khoảng khỏi
    phố phở phải phòng phép phút phương phượng phường phát phân
    thế thì thật thương thích thể thuế thầy thành thông thời
    trời trên trong trường trẻ trước trưa trăm trắng trận trình
    chào chợ chỗ chậm chuyện chúng chúc chữ chân chiều
    ghế ghi ghét ghé ghềnh ghẹo
    giờ giá giúp giữ giữa giỏi giường giấc giận giáo giống gì giàu giải giếng giặt giày
    quá quả quên quê quán quận quốc quyết quà quân quen quý quyền quạt quanh quay quẹo
    đi đây đó đẹp đường đất điện điểm đông đúng đầu đời đồng được đặc đá đèn đã đêm đỏ đủ đen
    xin xanh xe xa xuống xây xem xong xếp xã
    sáng sao sau sách sống sợ sức sự sửa sân sông siêu
    rất ra rồi rộng rẻ rừng rượu rau rõ rảnh
    làm lớn lên lúc lại lâu lạnh lửa luôn lòng lá lịch lễ lương
    dạy dài dễ dùng dưới dự dân dầu dụng dũng duyên dừng
    và vào vui về việc vì vẫn vậy vợ vườn vàng vòng vừa vẽ
    bạn bao bài bàn bên bình biển bóng bằng bữa bé
    có cái cũng cùng cảm cần cách cao các công cuộc cửa của con cô cậu chú cháu chị anh em
    hôm hay hơn học hết hỏi hiểu hình hoa hồng huyện
    mình mọi một mới mua mùa muốn mẹ mỗi máy mắt miệng mặt mưa mây mềm
    nước nói này nào năm nữa nếu nên nơi nặng nam nóng non núi
    tôi từ tất tốt tuổi tình tiền tiếng tay tên tâm tối tự tuyệt tin tìm tập
    gà gạo gần gặp gió gái gửi
    kế kể kéo kém kỳ kinh kiếm kia kết khô
    """)

    /// Letters that are also keys of a method, at the start or the end of a syllable.
    static let keyLetters = words("""
    xa xe xin xanh xong xuống xây xem xếp xã
    sa sáng sao sách sống sợ sức sự sửa sân sông siêu
    ra rất rồi rộng rẻ rừng rượu rau rõ rảnh
    dạ dả dê dế dì dò dở do
    ưu ưa ừ ừm ơ ờ ới ớt ơi
    oa oe oi ôi ôm ốm ổi ớm
    ao ào áo eo èo ém ép ẻo ôn ồn ổn
    """)

    static let phrases: [String] = [
        "xin chào", "cảm ơn", "tạm biệt", "chúc mừng năm mới", "chào buổi sáng", "xin lỗi",
        "không có gì", "rất vui được gặp bạn", "bạn khỏe không", "tôi khỏe", "hẹn gặp lại",
        "chúc ngủ ngon", "tôi yêu Việt Nam", "Hà Nội", "Thành phố Hồ Chí Minh", "Đà Nẵng", "Huế",
        "Hải Phòng", "Cần Thơ", "Nha Trang", "Đà Lạt", "Vũng Tàu", "Quy Nhơn", "Biên Hòa",
        "Nguyễn Văn An", "Trần Thị Bích", "Lê Hoàng Phương", "Phạm Quỳnh Anh", "Đặng Thùy Dương",
        "Võ Thị Sáu", "Ngô Quyền", "Đinh Tiên Hoàng", "Lý Thường Kiệt", "Hoàng Thị Mỹ Linh",
        "Bùi Xuân Trường", "Dương Quốc Khánh", "Huỳnh Thanh Tùng", "Phan Đình Phùng", "Vũ Thị Hương",
        "Cộng hòa xã hội chủ nghĩa Việt Nam", "Độc lập tự do hạnh phúc", "Thủ tướng Chính phủ",
        "Công nghệ thông tin", "Trường Đại học Bách khoa", "Ngân hàng thương mại cổ phần",
        "Phở bò tái nạm", "Bánh mì thịt nướng", "Cà phê sữa đá", "Bún chả Hà Nội", "Gỏi cuốn",
        "Chả giò", "Nước mắm", "Bún bò Huế", "Cơm tấm sườn", "Bánh xèo", "Hủ tiếu Nam Vang",
    ]

    static let sentences: [String] = [
        "Hôm nay trời đẹp quá.", "Tôi đang học tiếng Việt.", "Bạn tên là gì?", "Mình là sinh viên.",
        "Chúc mừng sinh nhật!", "Cảm ơn bạn rất nhiều.", "Anh ấy đang làm việc ở công ty.",
        "Chúng tôi đi ăn phở.", "Em yêu anh.", "Việt Nam là một đất nước xinh đẹp.",
        "Thời tiết hôm nay rất nóng.", "Tôi muốn mua một cái điện thoại mới.", "Bây giờ là mấy giờ?",
        "Làm ơn cho tôi hỏi đường.", "Ngày mai tôi sẽ đi du lịch.", "Quyết định số 1, ngày 12/5/2024.",
        "Giá 25.000đ, giảm 50%.", "Họ và tên: Nguyễn Văn A; năm sinh: 1990.",
        "Anh ơi, cho em một ly cà phê sữa đá nhé!", "Không có gì quý hơn độc lập, tự do.",
        "Trên trời có đám mây xanh, ở dưới có đám lúa vàng.", "Muốn sang thì bắc cầu kiều.",
        "Có công mài sắt có ngày nên kim.", "Ăn quả nhớ kẻ trồng cây.", "Uống nước nhớ nguồn.",
        "Gần mực thì đen, gần đèn thì sáng.", "Đi một ngày đàng, học một sàng khôn.",
    ]
}
