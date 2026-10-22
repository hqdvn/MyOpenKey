#include <windows.h>
#include <shellapi.h>
#include <commctrl.h>
#include <cwchar>
#include <vector>
#include "Macro.h"
#include "Hook.h"
#include "Settings.h"
#include "SettingsDlg.h"
#include "resource.h"

#define WM_TRAYICON (WM_APP + 1)
#define TIMER_HOOK_HEALTH 101
#define TIMER_TRAY_RETRY  102

#define ID_TRAY_SETTINGS          1000
#define ID_TRAY_VIETNAMESE        1001
#define ID_TRAY_ENGLISH           1002
#define ID_INPUT_TELEX            1010
#define ID_INPUT_VNI              1011
#define ID_INPUT_SIMPLETELEX1     1012
#define ID_INPUT_SIMPLETELEX2     1013
#define ID_CODE_UNICODE           1020
#define ID_CODE_TCVN3             1021
#define ID_CODE_VNI               1022
#define ID_CODE_COMPOUND          1023
#define ID_CODE_CP1258            1024
#define ID_OPT_CHECK_SPELLING     1030
#define ID_OPT_USE_MACRO          1031
#define ID_OPT_RUN_ON_STARTUP     1032
#define ID_TRAY_EXIT              1040

static const wchar_t* WINDOW_CLASS_NAME = L"MyOpenKey_MsgWndClass";
static const wchar_t* MUTEX_NAME = L"MyOpenKey_SingleInstance_Mutex";

static HINSTANCE s_hInstance = NULL;
static HICON s_hIconV = NULL;
static HICON s_hIconE = NULL;
static UINT s_uTaskbarRestartMsg = 0;
static bool s_trayAdded = false;
static int s_trayRetryCount = 0;

