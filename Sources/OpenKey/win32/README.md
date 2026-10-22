# MyOpenKey Windows Port

A lightweight Win32 port of the MyOpenKey Vietnamese input method (Telex, VNI, Simple Telex).

## Build Steps

Build using CMake and MSVC (Visual Studio 2019 / 2022) on Windows:

```cmd
cmake -B build
cmake --build build --config Release
```

The compiled binary will be placed at `build/Release/MyOpenKey.exe`.

## Architecture

- Plain Win32 C++17 (no external runtime dependencies).
- Low-level keyboard and mouse hooks (`WH_KEYBOARD_LL`, `WH_MOUSE_LL`).
- Notification area (system tray) icon and context menu.
- Registry-based settings storage under `HKCU\Software\MyOpenKey`.
- Reuses the core engine in `Sources/OpenKey/engine` and `ChunkSplitter.h`.

## Hướng dẫn sử dụng

- **Mở Bảng điều khiển (Settings):**
  - Nhấp đúp chuột trái (double-click) vào biểu tượng chữ **V** / **E** ở khay hệ thống (System Tray).
  - Hoặc nhấp chuột phải vào biểu tượng khay và chọn mục in đậm đầu tiên: **Bảng điều khiển…**.
  - Bảng điều khiển gồm 4 thẻ:
    1. **Bộ gõ:** Kiểu gõ (Telex, VNI, Simple Telex 1, Simple Telex 2), bảng mã (Unicode dựng sẵn, TCVN3, VNI Windows, Unicode tổ hợp, CP 1258), phím chuyển Việt/Anh (Ctrl+Shift hoặc Alt+Z), âm thanh "bíp".
    2. **Chính tả & gõ nhanh:** Kiểm tra chính tả, đặt dấu oà/uý kiểu mới, khôi phục từ sai chính tả, bỏ dấu tự do, gõ tắt Telex nhanh, phụ âm đầu/cuối nhanh, cho phép Z/F/W/J, viết hoa đầu câu.
    3. **Gõ tắt (Macro):** Quản lý bảng gõ tắt, thêm/sửa/xoá, nhập/xuất tệp văn bản (`.txt`).
    4. **Hệ thống:** Khởi động cùng Windows, sửa lỗi gợi ý tự động trên thanh địa chỉ trình duyệt (Chrome, Edge, Brave, Cốc Cốc, Firefox, Arc), phím tạm tắt nhanh Ctrl/Alt.
- **Chuyển chế độ gõ Việt / Anh:** Nhấp đơn chuột trái (single-click) vào biểu tượng khay, hoặc dùng phím tắt (`Ctrl + Shift` hoặc `Alt + Z`).
- **Lưu ý trên Windows 11:** Windows 11 mặc định đưa các biểu tượng khay hệ thống mới vào menu ẩn (dấu `^`). Người dùng có thể kéo biểu tượng chữ **V**/**E** ra ngoài thanh taskbar hoặc bật hiển thị tại: **Settings → Personalization → Taskbar → Other system tray icons**.

## Known Limits

- **Elevated applications (Admin):** Windows User Interface Privilege Isolation (UIPI) prevents lower-integrity processes from sending synthetic input to higher-integrity processes. When typing into applications running as Administrator (e.g., elevated cmd/powershell or Task Manager), MyOpenKey must also be run as Administrator.
- **Unsigned binary:** Unsigned executables may trigger Windows Defender SmartScreen warnings on first run ("Windows protected your PC"). Click "More info" -> "Run anyway".

## Đóng gói & phát hành

### Artifacts
Quy trình GitHub Release tự động xuất các tập tin:
- `MyOpenKey-<version>-setup.exe`: Bộ cài đặt Inno Setup 6 (cài đặt per-user vào `%LOCALAPPDATA%\Programs\MyOpenKey`, không đòi quyền Admin).
- `MyOpenKey-<version>-windows-portable.zip`: Bản portable đóng gói file thực thi `MyOpenKey.exe` và `LICENSE`.
- `MyOpenKey-<version>-windows-SHA256.txt`: Mã băm SHA256 kiểm tra tính toàn vẹn của các tập tin release.

### Ký mã số (Code Signing)
- CI hỗ trợ ký mã tự động nếu thiết lập các repository secrets:
  - `WINDOWS_PFX_BASE64`: Chứng chỉ số định dạng PFX mã hóa base64.
  - `WINDOWS_PFX_PASSWORD`: Mật khẩu mở khóa chứng chỉ PFX.
- Ký cả `MyOpenKey.exe` lẫn bộ cài đặt `MyOpenKey-<version>-setup.exe` bằng `signtool.exe` (SHA256 + Digicert RFC 3161 timestamp).
- **Bản chưa ký (Unsigned):** Nếu không có chứng chỉ, Windows Defender SmartScreen sẽ hiện cảnh báo bảo vệ ("Windows protected your PC") khi chạy lần đầu. Người dùng chọn "More info" -> "Run anyway".

### Cập nhật ứng dụng (Auto-update)
- Tính năng cập nhật tự động qua Sparkle hiện chỉ có trên bản macOS.
- Phiên bản Windows chưa tích hợp cơ chế tự động cập nhật ngầm. Người dùng cập nhật bằng cách tải và chạy bộ cài đặt hoặc file ZIP mới từ GitHub Releases; bộ cài đặt sẽ tự động tắt tiến trình cũ và ghi đè phiên bản mới.
