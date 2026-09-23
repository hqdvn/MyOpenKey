//
//  ModernSettingsView.swift
//  MyOpenKey
//
//  Modern SwiftUI settings view with shadcn / macOS design aesthetics.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - State Observable
class SettingsState: ObservableObject {
    static let shared = SettingsState()
    let bridge = OpenKeyBridge.shared()

    @Published var inputMethod: Int = 1
    @Published var inputType: Int = 0
    @Published var codeTable: Int = 0

    @Published var switchKeyPreset: Int = 0
    @Published var switchKeyControl: Bool = false
    @Published var switchKeyOption: Bool = true
    @Published var switchKeyCommand: Bool = false
    @Published var switchKeyShift: Bool = false
    @Published var switchKeyBeep: Bool = false
    @Published var switchKeyChar: String = "z"

    // Spelling
    @Published var modernOrthography: Bool = true
    @Published var spelling: Bool = true
    @Published var restoreIfInvalidWord: Bool = true
    @Published var allowConsonantZFWJ: Bool = true
    @Published var tempOffSpelling: Bool = true
    @Published var fixRecommendBrowser: Bool = true

    // Typing Utils
    @Published var smartSwitchKey: Bool = true
    @Published var rememberCode: Bool = true
    @Published var tempOffOpenKey: Bool = false
    @Published var upperCaseFirstChar: Bool = true
    @Published var otherLanguage: Bool = true

    // Macro
    @Published var useMacro: Bool = true
    @Published var quickTelex: Bool = true
    @Published var useMacroInEnglishMode: Bool = true
    @Published var autoCapsMacro: Bool = true
    @Published var quickStartConsonant: Bool = true
    @Published var quickEndConsonant: Bool = true

    // System
    @Published var runOnStartup: Bool = true
    @Published var showUIOnStartup: Bool = false
    @Published var showIconOnDock: Bool = false
    @Published var grayIcon: Bool = true
    @Published var sendKeyStepByStep: Bool = false
    @Published var fixChromiumBrowser: Bool = false
    @Published var performLayoutCompat: Bool = false
    @Published var checkNewVersionOnStartup: Bool = true
    @Published var excludedApps: [String] = []

    var availableInputTypes: [String] { bridge.availableInputTypes }
    var availableCodeTables: [String] { bridge.availableCodeTables }
    var appVersion: String { bridge.appVersion }
    var appBuild: String { bridge.appBuild }
    var buildDate: String { bridge.buildDate }
    var availableSwitchKeyPresets: [String] { bridge.availableSwitchKeyPresets }

    private var isUpdating = false

    init() {
        syncFromBridge()
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsNotification), name: .openKeySettingsDidChange, object: nil)
    }

    @objc private func onSettingsNotification() {
        DispatchQueue.main.async {
            self.syncFromBridge()
        }
    }

    func syncFromBridge() {
        isUpdating = true
        inputMethod = bridge.inputMethod
        inputType = bridge.inputType
        codeTable = bridge.codeTable

        switchKeyPreset = bridge.switchKeyPreset
        switchKeyControl = bridge.switchKeyControl
        switchKeyOption = bridge.switchKeyOption
        switchKeyCommand = bridge.switchKeyCommand
        switchKeyShift = bridge.switchKeyShift
        switchKeyBeep = bridge.switchKeyBeep
        switchKeyChar = bridge.switchKeyChar

        modernOrthography = bridge.modernOrthography
        spelling = bridge.spelling
        restoreIfInvalidWord = bridge.restoreIfInvalidWord
        allowConsonantZFWJ = bridge.allowConsonantZFWJ
        tempOffSpelling = bridge.tempOffSpelling
        fixRecommendBrowser = bridge.fixRecommendBrowser

        smartSwitchKey = bridge.smartSwitchKey
        rememberCode = bridge.rememberCode
        tempOffOpenKey = bridge.tempOffOpenKey
        upperCaseFirstChar = bridge.upperCaseFirstChar
        otherLanguage = bridge.otherLanguage

        useMacro = bridge.useMacro
        quickTelex = bridge.quickTelex
        useMacroInEnglishMode = bridge.useMacroInEnglishMode
        autoCapsMacro = bridge.autoCapsMacro
        quickStartConsonant = bridge.quickStartConsonant
        quickEndConsonant = bridge.quickEndConsonant

        runOnStartup = bridge.runOnStartup
        showUIOnStartup = bridge.showUIOnStartup
        showIconOnDock = bridge.showIconOnDock
        grayIcon = bridge.grayIcon
        sendKeyStepByStep = bridge.sendKeyStepByStep
        fixChromiumBrowser = bridge.fixChromiumBrowser
        performLayoutCompat = bridge.performLayoutCompat
        checkNewVersionOnStartup = bridge.checkNewVersionOnStartup
        excludedApps = bridge.excludedApps
        isUpdating = false
    }

    func save<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<OpenKeyBridge, T>, value: T) {
        guard !isUpdating else { return }
        bridge[keyPath: keyPath] = value
    }

    func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = "Chọn ứng dụng luôn dùng English"
        panel.prompt = "Thêm"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleId = Bundle(url: url)?.bundleIdentifier else { return }
        bridge.addExcludedApp(bundleId)
        syncFromBridge()
    }

    func removeExcludedApp(_ bundleId: String) {
        bridge.removeExcludedApp(bundleId)
        syncFromBridge()
    }

    func excludedAppName(_ bundleId: String) -> String {
        bridge.displayName(forBundleId: bundleId)
    }
}