static HICON CreateTextIcon(wchar_t letter, COLORREF bgColor, COLORREF textColor) {
    int cx = 0;
    int cy = 0;
    HMODULE hUser32 = GetModuleHandleW(L"user32.dll");
    if (hUser32) {
        typedef UINT (WINAPI *GetDpiForSystemFn)();
        typedef int (WINAPI *GetSystemMetricsForDpiFn)(int, UINT);
        GetDpiForSystemFn pGetDpiForSystem = reinterpret_cast<GetDpiForSystemFn>(GetProcAddress(hUser32, "GetDpiForSystem"));
        GetSystemMetricsForDpiFn pGetSystemMetricsForDpi = reinterpret_cast<GetSystemMetricsForDpiFn>(GetProcAddress(hUser32, "GetSystemMetricsForDpi"));
        if (pGetDpiForSystem && pGetSystemMetricsForDpi) {
            UINT dpi = pGetDpiForSystem();
            cx = pGetSystemMetricsForDpi(SM_CXSMICON, dpi);
            cy = pGetSystemMetricsForDpi(SM_CYSMICON, dpi);
        }
    }
    if (cx <= 0) cx = GetSystemMetrics(SM_CXSMICON);
    if (cy <= 0) cy = GetSystemMetrics(SM_CYSMICON);
    if (cx <= 0) cx = 16;
    if (cy <= 0) cy = 16;

    HDC hdcScreen = GetDC(NULL);
    HDC hdcMem = CreateCompatibleDC(hdcScreen);

    BITMAPINFO bi = {};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = cx;
    bi.bmiHeader.biHeight = -cy; // top-down
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    void* pBits = nullptr;
    HBITMAP hbmColor = CreateDIBSection(hdcMem, &bi, DIB_RGB_COLORS, &pBits, NULL, 0);
    if (!hbmColor || !pBits) {
        DeleteDC(hdcMem);
        ReleaseDC(NULL, hdcScreen);
        return NULL;
    }
    memset(pBits, 0, static_cast<size_t>(cx * cy) * sizeof(uint32_t));

    HBITMAP hbmOld = static_cast<HBITMAP>(SelectObject(hdcMem, hbmColor));

    // Rounded rectangle shape
    int corner = cx / 3;
    if (corner < 2) corner = 2;
    HRGN hRgn = CreateRoundRectRgn(0, 0, cx + 1, cy + 1, corner, corner);
    HBRUSH hBrushBg = CreateSolidBrush(bgColor);
    FillRgn(hdcMem, hRgn, hBrushBg);
    DeleteObject(hBrushBg);

    // Draw letter
    SetBkMode(hdcMem, TRANSPARENT);
    SetTextColor(hdcMem, textColor);

    int fontHeight = -MulDiv(cy, 80, 100);
    HFONT hFont = CreateFontW(fontHeight, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                              DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                              ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
    HFONT hOldFont = static_cast<HFONT>(SelectObject(hdcMem, hFont));

    RECT rc = { 0, 0, cx, cy };
    wchar_t text[2] = { letter, 0 };
    DrawTextW(hdcMem, text, 1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);

    SelectObject(hdcMem, hOldFont);
    DeleteObject(hFont);

    SelectObject(hdcMem, hbmOld);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdcScreen);

    // Mask bitmap: 1bpp, DWORD-aligned stride.
    // 0 = inside (opaque / uses color bitmap), 1 = outside (transparent).
    int maskStride = ((cx + 31) / 32) * 4;
    std::vector<BYTE> maskBits(static_cast<size_t>(maskStride * cy), 0xFF);

    uint32_t* pixels = static_cast<uint32_t*>(pBits);
    for (int y = 0; y < cy; ++y) {
        for (int x = 0; x < cx; ++x) {
            int idx = y * cx + x;
            if (PtInRegion(hRgn, x, y)) {
                pixels[idx] |= 0xFF000000; // Opaque alpha
                int byteIdx = y * maskStride + (x / 8);
                int bitIdx = 7 - (x % 8);
                maskBits[static_cast<size_t>(byteIdx)] &= static_cast<BYTE>(~(1 << bitIdx));
            } else {
                pixels[idx] = 0; // Fully transparent
            }
        }
    }
    DeleteObject(hRgn);

    HBITMAP hbmMask = CreateBitmap(cx, cy, 1, 1, maskBits.data());

    ICONINFO ii = {};
    ii.fIcon = TRUE;
    ii.xHotspot = 0;
    ii.yHotspot = 0;
    ii.hbmMask = hbmMask;
    ii.hbmColor = hbmColor;

    HICON hIcon = CreateIconIndirect(&ii);

    DeleteObject(hbmColor);
    DeleteObject(hbmMask);

    return hIcon;
}

static void SetTrayTip(NOTIFYICONDATAW& nid, const wchar_t* tip) {
    wcsncpy_s(nid.szTip, tip, _TRUNCATE);
}

static bool AddTrayIcon(HWND hwnd) {
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(NOTIFYICONDATAW);
    nid.hWnd = hwnd;
    nid.uID = 1;
    nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    nid.uCallbackMessage = WM_TRAYICON;
    nid.hIcon = (vLanguage == 1) ? s_hIconV : s_hIconE;
    SetTrayTip(nid, (vLanguage == 1) ? L"MyOpenKey - Tiếng Việt" : L"MyOpenKey - English");
    if (Shell_NotifyIconW(NIM_ADD, &nid)) {
        s_trayAdded = true;
        return true;
    }
    return false;
}

static void UpdateTrayIcon(HWND hwnd) {
    if (!s_trayAdded) {
        AddTrayIcon(hwnd);
        return;
    }
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(NOTIFYICONDATAW);
    nid.hWnd = hwnd;
    nid.uID = 1;
    nid.uFlags = NIF_ICON | NIF_TIP;
    nid.hIcon = (vLanguage == 1) ? s_hIconV : s_hIconE;
    SetTrayTip(nid, (vLanguage == 1) ? L"MyOpenKey - Tiếng Việt" : L"MyOpenKey - English");
    Shell_NotifyIconW(NIM_MODIFY, &nid);
}

