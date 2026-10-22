# MyOpenKey Changelog

##### MyOpenKey 0.1.09 (Build 10) — 23/10/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- Windows: sửa gõ trên thanh địa chỉ trình duyệt bị lặp ký tự (`oo` → `oô`) do gợi ý tự động
- Windows: thêm biểu tượng ứng dụng cho exe, lối tắt và bộ cài
- Windows: sửa biểu tượng khay hệ thống không hiển thị
- Windows: thêm Bảng điều khiển (kiểu gõ, bảng mã, chính tả, gõ tắt, hệ thống) mở từ biểu tượng khay
- macOS: không có thay đổi chức năng

##### MyOpenKey 0.1.08 (Build 9) — 23/10/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- Windows: sửa lỗi thiếu `MSVCP140.dll` / `VCRUNTIME140.dll` / `VCRUNTIME140_1.dll` khi chạy trên máy chưa cài Visual C++ Redistributable (liên kết tĩnh C runtime)
- Windows: nhúng lại manifest ứng dụng (DPI PerMonitorV2, Common Controls v6)
- CI: kiểm tra exe Windows không phụ thuộc DLL runtime của Visual C++
- macOS: không có thay đổi chức năng

##### MyOpenKey 0.1.07 (macOS) (Build 8) — 23/10/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- **Sửa lỗi bộ gõ cốt lõi (Core Engine):**
  - E1: Kiểm tra `_index > 0` trước khi truy cập `TypingWord[_index - 1]` khi gõ ký tự `w`, `[`, `]` đầu từ.
  - E3/E8: Kiểm tra giới hạn buffer khi xử lý phụ âm nhanh đầu/cuối (`checkQuickConsonant`), dùng `find()` thay vì `operator[]`; kẹp chặn chỉ số kết thúc theo `_index` khi phát lại phím macro.
  - E5/E6: Kiểm tra biên an toàn `cursor + n <= size` khi đọc dữ liệu nhị phân macro (`initMacroMap`) và smart switch key (`initSmartSwitchKey`), tránh tràn bộ nhớ stack.
  - E7: Bắt ngoại lệ `std::range_error` trong `utf8ToWideString` khi chuỗi UTF-8 không hợp lệ và trả về chuỗi rỗng.
  - E9/A13: Giới hạn độ dài `hMacroKey` (tối đa 255), `_typingStates` (32 phần tử) và `_longWordHelper` (32 phần tử) khi gõ liên tục từ dài; kẹp giá trị `hBPC` tránh tràn kiểu `Byte`.
  - E11: Từ chối phím tắt macro vượt quá 255 bytes hoặc nội dung vượt quá 65535 bytes; bỏ qua `bundleId` dài hơn 255 bytes khi lưu dữ liệu SmartSwitchKey.
  - W1: Hỗ trợ bộ mã phím Windows đa nền tảng (`platforms/win32.h`, `CMakeLists.txt`, chạy CI build và test trên Windows).
  - **Windows (thử nghiệm):** app khay hệ thống Win32 dùng chung engine, bộ cài Inno Setup + bản portable, CI build Windows.
- **Sửa lỗi tầng ứng dụng (App Layer):**
  - E4: Chặn crash khi `_syncKey` rỗng.
  - E10: Giới hạn giá trị cài đặt lưu trữ cho `vCodeTable`, `vInputType`, bảng mã chuyển đổi và smart switch.
  - P2/E12/E14: Viết lại `SendNewCharString` dạng vòng lặp chia khúc tối đa 16 unit, loại bỏ hoàn toàn đệ quy và không mất ký tự khi gửi chuỗi dài.
  - E13: Kiểm tra an toàn con trỏ NULL đối với `UTF8String`.
  - A1: Chuyển mã nhanh trong nền, không còn chặn bàn phím.
  - A2: Khôi phục vùng chọn văn bản khi dùng AX fallback.
  - A3: Sửa lỗi đảo ngược tùy chọn cảnh báo khi chuyển mã.
  - A4: Công tắc tự động cập nhật điều khiển trực tiếp Sparkle, gỡ bỏ bộ kiểm tra `version.json` dư thừa.
  - A5: Nhập file macro lỗi không làm mất macro cũ trong bộ nhớ.
  - A6: Khắc phục rò rỉ bộ nhớ `CGEventSource`.
  - A7: Reset trạng thái macro tiếng Anh khi click chuột.
  - A8: Khôi phục cài đặt mặc định đồng bộ đúng trạng thái kiểm tra chính tả.
  - A9: Không đăng ký lại login item mỗi lần chuyển đổi ngôn ngữ.
  - A10: Bổ sung nhãn hỗ trợ VoiceOver cho người khiếm thị.
  - A11: Bỏ qua xử lý khi con trỏ nằm trong ô mật khẩu an toàn.
  - A12: Chuyển mã clipboard không làm mất các định dạng dữ liệu khác.