// MARK: - Navigation Tabs
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Bộ gõ"
    case macro = "Gõ tắt"
    case system = "Hệ thống"
    case about = "Thông tin"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "keyboard"
        case .macro: return "text.badge.plus"
        case .system: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Main Settings View
public struct ModernSettingsView: View {
    @StateObject private var state = SettingsState.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var showResetAlert = false
    @State private var isCheckingUpdate = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar (shadcn pill tabs)
            HStack {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selectedTab == tab
                            ? Color(NSColor.selectedContentBackgroundColor).opacity(0.18)
                            : Color.white.opacity(0.001)
                        )
                        .foregroundColor(
                            selectedTab == tab
                            ? Color(NSColor.controlAccentColor)
                            : Color.secondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selectedTab == tab ? Color(NSColor.controlAccentColor).opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))

            Divider().opacity(0.6)

            // Content Area
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .general:
                        GeneralTabView(state: state)
                    case .macro:
                        MacroTabView(state: state)
                    case .system:
                        SystemTabView(state: state, isCheckingUpdate: $isCheckingUpdate)
                    case .about:
                        AboutTabView(state: state, isCheckingUpdate: $isCheckingUpdate)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.6)

            // Bottom Bar (macOS standard)
            HStack {
                Button("Khôi phục mặc định") {
                    showResetAlert = true
                }
                .font(.system(size: 12))
                .controlSize(.regular)
                .alert(isPresented: $showResetAlert) {
                    Alert(
                        title: Text("Thiết lập lại cấu hình"),
                        message: Text("Bạn có chắc chắn muốn khôi phục toàn bộ cài đặt mặc định của MyOpenKey không?"),
                        primaryButton: .destructive(Text("Khôi phục")) {
                            state.bridge.resetToDefaults()
                        },
                        secondaryButton: .cancel(Text("Không"))
                    )
                }

                Spacer()

                Button("Đóng") {
                    if let win = NSApp.windows.first(where: { $0.title.contains("MyOpenKey") }) {
                        win.close()
                    } else {
                        NSApp.keyWindow?.close()
                    }
                }
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Reusable shadcn Card & Row Components
struct GroupedCard<Content: View>: View {
    var title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 6)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.55), lineWidth: 1)
            )
        }
    }
}

struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Keyboard Badge (Kbd style)
struct KbdBadge: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    isActive
                    ? Color(NSColor.controlAccentColor)
                    : Color(NSColor.textBackgroundColor)
                )
                .foregroundColor(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isActive
                            ? Color(NSColor.controlAccentColor).opacity(0.8)
                            : Color(NSColor.separatorColor),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(isActive ? 0.15 : 0.05), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab 1: Bộ gõ
struct GeneralTabView: View {
    @ObservedObject var state: SettingsState

    var body: some View {
        VStack(spacing: 16) {
            // Main Input Config Card
            GroupedCard(title: "CẤU HÌNH GÕ CHÍNH") {
                SettingRow("Kiểu gõ", subtitle: "Phương thức gõ dấu tiếng Việt phổ biến") {
                    Picker("", selection: Binding(
                        get: { state.inputType },
                        set: { state.inputType = $0; state.save(\.inputType, value: $0) }
                    )) {
                        ForEach(0..<state.availableInputTypes.count, id: \.self) { idx in
                            Text(state.availableInputTypes[idx]).tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                Divider().opacity(0.4)

                SettingRow("Bảng mã", subtitle: "Chuẩn mã hoá ký tự văn bản") {
                    Picker("", selection: Binding(
                        get: { state.codeTable },
                        set: { state.codeTable = $0; state.save(\.codeTable, value: $0) }
                    )) {
                        ForEach(0..<state.availableCodeTables.count, id: \.self) { idx in
                            Text(state.availableCodeTables[idx]).tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                Divider().opacity(0.4)

                SettingRow("Chế độ hiện tại", subtitle: "Chuyển nhanh ngôn ngữ nhập liệu") {
                    Picker("", selection: Binding(
                        get: { state.inputMethod },
                        set: { state.inputMethod = $0; state.save(\.inputMethod, value: $0) }
                    )) {
                        Text("Tiếng Việt").tag(1)
                        Text("English").tag(0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                Divider().opacity(0.4)

                SettingRow("Phím chuyển chế độ", subtitle: state.switchKeyPreset == 6
                           ? "Cần đặt System Settings → Keyboard → Press 🌐 = Do Nothing"
                           : "Bấm tổ hợp này ở bất kỳ đâu để đổi nhanh V / E") {
                    Picker("", selection: Binding(
                        get: { state.switchKeyPreset },
                        set: { state.switchKeyPreset = $0; state.save(\.switchKeyPreset, value: $0) }
                    )) {
                        ForEach(0..<state.availableSwitchKeyPresets.count, id: \.self) { idx in
                            Text(state.availableSwitchKeyPresets[idx]).tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 175)
                }

                Divider().opacity(0.4)

                SettingRow("Âm thanh thông báo", subtitle: "Phát tiếng bíp ngắn mỗi khi chuyển chế độ") {
                    Toggle("", isOn: Binding(
                        get: { state.switchKeyBeep },
                        set: { state.switchKeyBeep = $0; state.save(\.switchKeyBeep, value: $0) }
                    ))
                    .toggleStyle(.switch)
                    .accessibilityLabel("Âm thanh thông báo")
                }
            }

            // Spelling Card
            GroupedCard(title: "CHÍNH TẢ") {
                SettingRow("Kiểm tra chính tả", subtitle: "Hạn chế lỗi chính tả khi gõ tiếng Việt") {
                    Toggle("", isOn: Binding(
                        get: { state.spelling },
                        set: { state.spelling = $0; state.save(\.spelling, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Tự khôi phục phím với từ sai", subtitle: "Tự phục hồi các ký tự đã nhập khi từ không hợp lệ") {
                    Toggle("", isOn: Binding(
                        get: { state.restoreIfInvalidWord },
                        set: { state.restoreIfInvalidWord = $0; state.save(\.restoreIfInvalidWord, value: $0) }
                    ))
                    .toggleStyle(.switch)
                    .disabled(!state.spelling)
                }

                Divider().opacity(0.4)

                SettingRow("Cho phép \"z, w, j, f\" làm phụ âm", subtitle: "Vẫn chấp nhận các ký tự này làm phụ âm đầu") {
                    Toggle("", isOn: Binding(
                        get: { state.allowConsonantZFWJ },
                        set: { state.allowConsonantZFWJ = $0; state.save(\.allowConsonantZFWJ, value: $0) }
                    ))
                    .toggleStyle(.switch)
                    .disabled(!state.spelling)
                }

                Divider().opacity(0.4)

                SettingRow("Tạm tắt chính tả bằng phím ⌃", subtitle: "Nhấn Control để gõ từ ngoại lai (Đắk Lắk, Krông...)") {
                    Toggle("", isOn: Binding(
                        get: { state.tempOffSpelling },
                        set: { state.tempOffSpelling = $0; state.save(\.tempOffSpelling, value: $0) }
                    ))
                    .toggleStyle(.switch)
                    .disabled(!state.spelling)
                }

                Divider().opacity(0.4)

                SettingRow("Đặt dấu oà, uý (kiểu mới)", subtitle: "Đặt dấu ở âm chính thay vì òa, úy theo kiểu cũ") {
                    Toggle("", isOn: Binding(
                        get: { state.modernOrthography },
                        set: { state.modernOrthography = $0; state.save(\.modernOrthography, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }
            }

            // Typing Utilities Card
            GroupedCard(title: "TIỆN ÍCH") {
                SettingRow("Chuyển chế độ thông minh", subtitle: "Tự ghi nhớ chế độ Tiếng Việt/English cho từng ứng dụng") {
                    Toggle("", isOn: Binding(
                        get: { state.smartSwitchKey },
                        set: { state.smartSwitchKey = $0; state.save(\.smartSwitchKey, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Tự ghi nhớ bảng mã theo ứng dụng", subtitle: "Tự chọn bảng mã VNI/TCVN3 khi mở Photoshop, CAD...") {
                    Toggle("", isOn: Binding(
                        get: { state.rememberCode },
                        set: { state.rememberCode = $0; state.save(\.rememberCode, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Viết Hoa chữ cái đầu câu", subtitle: "Tự động viết hoa sau dấu chấm kết câu hoặc xuống dòng") {
                    Toggle("", isOn: Binding(
                        get: { state.upperCaseFirstChar },
                        set: { state.upperCaseFirstChar = $0; state.save(\.upperCaseFirstChar, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Tạm tắt OpenKey bằng phím ⌘", subtitle: "Nhấn Command để tạm dừng bỏ dấu cho từ hiện tại") {
                    Toggle("", isOn: Binding(
                        get: { state.tempOffOpenKey },
                        set: { state.tempOffOpenKey = $0; state.save(\.tempOffOpenKey, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Tắt khi bộ gõ hệ thống khác tiếng Anh", subtitle: "Tự động tắt MyOpenKey khi chuyển sang bàn phím khác") {
                    Toggle("", isOn: Binding(
                        get: { state.otherLanguage },
                        set: { state.otherLanguage = $0; state.save(\.otherLanguage, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Sửa lỗi gợi ý (trình duyệt, Excel)", subtitle: "Khắc phục lỗi nhảy chữ và đúp từ trên thanh địa chỉ") {
                    Toggle("", isOn: Binding(
                        get: { state.fixRecommendBrowser },
                        set: { state.fixRecommendBrowser = $0; state.save(\.fixRecommendBrowser, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }
            }
        }
    }
}

// MARK: - Tab 2: Gõ tắt
struct MacroTabView: View {
    @ObservedObject var state: SettingsState

    var body: some View {
        VStack(spacing: 16) {
            GroupedCard(title: "GÕ TẮT (MACRO)") {
                SettingRow("Cho phép gõ tắt", subtitle: "Tự động thay thế từ viết tắt theo bảng định nghĩa") {
                    Toggle("", isOn: Binding(
                        get: { state.useMacro },
                        set: { state.useMacro = $0; state.save(\.useMacro, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Gõ tắt cả khi tắt gõ tiếng Việt", subtitle: "Vẫn kích hoạt gõ tắt khi đang ở chế độ tiếng Anh") {
                    Toggle("", isOn: Binding(
                        get: { state.useMacroInEnglishMode },
                        set: { state.useMacroInEnglishMode = $0; state.save(\.useMacroInEnglishMode, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Tự động viết hoa theo phím tắt", subtitle: "ko=không ➔ Ko=Không, KO=KHÔNG") {
                    Toggle("", isOn: Binding(
                        get: { state.autoCapsMacro },
                        set: { state.autoCapsMacro = $0; state.save(\.autoCapsMacro, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Danh sách từ gõ tắt", subtitle: "Xem và chỉnh sửa bảng từ gõ tắt cá nhân") {
                    Button("Bảng gõ tắt...") {
                        state.bridge.openMacroWindow()
                    }
                    .controlSize(.regular)
                }
            }

            GroupedCard(title: "GÕ NHANH (QUICK TELEX)") {
                SettingRow("Gõ nhanh phụ âm ghép", subtitle: "cc=ch, gg=gi, kk=kh, nn=ng, qq=qu, pp=ph, tt=th") {
                    Toggle("", isOn: Binding(
                        get: { state.quickTelex },
                        set: { state.quickTelex = $0; state.save(\.quickTelex, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Gõ tắt phụ âm đầu", subtitle: "Thay nhanh: f→ph, j→gi, w→qu (fải→phải, wên→quên)") {
                    Toggle("", isOn: Binding(
                        get: { state.quickStartConsonant },
                        set: { state.quickStartConsonant = $0; state.save(\.quickStartConsonant, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Gõ tắt phụ âm cuối", subtitle: "Thay nhanh: g→ng, h→nh, k→ch (nhah→nhanh, bák→bách)") {
                    Toggle("", isOn: Binding(
                        get: { state.quickEndConsonant },
                        set: { state.quickEndConsonant = $0; state.save(\.quickEndConsonant, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }
            }
        }
    }
}

// MARK: - Tab 3: Hệ thống
struct SystemTabView: View {
    @ObservedObject var state: SettingsState
    @Binding var isCheckingUpdate: Bool

    var body: some View {
        VStack(spacing: 16) {
            GroupedCard(title: "KHỞI ĐỘNG & GIAO DIỆN") {
                SettingRow("Khởi động cùng macOS", subtitle: "Tự động chạy MyOpenKey mỗi khi bật máy tính") {
                    Toggle("", isOn: Binding(
                        get: { state.runOnStartup },
                        set: { state.runOnStartup = $0; state.save(\.runOnStartup, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Bật bảng này khi khởi động", subtitle: "Mở bảng điều khiển mỗi khi khởi chạy chương trình") {
                    Toggle("", isOn: Binding(
                        get: { state.showUIOnStartup },
                        set: { state.showUIOnStartup = $0; state.save(\.showUIOnStartup, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Hiện biểu tượng trên thanh Dock", subtitle: "Hiển thị icon ứng dụng trên thanh Dock của macOS") {
                    Toggle("", isOn: Binding(
                        get: { state.showIconOnDock },
                        set: { state.showIconOnDock = $0; state.save(\.showIconOnDock, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Biểu tượng hiện đại trên menu bar", subtitle: "Sử dụng icon đơn sắc phẳng phù hợp với macOS mới") {
                    Toggle("", isOn: Binding(
                        get: { state.grayIcon },
                        set: { state.grayIcon = $0; state.save(\.grayIcon, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }
            }

            GroupedCard(title: "TƯƠNG THÍCH") {
                SettingRow("Gửi từng phím (Step-by-step)", subtitle: "Chỉ bật nếu bạn gặp lỗi gõ chữ trên một số phần mềm cũ") {
                    Toggle("", isOn: Binding(
                        get: { state.sendKeyStepByStep },
                        set: { state.sendKeyStepByStep = $0; state.save(\.sendKeyStepByStep, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Sửa lỗi trên Chromium (beta)", subtitle: "Hạn chế lỗi đúp từ trên Google Chrome, Edge, Brave") {
                    Toggle("", isOn: Binding(
                        get: { state.fixChromiumBrowser },
                        set: { state.fixChromiumBrowser = $0; state.save(\.fixChromiumBrowser, value: $0) }
                    ))
                    .toggleStyle(.switch)
                    .disabled(!state.fixRecommendBrowser)
                }

                Divider().opacity(0.4)

                SettingRow("Tương thích Layout bàn phím khác", subtitle: "Cho phép gõ Telex trên layout Dvorak, Coleman...") {
                    Toggle("", isOn: Binding(
                        get: { state.performLayoutCompat },
                        set: { state.performLayoutCompat = $0; state.save(\.performLayoutCompat, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }
            }

            GroupedCard(title: "ỨNG DỤNG LUÔN DÙNG ENGLISH") {
                if state.excludedApps.isEmpty {
                    SettingRow("Chưa có ứng dụng nào", subtitle: "MyOpenKey tự chuyển English khi mở các app này") {
                        EmptyView()
                    }
                } else {
                    ForEach(Array(state.excludedApps.enumerated()), id: \.element) { index, bundleId in
                        SettingRow(state.excludedAppName(bundleId), subtitle: bundleId) {
                            Button(action: { state.removeExcludedApp(bundleId) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                        }
                        if index < state.excludedApps.count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }

                Divider().opacity(0.4)

                SettingRow("Thêm ứng dụng", subtitle: "Game, Terminal, IDE... sẽ luôn gõ English") {
                    Button("Thêm...") {
                        state.addExcludedApp()
                    }
                    .controlSize(.regular)
                }
            }

            GroupedCard(title: "CẬP NHẬT") {
                SettingRow("Kiểm tra bản mới lúc khởi động", subtitle: "Tự động thông báo khi có phiên bản MyOpenKey mới hơn") {
                    Toggle("", isOn: Binding(
                        get: { state.checkNewVersionOnStartup },
                        set: { state.checkNewVersionOnStartup = $0; state.save(\.checkNewVersionOnStartup, value: $0) }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().opacity(0.4)

                SettingRow("Kiểm tra cập nhật (Sparkle)", subtitle: "Tự động tải ngầm và cài đặt phiên bản mới nhất") {
                    Button("Kiểm tra bản mới...") {
                        SparkleUpdater.shared.checkForUpdates()
                    }
                    .controlSize(.regular)
                }
            }
        }
    }
}

// MARK: - Tab 4: Thông tin
struct AboutTabView: View {
    @ObservedObject var state: SettingsState
    @Binding var isCheckingUpdate: Bool

    var body: some View {
        VStack(spacing: 18) {
            // App Banner Header
            VStack(spacing: 8) {
                if let appIcon = NSImage(named: "Icon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                }

                Text("MyOpenKey")
                    .font(.system(size: 22, weight: .bold))

                Text("Phiên bản \(state.appVersion) (build \(state.appBuild)) · \(state.buildDate)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Text("Nguồn mở")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())

                    Text("GNU GPLv3")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 4)

            // Credit Information Card
            GroupedCard(title: "THÔNG TIN PHÁT HÀNH & TÁC GIẢ") {
                SettingRow("Tác giả phát triển", subtitle: "Huỳnh Quốc Đạt © 2026") {
                    Link("hqd.vn", destination: URL(string: "https://hqd.vn")!)
                        .font(.system(size: 12, weight: .medium))
                }

                Divider().opacity(0.4)

                SettingRow("Mã nguồn dự án", subtitle: "github.com/hqdvn/MyOpenKey") {
                    Link("GitHub", destination: URL(string: "https://github.com/hqdvn/MyOpenKey")!)
                        .font(.system(size: 12, weight: .medium))
                }

                Divider().opacity(0.4)

                SettingRow("Liên hệ & hỗ trợ", subtitle: "work@hqd.vn") {
                    Link("Gửi email", destination: URL(string: "mailto:work@hqd.vn")!)
                        .font(.system(size: 12, weight: .medium))
                }

                Divider().opacity(0.4)

                SettingRow("Ghi nhận nguồn gốc", subtitle: "Phát triển dựa trên bộ máy OpenKey của Mai Vũ Tuyên (GPLv3)") {
                    Link("Repo gốc", destination: URL(string: "https://github.com/tuyenvm/OpenKey")!)
                        .font(.system(size: 12, weight: .medium))
                }
            }

            // Description note
            Text("MyOpenKey là bản sửa đổi của OpenKey, kế thừa trọn vẹn bộ máy gõ tiếng Việt mượt mà của tác giả Mai Vũ Tuyên và được tái thiết kế giao diện theo chuẩn hiện đại của macOS.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Hosting Controller Factory for Objective-C
@objc public class ModernPanel: NSObject {
    @objc public static func createViewController() -> NSViewController {
        let hosting = NSHostingController(rootView: ModernSettingsView())
        hosting.view.frame = NSRect(x: 0, y: 0, width: 580, height: 620)
        return hosting
    }
}

// MARK: - Modern Macro Manager (Thiết lập gõ tắt)

class MacroState: ObservableObject {
    static let shared = MacroState()
    let bridge = MacroBridge.shared()

    @Published var macros: [MacroItem] = []
    @Published var searchText: String = ""
    @Published var inputShortcut: String = ""
    @Published var inputContent: String = ""
    @Published var selectedShortcut: String? = nil
    @Published var autoCapsMacro: Bool = true
    @Published var alertMessage: String? = nil

    var isEditing: Bool {
        selectedShortcut != nil || (!inputShortcut.isEmpty && macros.contains(where: { $0.shortcut == inputShortcut }))
    }

    var filteredMacros: [MacroItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return macros
        }
        let query = searchText.lowercased()
        return macros.filter {
            $0.shortcut.lowercased().contains(query) || $0.content.lowercased().contains(query)
        }
    }

    init() {
        reload()
    }

    func reload() {
        macros = bridge.allMacros()
        autoCapsMacro = bridge.autoCapsMacro
    }

    func select(_ item: MacroItem) {
        selectedShortcut = item.shortcut
        inputShortcut = item.shortcut
        inputContent = item.content
    }

    func clearSelection() {
        selectedShortcut = nil
        inputShortcut = ""
        inputContent = ""
    }

    func addOrUpdate() {
        let s = inputShortcut.trimmingCharacters(in: .whitespaces)
        let c = inputContent.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty && !c.isEmpty else {
            alertMessage = "Vui lòng nhập cả từ gõ tắt và nội dung thay thế!"
            return
        }
        _ = bridge.addOrUpdateMacro(s, content: c)
        clearSelection()
        reload()
    }

    func delete(shortcut: String) {
        _ = bridge.deleteMacro(shortcut)
        if selectedShortcut == shortcut {
            clearSelection()
        }
        reload()
    }

    func toggleAutoCaps(_ val: Bool) {
        autoCapsMacro = val
        bridge.autoCapsMacro = val
    }

    func loadFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Chọn file dữ liệu gõ tắt"
        panel.prompt = "Mở"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            let alert = NSAlert()
            alert.messageText = "Nạp dữ liệu gõ tắt"
            alert.informativeText = "Bạn có muốn giữ lại các từ gõ tắt hiện tại không?"
            alert.addButton(withTitle: "Giữ lại")
            alert.addButton(withTitle: "Ghi đè tất cả")
            let keep = (alert.runModal() == .alertFirstButtonReturn)
            _ = bridge.load(fromFile: url.path, keepCurrent: keep)
            reload()
        }
    }

    func exportToFile() {
        let panel = NSSavePanel()
        panel.title = "Lưu dữ liệu gõ tắt"
        panel.prompt = "Lưu"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "MyOpenKeyMacro.txt"
        if panel.runModal() == .OK, let url = panel.url {
            _ = bridge.export(toFile: url.path)
        }
    }
}

public struct ModernMacroView: View {
    @StateObject private var state = MacroState.shared
    @FocusState private var isShortcutFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Header Card: Input Form
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Từ gõ tắt")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        TextField("vd: ko, ng, vn", text: $state.inputShortcut)
                            .textFieldStyle(.roundedBorder)
                            .focused($isShortcutFocused)
                            .frame(width: 140)
                            .onSubmit {
                                state.addOrUpdate()
                                isShortcutFocused = true
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nội dung thay thế")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        TextField("vd: không, người, Việt Nam", text: $state.inputContent)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                state.addOrUpdate()
                                isShortcutFocused = true
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(" ")
                            .font(.system(size: 11))
                        HStack(spacing: 6) {
                            Button(action: {
                                state.addOrUpdate()
                                isShortcutFocused = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: state.isEditing ? "checkmark" : "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(state.isEditing ? "Lưu" : "Thêm")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                            if state.selectedShortcut != nil {
                                Button("Hủy") {
                                    state.clearSelection()
                                }
                                .controlSize(.regular)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider().opacity(0.6)

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Tìm kiếm từ gõ tắt hoặc nội dung...", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !state.searchText.isEmpty {
                    Button(action: { state.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("\(state.filteredMacros.count) từ gõ tắt")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider().opacity(0.6)

            // Macro List Content
            ScrollView(.vertical, showsIndicators: true) {
                if state.filteredMacros.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(state.searchText.isEmpty ? "Chưa có từ gõ tắt nào" : "Không tìm thấy từ phù hợp")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Nhập từ viết tắt và nội dung đầy đủ ở trên để thêm mới.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(state.filteredMacros, id: \.shortcut) { item in
                            HStack(spacing: 12) {
                                Text(item.shortcut)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        state.selectedShortcut == item.shortcut
                                        ? Color(NSColor.controlAccentColor)
                                        : Color(NSColor.textBackgroundColor)
                                    )
                                    .foregroundColor(state.selectedShortcut == item.shortcut ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 1)
                                    )

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.6))

                                Text(item.content)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer()

                                Button(action: {
                                    state.delete(shortcut: item.shortcut)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help("Xóa từ gõ tắt này")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                state.selectedShortcut == item.shortcut
                                ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15)
                                : Color(NSColor.controlBackgroundColor)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(
                                        state.selectedShortcut == item.shortcut
                                        ? Color(NSColor.controlAccentColor).opacity(0.4)
                                        : Color(NSColor.separatorColor).opacity(0.4),
                                        lineWidth: 1
                                    )
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                state.select(item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))

            Divider().opacity(0.6)

            // Bottom Bar
            HStack(spacing: 12) {
                Button(action: { state.loadFromFile() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 11))
                        Text("Nạp từ file...")
                            .font(.system(size: 12))
                    }
                }
                .controlSize(.regular)

                Button(action: { state.exportToFile() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 11))
                        Text("Xuất ra file...")
                            .font(.system(size: 12))
                    }
                }
                .controlSize(.regular)

                Spacer()

                Toggle("Tự động viết hoa", isOn: Binding(
                    get: { state.autoCapsMacro },
                    set: { state.toggleAutoCaps($0) }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .help("Tự động viết hoa từ gõ tắt theo cách bạn gõ phím viết tắt (vd: ko=không, Ko=Không, KO=KHÔNG)")

                Button("Đóng") {
                    if let win = NSApp.windows.first(where: { $0.title.contains("gõ tắt") }) {
                        win.close()
                    } else {
                        NSApp.keyWindow?.close()
                    }
                }
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 620, height: 540)
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: Binding(
            get: { state.alertMessage != nil },
            set: { if !$0 { state.alertMessage = nil } }
        )) {
            Alert(
                title: Text("Gõ tắt"),
                message: Text(state.alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

@objc public class ModernMacroPanel: NSObject {
    @objc public static func createViewController() -> NSViewController {
        let hosting = NSHostingController(rootView: ModernMacroView())
        hosting.view.frame = NSRect(x: 0, y: 0, width: 620, height: 540)
        return hosting
    }
}

// MARK: - Modern Convert Tool (Công cụ chuyển mã)

class ConvertToolState: ObservableObject {
    static let shared = ConvertToolState()
    let bridge = ConvertToolBridge.shared()

    @Published var fromCode: Int = 0
    @Published var toCode: Int = 0
    @Published var caseOption: Int = 0
    @Published var removeMark: Bool = false
    @Published var alertWhenCompleted: Bool = true
    @Published var hotKeyPreset: Int = 0

    var availableCodeTables: [String] { bridge.availableCodeTables }
    var availableHotKeyPresets: [String] { bridge.availableHotKeyPresets }

    init() {
        reload()
    }

    func reload() {
        fromCode = bridge.fromCode
        toCode = bridge.toCode
        caseOption = bridge.caseOption
        removeMark = bridge.removeMark
        alertWhenCompleted = bridge.alertWhenCompleted
        hotKeyPreset = bridge.hotKeyPreset
    }

    func reverse() {
        bridge.reverseCodes()
        fromCode = bridge.fromCode
        toCode = bridge.toCode
    }

    func convertClipboard() {
        _ = bridge.convertClipboard(NSApp.keyWindow)
    }
}

public struct ModernConvertToolView: View {
    @StateObject private var state = ConvertToolState.shared

    let caseOptions = [
        "Không thay đổi",
        "SANG CHỮ HOA",
        "sang chữ thường",
        "Viết hoa chữ cái đầu câu",
        "Viết Hoa Mỗi Từ"
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Bảng mã chuyển đổi
                    GroupedCard(title: "BẢNG MÃ CHUYỂN ĐỔI") {
                        SettingRow("Bảng mã nguồn", subtitle: "Bảng mã của văn bản hiện tại trong clipboard") {
                            Picker("", selection: Binding(
                                get: { state.fromCode },
                                set: { state.fromCode = $0; state.bridge.fromCode = $0 }
                            )) {
                                ForEach(0..<state.availableCodeTables.count, id: \.self) { idx in
                                    Text(state.availableCodeTables[idx]).tag(idx)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 175)
                        }

                        Divider().opacity(0.4)

                        SettingRow("Đảo chiều chuyển mã", subtitle: "Hoán đổi nhanh giữa bảng mã nguồn và đích") {
                            Button(action: { state.reverse() }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 11))
                                    Text("Đảo chiều")
                                        .font(.system(size: 12))
                                }
                            }
                            .controlSize(.regular)
                        }

                        Divider().opacity(0.4)

                        SettingRow("Bảng mã đích", subtitle: "Bảng mã cần chuyển đổi sang (thường là Unicode)") {
                            Picker("", selection: Binding(
                                get: { state.toCode },
                                set: { state.toCode = $0; state.bridge.toCode = $0 }
                            )) {
                                ForEach(0..<state.availableCodeTables.count, id: \.self) { idx in
                                    Text(state.availableCodeTables[idx]).tag(idx)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 175)
                        }
                    }

                    // Tùy chọn định dạng chữ
                    GroupedCard(title: "TÙY CHỌN ĐỊNH DẠNG CHỮ") {
                        SettingRow("Chuyển đổi kiểu chữ", subtitle: "Thay đổi hoa / thường cho toàn bộ văn bản") {
                            Picker("", selection: Binding(
                                get: { state.caseOption },
                                set: { state.caseOption = $0; state.bridge.caseOption = $0 }
                            )) {
                                ForEach(0..<caseOptions.count, id: \.self) { idx in
                                    Text(caseOptions[idx]).tag(idx)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 195)
                        }

                        Divider().opacity(0.4)

                        SettingRow("Bỏ dấu tiếng Việt", subtitle: "Chuyển toàn bộ văn bản sang tiếng Việt không dấu") {
                            Toggle("", isOn: Binding(
                                get: { state.removeMark },
                                set: { state.removeMark = $0; state.bridge.removeMark = $0 }
                            ))
                            .toggleStyle(.switch)
                        }

                        Divider().opacity(0.4)

                        SettingRow("Thông báo sau khi hoàn tất", subtitle: "Hiển thị hộp thoại báo kết quả đã lưu vào clipboard") {
                            Toggle("", isOn: Binding(
                                get: { state.alertWhenCompleted },
                                set: { state.alertWhenCompleted = $0; state.bridge.alertWhenCompleted = $0 }
                            ))
                            .toggleStyle(.switch)
                        }
                    }

                    // Phím tắt chuyển nhanh
                    GroupedCard(title: "PHÍM TẮT CHUYỂN MÃ NHANH") {
                        SettingRow("Tổ hợp phím tắt", subtitle: "Chuyển mã clipboard ngay tức khắc mà không cần mở cửa sổ") {
                            Picker("", selection: Binding(
                                get: { state.hotKeyPreset },
                                set: { state.hotKeyPreset = $0; state.bridge.hotKeyPreset = $0 }
                            )) {
                                ForEach(0..<state.availableHotKeyPresets.count, id: \.self) { idx in
                                    Text(state.availableHotKeyPresets[idx]).tag(idx)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 210)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }

            Divider().opacity(0.6)

            // Bottom Bar
            HStack {
                Button(action: { state.convertClipboard() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                        Text("Chuyển mã Clipboard ngay")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)

                Spacer()

                Button("Đóng") {
                    if let win = NSApp.windows.first(where: { $0.title.contains("chuyển mã") }) {
                        win.close()
                    } else {
                        NSApp.keyWindow?.close()
                    }
                }
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 570)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

@objc public class ModernConvertPanel: NSObject {
    @objc public static func createViewController() -> NSViewController {
        let hosting = NSHostingController(rootView: ModernConvertToolView())
        hosting.view.frame = NSRect(x: 0, y: 0, width: 580, height: 570)
        return hosting
    }
}