static void RemoveTrayIcon(HWND hwnd) {
    if (s_trayAdded) {
        NOTIFYICONDATAW nid = {};
        nid.cbSize = sizeof(NOTIFYICONDATAW);
        nid.hWnd = hwnd;
        nid.uID = 1;
        Shell_NotifyIconW(NIM_DELETE, &nid);
        s_trayAdded = false;
    }
}

static HMENU CreateContextMenu() {
    HMENU hMenu = CreatePopupMenu();
    HMENU hSubInput = CreatePopupMenu();
    HMENU hSubCode = CreatePopupMenu();

    AppendMenuW(hMenu, MF_STRING, ID_TRAY_SETTINGS, L"Bảng điều khiển…");
    SetMenuDefaultItem(hMenu, ID_TRAY_SETTINGS, FALSE);
    AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);

    AppendMenuW(hMenu, MF_STRING | (vLanguage == 1 ? MF_CHECKED : MF_UNCHECKED), ID_TRAY_VIETNAMESE, L"Tiếng Việt (Ctrl+Shift)");
    AppendMenuW(hMenu, MF_STRING | (vLanguage == 0 ? MF_CHECKED : MF_UNCHECKED), ID_TRAY_ENGLISH, L"English");
    AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);

    AppendMenuW(hSubInput, MF_STRING | (vInputType == 0 ? MF_CHECKED : MF_UNCHECKED), ID_INPUT_TELEX, L"Telex");
    AppendMenuW(hSubInput, MF_STRING | (vInputType == 1 ? MF_CHECKED : MF_UNCHECKED), ID_INPUT_VNI, L"VNI");
    AppendMenuW(hSubInput, MF_STRING | (vInputType == 2 ? MF_CHECKED : MF_UNCHECKED), ID_INPUT_SIMPLETELEX1, L"Simple Telex 1");
    AppendMenuW(hSubInput, MF_STRING | (vInputType == 3 ? MF_CHECKED : MF_UNCHECKED), ID_INPUT_SIMPLETELEX2, L"Simple Telex 2");
    AppendMenuW(hMenu, MF_POPUP, reinterpret_cast<UINT_PTR>(hSubInput), L"Kiểu gõ");

    AppendMenuW(hSubCode, MF_STRING | (vCodeTable == 0 ? MF_CHECKED : MF_UNCHECKED), ID_CODE_UNICODE, L"Unicode dựng sẵn");
    AppendMenuW(hSubCode, MF_STRING | (vCodeTable == 1 ? MF_CHECKED : MF_UNCHECKED), ID_CODE_TCVN3, L"TCVN3 (ABC)");
    AppendMenuW(hSubCode, MF_STRING | (vCodeTable == 2 ? MF_CHECKED : MF_UNCHECKED), ID_CODE_VNI, L"VNI Windows");
    AppendMenuW(hSubCode, MF_STRING | (vCodeTable == 3 ? MF_CHECKED : MF_UNCHECKED), ID_CODE_COMPOUND, L"Unicode tổ hợp");
    AppendMenuW(hSubCode, MF_STRING | (vCodeTable == 4 ? MF_CHECKED : MF_UNCHECKED), ID_CODE_CP1258, L"Vietnamese Locale (CP 1258)");
    AppendMenuW(hMenu, MF_POPUP, reinterpret_cast<UINT_PTR>(hSubCode), L"Bảng mã");

    AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);

    AppendMenuW(hMenu, MF_STRING | (vCheckSpelling ? MF_CHECKED : MF_UNCHECKED), ID_OPT_CHECK_SPELLING, L"Kiểm tra chính tả");
    AppendMenuW(hMenu, MF_STRING | (vUseMacro ? MF_CHECKED : MF_UNCHECKED), ID_OPT_USE_MACRO, L"Dùng macro");
    AppendMenuW(hMenu, MF_STRING | (Settings::IsRunOnStartup() ? MF_CHECKED : MF_UNCHECKED), ID_OPT_RUN_ON_STARTUP, L"Khởi động cùng Windows");

    AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);

    AppendMenuW(hMenu, MF_STRING, ID_TRAY_EXIT, L"Thoát");

    return hMenu;
}

