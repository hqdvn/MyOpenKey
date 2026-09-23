# MyOpenKey Changelog

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