- **CI & Đóng gói phát hành (P4):**
  - Đưa `CERTIFICATE_P12` và `CERTIFICATE_PWD` lên `env` cấp job trong `release.yml`.
  - Thắt chặt `generate_appcast` và `git push` trong `build_release.sh` và `release.yml`, kiểm tra `appcast.xml` có entry hợp lệ chứa chữ ký `sparkle:edSignature`.
  - Ghim mã băm commit SHA đầy đủ cho `actions/checkout` (v7.0.1) và `softprops/action-gh-release` (v3.0.3).
  - Dọn dẹp nhánh file tạm `/tmp/sparkle_private_key.txt`, xóa `XPCServices` khỏi Sparkle framework trước khi ký mã.
  - Bổ sung quy trình CI `.github/workflows/ci.yml` tự động chạy bộ kiểm thử engine và build thử nghiệm Xcode trên macOS 14, kèm build/test engine trên Windows.
- **Dọn dẹp kho mã nguồn (P5):**
  - Thêm `xcuserdata/` vào `.gitignore` và hủy theo dõi các file giao diện người dùng Xcode.
  - Nâng `MACOSX_DEPLOYMENT_TARGET` từ 12.0 lên 13.0 trong toàn bộ `project.pbxproj`.
  - Dọn dẹp nhóm và file tham chiếu mồ côi `OpenKeyUpdate` khỏi dự án Xcode.
##### MyOpenKey 0.1.06 (macOS) (Build 7) — 28/09/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- **Tự động kích hoạt khi được cấp quyền Trợ năng:**
  - Mở app lần đầu chưa có quyền: tự mở trang Cài đặt hệ thống và theo dõi ngầm định kỳ mỗi 1 giây.
  - Ngay khi người dùng bật công tắc cho phép, MyOpenKey tự kích hoạt menu bar và engine gõ ngay lập tức, không cần khởi động lại hay mở lại app.
- **Sửa lỗi "Kiểm tra cập nhật" lần đầu không phản hồi:**
  - Khởi tạo sớm Sparkle Controller ngay khi app mở, đưa việc hiển thị UI vào chế độ RunLoop mặc định để Menu Bar đóng hẳn và tự động thử lại sau 300ms nếu updater chưa kịp hoàn thành chu kỳ khởi tạo.
- **Đồng bộ thương hiệu MyOpenKey:**
  - Cập nhật dòng *"Tạm tắt OpenKey bằng phím ⌘"* thành *"Tạm tắt MyOpenKey bằng phím ⌘"* trong tab Tiện ích của Bảng điều khiển và đồng bộ toàn bộ tooltip trong Storyboard.
- **Làm mới hình ảnh giao diện & tài liệu:**
  - Chụp mới toàn bộ 5 ảnh màn hình thực tế trong `README.md` theo chuẩn giao diện MyOpenKey mới nhất và tinh gọn các bước cài đặt.
- **Nâng cấp CI Release:**
  - Nâng cấp `actions/checkout` lên `v7` và `softprops/action-gh-release` lên `v3` chạy trên môi trường Node 24.

##### MyOpenKey 0.1.05 (macOS) (Build 6) — 27/09/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- **Ký Developer ID & Notarize bởi Apple:**
  - Ứng dụng và bộ cài `.dmg` được ký bằng chứng chỉ Apple Developer ID, bật Hardened Runtime và được Apple notarize.
  - Mở ứng dụng ngay lần đầu, không còn cảnh báo *"Apple could not verify..."*, không cần `xattr` hay bấm *Open Anyway*.
  - Bỏ chứng chỉ tự ký `MyOpenKey Signing` và công cụ `Cài đặt chứng chỉ (Giữ quyền).command` khỏi bộ cài.
- **Lưu ý khi cập nhật từ bản cũ:** do đổi chứng chỉ ký, macOS sẽ yêu cầu **cấp lại quyền Trợ năng (Accessibility) một lần duy nhất**. Các bản sau giữ nguyên quyền.
- Đổi nhánh chính của kho mã từ `master` sang `main`; Sparkle và kiểm tra phiên bản dùng đường dẫn mới.

##### MyOpenKey 0.1.04 (macOS) (Build 5) — 24/09/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))  
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- **Gõ mượt trong Spotlight và Alfred:**
  - Sửa trực tiếp ô nhập qua Accessibility API thay vì gửi Backspace giả, hết lỗi mất/lộn chữ khi gõ nhanh do xung đột với gợi ý inline.
  - Nhận diện cả Spotlight mới trên macOS 26+ (`com.apple.campo`). Chỉ áp dụng bảng mã Unicode; tự quay về cách gửi phím nếu ô nhập không hỗ trợ.
  - Raycast giữ cách gửi phím vì ô nhập của Raycast không nhận sửa qua Accessibility.