static void ShowContextMenu(HWND hwnd) {
    POINT pt;
    GetCursorPos(&pt);
    SetForegroundWindow(hwnd);
    HMENU hMenu = CreateContextMenu();
    TrackPopupMenu(hMenu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, pt.x, pt.y, 0, hwnd, NULL);
    DestroyMenu(hMenu);
    PostMessageW(hwnd, WM_NULL, 0, 0);
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    if (uMsg == s_uTaskbarRestartMsg && s_uTaskbarRestartMsg != 0) {
        s_trayAdded = false;
        if (!AddTrayIcon(hwnd)) {
            s_trayRetryCount = 0;
            SetTimer(hwnd, TIMER_TRAY_RETRY, 1000, NULL);
        }
        return 0;
    }

    switch (uMsg) {
    case WM_CREATE:
        s_hIconV = CreateTextIcon(L'V', RGB(218, 41, 28), RGB(255, 255, 255));
        s_hIconE = CreateTextIcon(L'E', RGB(0, 120, 215), RGB(255, 255, 255));
        if (!AddTrayIcon(hwnd)) {
            s_trayRetryCount = 0;
            SetTimer(hwnd, TIMER_TRAY_RETRY, 1000, NULL);
        }
        Hook::Install(hwnd);
        SetTimer(hwnd, TIMER_HOOK_HEALTH, 5000, NULL);
        return 0;

    case WM_TIMER:
        if (wParam == TIMER_HOOK_HEALTH) {
            Hook::CheckHealth();
        } else if (wParam == TIMER_TRAY_RETRY) {
            s_trayRetryCount++;
            if (AddTrayIcon(hwnd) || s_trayRetryCount >= 30) {
                KillTimer(hwnd, TIMER_TRAY_RETRY);
            }
        }
        return 0;

    case WM_APP_LANGUAGE_CHANGED:
        UpdateTrayIcon(hwnd);
        Settings::Save();
        return 0;

    case WM_TRAYICON:
        if (lParam == WM_LBUTTONUP) {
            Hook::SwitchLanguage();
        } else if (lParam == WM_LBUTTONDBLCLK) {
            SettingsDlg::Show(s_hInstance, hwnd);
        } else if (lParam == WM_RBUTTONUP || lParam == WM_CONTEXTMENU) {
            ShowContextMenu(hwnd);
        }
        return 0;

    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case ID_TRAY_SETTINGS:
            SettingsDlg::Show(s_hInstance, hwnd);
            break;

        case ID_TRAY_VIETNAMESE:
            vLanguage = 1;
            UpdateTrayIcon(hwnd);
            Settings::Save();
            startNewSession();
            Hook::ClearSyncKey();
            break;

        case ID_TRAY_ENGLISH:
            vLanguage = 0;
            UpdateTrayIcon(hwnd);
            Settings::Save();
            startNewSession();
            Hook::ClearSyncKey();
            break;

        case ID_INPUT_TELEX:
            vInputType = 0;
            Settings::Save();
            startNewSession();
            break;

        case ID_INPUT_VNI:
            vInputType = 1;
            Settings::Save();
            startNewSession();
            break;

        case ID_INPUT_SIMPLETELEX1:
            vInputType = 2;
            Settings::Save();
            startNewSession();
            break;

        case ID_INPUT_SIMPLETELEX2:
            vInputType = 3;
            Settings::Save();
            startNewSession();
            break;

        case ID_CODE_UNICODE:
            vCodeTable = 0;
            onTableCodeChange();
            Hook::ClearSyncKey();
            Settings::Save();
            startNewSession();
            break;

        case ID_CODE_TCVN3:
            vCodeTable = 1;
            onTableCodeChange();
            Hook::ClearSyncKey();
            Settings::Save();
            startNewSession();
            break;

        case ID_CODE_VNI:
            vCodeTable = 2;
            onTableCodeChange();
            Hook::ClearSyncKey();
            Settings::Save();
            startNewSession();
            break;

        case ID_CODE_COMPOUND:
            vCodeTable = 3;
            onTableCodeChange();
            Hook::ClearSyncKey();
            Settings::Save();
            startNewSession();
            break;

        case ID_CODE_CP1258:
            vCodeTable = 4;
            onTableCodeChange();
            Hook::ClearSyncKey();
            Settings::Save();
            startNewSession();
            break;

        case ID_OPT_CHECK_SPELLING:
            vCheckSpelling = vCheckSpelling ? 0 : 1;
            vSetCheckSpelling();
            Settings::Save();
            break;

        case ID_OPT_USE_MACRO:
            vUseMacro = vUseMacro ? 0 : 1;
            Settings::Save();
            break;

        case ID_OPT_RUN_ON_STARTUP:
            Settings::SetRunOnStartup(!Settings::IsRunOnStartup());
            break;

        case ID_TRAY_EXIT:
            DestroyWindow(hwnd);
            break;
        }
        return 0;

    case WM_DESTROY:
        KillTimer(hwnd, TIMER_HOOK_HEALTH);
        KillTimer(hwnd, TIMER_TRAY_RETRY);
        RemoveTrayIcon(hwnd);
        Hook::Uninstall();
        if (s_hIconV) { DestroyIcon(s_hIconV); s_hIconV = NULL; }
        if (s_hIconE) { DestroyIcon(s_hIconE); s_hIconE = NULL; }
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcW(hwnd, uMsg, wParam, lParam);
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR pCmdLine, int nCmdShow) {
    (void)hPrevInstance;
    (void)pCmdLine;
    (void)nCmdShow;

    s_hInstance = hInstance;

    // Single instance check
    HANDLE hMutex = CreateMutexW(NULL, TRUE, MUTEX_NAME);
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        if (hMutex) CloseHandle(hMutex);
        HWND hwndExisting = FindWindowW(WINDOW_CLASS_NAME, NULL);
        if (hwndExisting) {
            SetForegroundWindow(hwndExisting);
        }
        return 0;
    }

    // Common controls for Tab, ListView
    INITCOMMONCONTROLSEX icex = {};
    icex.dwSize = sizeof(INITCOMMONCONTROLSEX);
    icex.dwICC = ICC_TAB_CLASSES | ICC_LISTVIEW_CLASSES | ICC_STANDARD_CLASSES;
    InitCommonControlsEx(&icex);

    // Load persisted settings
    Settings::Load();

    s_uTaskbarRestartMsg = RegisterWindowMessageW(L"TaskbarCreated");

    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(WNDCLASSEXW);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.hIcon = LoadIconW(hInstance, MAKEINTRESOURCEW(IDI_APPICON));
    wc.hIconSm = static_cast<HICON>(LoadImageW(hInstance, MAKEINTRESOURCEW(IDI_APPICON), IMAGE_ICON,
                                               GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON),
                                               LR_DEFAULTCOLOR));
    wc.lpszClassName = WINDOW_CLASS_NAME;

    if (!RegisterClassExW(&wc)) {
        if (hMutex) { ReleaseMutex(hMutex); CloseHandle(hMutex); }
        return 1;
    }

    HWND hwnd = CreateWindowExW(0, WINDOW_CLASS_NAME, L"MyOpenKey",
                                WS_POPUP, 0, 0, 0, 0,
                                NULL, NULL, hInstance, NULL);

    if (!hwnd) {
        if (hMutex) { ReleaseMutex(hMutex); CloseHandle(hMutex); }
        return 1;
    }

    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0)) {
        HWND hDlg = SettingsDlg::GetHwnd();
        if (hDlg && IsWindow(hDlg) && IsDialogMessageW(hDlg, &msg)) {
            continue;
        }
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    if (hMutex) {
        ReleaseMutex(hMutex);
        CloseHandle(hMutex);
    }

    return static_cast<int>(msg.wParam);
}
