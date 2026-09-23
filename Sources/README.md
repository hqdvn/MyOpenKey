# Cấu trúc mã nguồn MyOpenKey

Thư mục này chứa toàn bộ mã nguồn của dự án **MyOpenKey**:

- `OpenKey/engine/`: Bộ máy xử lý gõ tiếng Việt cốt lõi (Core Engine C++).
- `OpenKey/macOS/`: Ứng dụng dành cho macOS:
  - `ModernKey/`: Mã nguồn giao diện chính, cầu nối Objective-C (`OpenKeyBridge`) và giao diện hiện đại SwiftUI (`ModernSettingsView.swift`).
  - `OpenKeyHelper/`: Trình trợ giúp khởi động (legacy fallback).
  - `OpenKey.xcodeproj`: Dự án Xcode chính.

---

- **Tác giả:** Huỳnh Quốc Đạt ([hqd.vn](https://hqd.vn) · [work@hqd.vn](mailto:work@hqd.vn))
- **Mã nguồn gốc:** [OpenKey](https://github.com/tuyenvm/OpenKey) của Mai Vũ Tuyên (© 2019)
- **Giấy phép:** [GNU GPLv3](../LICENSE)