- **Ổn định & Tiết kiệm pin:**
  - Tự bật lại EventTap cả khi macOS tắt do `kCGEventTapDisabledByUserInput` (secure input), không chỉ timeout.
  - Bật lại EventTap ngay khi máy thức dậy sau Sleep hoặc chuyển lại phiên người dùng; Watchdog dự phòng giãn từ 500ms lên 5s để máy không bị đánh thức liên tục khi rảnh.
  - Giới hạn thời gian chờ Accessibility 100ms, tránh treo bộ gõ khi app đích không phản hồi.
- **Hiệu năng & Sửa lỗi:**
  - Tùy chọn "Tắt Tiếng Việt khi dùng bàn phím ngôn ngữ khác" dùng cache, chỉ cập nhật khi đổi input source thay vì truy vấn mỗi phím; sửa lỗi rò bộ nhớ và giải phóng sai đối tượng (nguy cơ crash) ở code cũ.
  - Các xử lý đặc thù theo app (Sublime Text, Unicode tổ hợp, sửa gợi ý) dùng app nhận phím, cache theo pid, thay vì truy vấn app đang active mỗi phím; nhận đúng app khi gõ trong Spotlight.
  - Adobe (Photoshop, Illustrator, InDesign…) và Affinity: bỏ qua workaround gợi ý trình duyệt, hết hiện ô vuông ✕.
  - Dọn code chết xử lý sự kiện kéo chuột.
- Một số cải tiến được port từ [mkey](https://github.com/maclifevn/mkey) (GPLv3).

##### MyOpenKey 0.1.03 (macOS) (Build 4) — 24/09/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))  
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- **Giải pháp giữ quyền Trợ năng (Accessibility) vĩnh viễn:**
  - Tích hợp chứng chỉ ký số phát hành cố định `MyOpenKey Signing` (Designated Requirement ổn định trên macOS TCC).
  - Đính kèm công cụ 1-click `Cài đặt chứng chỉ (Giữ quyền).command` trong file `.dmg` để người dùng thêm chứng chỉ tin cậy vào Keychain máy một lần duy nhất.
  - Khắc phục triệt để lỗi macOS thu hồi và yêu cầu cấp lại quyền Trợ năng mỗi khi ứng dụng tự động cập nhật bản mới.

##### MyOpenKey 0.1.02 (macOS) (Build 3) — 24/09/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))  
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- **Bản địa hóa tiếng Việt cho Sparkle Auto-Update:**
  - Hỗ trợ đầy đủ ngôn ngữ tiếng Việt (vi) cho toàn bộ chuỗi thông báo, hộp thoại kiểm tra và tiến trình cập nhật tự động của Sparkle 2.
- **Tinh chỉnh giao diện & Bảng điều khiển:**
  - Thiết kế lại trạng thái rỗng cho danh sách loại trừ ứng dụng (App Exclusion) với biểu tượng nét đứt hiện đại, tinh tế.
  - Đồng bộ chuẩn hóa thuật ngữ "Kiểm tra cập nhật" trên toàn bộ menu bar, storyboard và bảng cài đặt hệ thống.
  - Chụp mới toàn bộ ảnh giao diện thực tế và cập nhật tài liệu hướng dẫn `README.md`.

##### MyOpenKey 0.1.01 (macOS) (Build 2) — 24/09/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))  
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- **Tự động cập nhật 1-click với Sparkle 2:**
  - Tích hợp framework Sparkle 2 (Ed25519) tự động kiểm tra, tải ngầm và cài đặt bản mới trực tiếp trong ứng dụng mà không cần tải thủ công từ trình duyệt.
- **Hiện đại hóa toàn diện Công cụ chuyển mã (Convert Tool):**
  - Chuyển đổi hoàn toàn sang giao diện SwiftUI Inset-Grouped cards: đảo chiều bảng mã 1-click, tùy chọn đổi hoa/thường, bỏ dấu tiếng Việt, phím tắt chuyển mã nhanh, chuyển đổi clipboard tức thì.
- **Tối ưu hóa hiệu năng & Độ trễ gõ phím:**
  - Thêm bộ nhớ đệm `targetPID` trong vòng lặp EventTap: giảm thiểu lệnh gọi IPC hệ thống xuống $O(1)$ cho mỗi phím bấm, mang lại độ trễ gõ phím cực thấp.
- **Tinh gọn giao diện:**
  - Loại bỏ menu và cửa sổ Giới thiệu pop-up cũ, gom toàn bộ thông tin bản quyền và liên hệ vào tab *Thông tin* trong Bảng điều khiển.

##### MyOpenKey 0.1.00 (macOS) (Build 1) — 23/09/2026
Phát triển bởi **Huỳnh Quốc Đạt** ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))  
Dự án mã nguồn mở độc lập tại [github.com/hqdvn/MyOpenKey](https://github.com/hqdvn/MyOpenKey).

- **Giao diện hiện đại (SwiftUI / Inset-Grouped Cards):**
  - Tái thiết kế toàn bộ Bảng điều khiển bằng SwiftUI theo chuẩn macOS hiện đại: card bo góc 10px, viền kính mờ, phụ đề chi tiết cho từng tính năng.
  - Tự động thích ứng hoàn hảo với Dark Mode và Light Mode.
  - Cụm nút dưới đáy tối ưu: "Khôi phục mặc định" bên trái, "Đóng" bên phải (bỏ nút Thoát tránh bấm nhầm).
- **Bộ nhận diện thương hiệu & Biểu tượng mới:**
  - App Icon chuẩn macOS continuous squircle với 3 phím bấm 3D `a`, `ă`, `â` sắc nét, không còn viền trắng hay lỗi hộp vuông đổ bóng.
  - Biểu tượng Menu bar mới: chữ `V` (Tiếng Việt) và `E` (English) chuyển sắc xanh cyan nổi bật, nét chữ thanh mảnh tinh tế đồng bộ với icon hệ thống.
  - Hỗ trợ cả 2 chế độ hiển thị: Full Color Gradient và Đơn sắc hiện đại (`setTemplate:YES`).
- **Thiết lập gõ tắt (Macro Manager) hiện đại:**
  - Xây dựng lại hoàn toàn bằng SwiftUI: tìm kiếm thời gian thực, nhập và chỉnh sửa nhanh ngay trên thanh công cụ, xóa từ gõ tắt với 1 click, nạp/xuất file tương thích hoàn toàn dữ liệu cũ.
- **Công cụ chuyển mã (Convert Tool) hiện đại:**
  - Tái thiết kế toàn diện bằng SwiftUI: đảo chiều bảng mã 1-click, tùy chọn đổi hoa/thường, bỏ dấu tiếng Việt, phím tắt chuyển mã nhanh, chuyển đổi clipboard tức thì.
- **Tối ưu hóa hiệu năng & Bộ nhớ:**
  - Lưu đệm định danh ứng dụng mục tiêu (`targetPID` cache) trong vòng lặp EventTap: giảm thiểu gọi IPC hệ thống xuống độ phức tạp $O(1)$ trên mỗi phím bấm, mang lại độ trễ gõ phím cực thấp.
- **Ổn định tối đa & Chống đơ kẹt phím:**
  - Bộ giám sát Watchdog (500ms): tự động khôi phục kết nối bàn phím nếu macOS ngắt EventTap sau khi Sleep/Wake máy.
  - Cấp phát sự kiện Backspace động: khắc phục lỗi nghẽn hàng đợi phím trên Apple Mail và các ứng dụng WebKit.
  - Loại bỏ hook kéo chuột (`MouseDragged`) khỏi eventMask để giảm tải xử lý sự kiện thừa.
  - Khắc phục lỗi kẹt cửa sổ khi mở từ Spaces/Desktop khác: tự động di chuyển đến Desktop đang hoạt động.
- **Tính năng mới:**
  - Hỗ trợ chuyển chế độ nhanh bằng 1 lần nhấn phím `🌐 Fn (Globe)` như bộ gõ Apple mặc định.
  - Danh sách loại trừ ứng dụng (App Exclusion): người dùng tự thêm các ứng dụng (Terminal, IDE, Game...) để luôn dùng English, tự khôi phục Tiếng Việt khi chuyển ra ngoài.
  - Hỗ trợ khởi động cùng hệ thống bằng kiến trúc native `SMAppService` trên macOS 13+ (trên macOS 12 chưa khả dụng).
  - Sửa lỗi kẹt chế độ khi chọn English trên Bảng điều khiển.
  - Cơ chế kiểm tra cập nhật mới qua GitHub Releases với thông báo mạng rõ ràng.
- **Hệ thống & Tương thích:**
  - Đổi tên ứng dụng thành **MyOpenKey**, bundle ID riêng `com.hqdvn.myopenkey` (cài song song với OpenKey gốc).
  - Nâng macOS deployment target lên 12.0 (hỗ trợ Xcode 14–27+).
  - Dọn sạch toàn bộ mã nguồn thừa của Windows và Linux, tập trung 100% vào macOS.

##### 23/09/2026: Khởi tạo dự án từ mã nguồn gốc OpenKey (tác giả: Mai Vũ Tuyên - GPLv3).
