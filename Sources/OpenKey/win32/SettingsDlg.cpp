#include "SettingsDlg.h"
#include "Settings.h"
#include "Engine.h"
#include "Macro.h"
#include "Hook.h"
#include "resource.h"

#include <commctrl.h>
#include <shellapi.h>
#include <commdlg.h>
#include <vector>
#include <string>

namespace SettingsDlg {

static HWND s_hwndSettings = NULL;
static HWND s_hwndMainOwner = NULL;
static HWND s_hTab = NULL;
static HWND s_hChildTabs[4] = { NULL, NULL, NULL, NULL };
static int s_activeTab = 0;

static std::wstring Utf8ToWide(const std::string& str) {
    if (str.empty()) return std::wstring();
    int len = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), static_cast<int>(str.length()), NULL, 0);
    if (len <= 0) return std::wstring();
    std::wstring result(static_cast<size_t>(len), 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), static_cast<int>(str.length()), &result[0], len);
    return result;
}

static std::string WideToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int len = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.length()), NULL, 0, NULL, NULL);
    if (len <= 0) return std::string();
    std::string result(static_cast<size_t>(len), 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.length()), &result[0], len, NULL, NULL);
    return result;
}

static void NotifyParentStateChanged() {
    if (s_hwndMainOwner && IsWindow(s_hwndMainOwner)) {
        PostMessageW(s_hwndMainOwner, WM_APP_LANGUAGE_CHANGED, 0, 0);
    }
}

// -------------------------------------------------------------
// Tab 1: Input (Bộ gõ)
// -------------------------------------------------------------
static INT_PTR CALLBACK TabInputDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    (void)lParam;
    switch (uMsg) {
    case WM_INITDIALOG: {
        HWND hComboInput = GetDlgItem(hDlg, IDC_COMBO_INPUT_TYPE);
        SendMessageW(hComboInput, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"Telex"));
        SendMessageW(hComboInput, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"VNI"));
        SendMessageW(hComboInput, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"Simple Telex 1"));
        SendMessageW(hComboInput, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"Simple Telex 2"));
        SendMessageW(hComboInput, CB_SETCURSEL, static_cast<WPARAM>(vInputType), 0);

        HWND hComboCode = GetDlgItem(hDlg, IDC_COMBO_CODE_TABLE);
        SendMessageW(hComboCode, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"Unicode dựng sẵn"));
        SendMessageW(hComboCode, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"TCVN3 (ABC)"));
        SendMessageW(hComboCode, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"VNI Windows"));
        SendMessageW(hComboCode, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"Unicode tổ hợp"));
        SendMessageW(hComboCode, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"Vietnamese Locale (CP 1258)"));
        SendMessageW(hComboCode, CB_SETCURSEL, static_cast<WPARAM>(vCodeTable), 0);

        bool isCtrlShift = (GET_SWITCH_KEY(vSwitchKeyStatus) == 0xFE);
        CheckRadioButton(hDlg, IDC_RADIO_CTRL_SHIFT, IDC_RADIO_ALT_Z,
                         isCtrlShift ? IDC_RADIO_CTRL_SHIFT : IDC_RADIO_ALT_Z);

        CheckDlgButton(hDlg, IDC_CHK_BEEP, HAS_BEEP(vSwitchKeyStatus) ? BST_CHECKED : BST_UNCHECKED);
        return TRUE;
    }

    case WM_COMMAND: {
        WORD id = LOWORD(wParam);
        WORD code = HIWORD(wParam);

        if (id == IDC_COMBO_INPUT_TYPE && code == CBN_SELCHANGE) {
            int sel = static_cast<int>(SendMessageW(GetDlgItem(hDlg, IDC_COMBO_INPUT_TYPE), CB_GETCURSEL, 0, 0));
            if (sel >= 0 && sel <= 3) {
                vInputType = sel;
                startNewSession();
                Settings::Save();
            }
            return TRUE;
        }

        if (id == IDC_COMBO_CODE_TABLE && code == CBN_SELCHANGE) {
            int sel = static_cast<int>(SendMessageW(GetDlgItem(hDlg, IDC_COMBO_CODE_TABLE), CB_GETCURSEL, 0, 0));
            if (sel >= 0 && sel <= 4) {
                vCodeTable = sel;
                onTableCodeChange();
                Hook::ClearSyncKey();
                startNewSession();
                Settings::Save();
            }
            return TRUE;
        }

        if (id == IDC_RADIO_CTRL_SHIFT && code == BN_CLICKED) {
            vSwitchKeyStatus = 0xFE0009FE | (vSwitchKeyStatus & 0x8000);
            Settings::Save();
            return TRUE;
        }

        if (id == IDC_RADIO_ALT_Z && code == BN_CLICKED) {
            vSwitchKeyStatus = 0x5A00025A | (vSwitchKeyStatus & 0x8000);
            Settings::Save();
            return TRUE;
        }

        if (id == IDC_CHK_BEEP && code == BN_CLICKED) {
            bool checked = (IsDlgButtonChecked(hDlg, IDC_CHK_BEEP) == BST_CHECKED);
            if (checked) {
                vSwitchKeyStatus |= 0x8000;
            } else {
                vSwitchKeyStatus &= ~0x8000;
            }
            Settings::Save();
            return TRUE;
        }
        break;
    }
    }
    return FALSE;
}

// -------------------------------------------------------------
// Tab 2: Spelling & Quick Typing (Chính tả & gõ nhanh)
// -------------------------------------------------------------
static INT_PTR CALLBACK TabSpellingDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    (void)lParam;
    switch (uMsg) {
    case WM_INITDIALOG:
        CheckDlgButton(hDlg, IDC_CHK_SPELLING, vCheckSpelling ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_MODERN_ORTHO, vUseModernOrthography ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_RESTORE_SPELL, vRestoreIfWrongSpelling ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_FREE_MARK, vFreeMark ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_AUTO_UPPER, vUpperCaseFirstChar ? BST_CHECKED : BST_UNCHECKED);

        CheckDlgButton(hDlg, IDC_CHK_QUICK_TELEX, vQuickTelex ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_QUICK_START, vQuickStartConsonant ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_QUICK_END, vQuickEndConsonant ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_ALLOW_ZFWJ, vAllowConsonantZFWJ ? BST_CHECKED : BST_UNCHECKED);
        return TRUE;

    case WM_COMMAND: {
        WORD id = LOWORD(wParam);
        if (HIWORD(wParam) == BN_CLICKED) {
            switch (id) {
            case IDC_CHK_SPELLING:
                vCheckSpelling = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                vSetCheckSpelling();
                Settings::Save();
                return TRUE;

            case IDC_CHK_MODERN_ORTHO:
                vUseModernOrthography = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_RESTORE_SPELL:
                vRestoreIfWrongSpelling = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_FREE_MARK:
                vFreeMark = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_AUTO_UPPER:
                vUpperCaseFirstChar = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_QUICK_TELEX:
                vQuickTelex = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_QUICK_START:
                vQuickStartConsonant = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_QUICK_END:
                vQuickEndConsonant = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_ALLOW_ZFWJ:
                vAllowConsonantZFWJ = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;
            }
        }
        break;
    }
    }
    return FALSE;
}

// -------------------------------------------------------------
// Tab 3: Macro (Gõ tắt)
// -------------------------------------------------------------
static void ReloadMacroListView(HWND hList) {
    ListView_DeleteAllItems(hList);

    std::vector<std::vector<Uint32>> keys;
    std::vector<std::string> macroTexts;
    std::vector<std::string> macroContents;
    getAllMacro(keys, macroTexts, macroContents);

    for (size_t i = 0; i < macroTexts.size(); ++i) {
        std::wstring wKey = Utf8ToWide(macroTexts[i]);
        std::wstring wText = Utf8ToWide(macroContents[i]);

        LVITEMW item = {};
        item.mask = LVIF_TEXT;
        item.iItem = static_cast<int>(i);
        item.iSubItem = 0;
        item.pszText = const_cast<LPWSTR>(wKey.c_str());
        ListView_InsertItem(hList, &item);

        ListView_SetItemText(hList, static_cast<int>(i), 1, const_cast<LPWSTR>(wText.c_str()));
    }
}

static INT_PTR CALLBACK TabMacroDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
    case WM_INITDIALOG: {
        CheckDlgButton(hDlg, IDC_CHK_USE_MACRO, vUseMacro ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_MACRO_ENGLISH, vUseMacroInEnglishMode ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_AUTO_CAPS_MACRO, vAutoCapsMacro ? BST_CHECKED : BST_UNCHECKED);

        HWND hList = GetDlgItem(hDlg, IDC_LIST_MACRO);
        ListView_SetExtendedListViewStyle(hList, LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES);

        LVCOLUMNW col = {};
        col.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM;

        col.cx = 95;
        wchar_t col1[] = L"Từ gõ tắt";
        col.pszText = col1;
        ListView_InsertColumn(hList, 0, &col);

        col.cx = 200;
        wchar_t col2[] = L"Nội dung";
        col.pszText = col2;
        ListView_InsertColumn(hList, 1, &col);

        ReloadMacroListView(hList);
        return TRUE;
    }

    case WM_NOTIFY: {
        NMHDR* pnm = reinterpret_cast<NMHDR*>(lParam);
        if (pnm && pnm->idFrom == IDC_LIST_MACRO) {
            if (pnm->code == NM_CLICK || pnm->code == LVN_ITEMCHANGED) {
                HWND hList = GetDlgItem(hDlg, IDC_LIST_MACRO);
                int sel = ListView_GetNextItem(hList, -1, LVNI_SELECTED);
                if (sel >= 0) {
                    wchar_t szKey[256] = {};
                    wchar_t szText[1024] = {};
                    ListView_GetItemText(hList, sel, 0, szKey, 256);
                    ListView_GetItemText(hList, sel, 1, szText, 1024);
                    SetDlgItemTextW(hDlg, IDC_EDIT_MACRO_KEY, szKey);
                    SetDlgItemTextW(hDlg, IDC_EDIT_MACRO_TEXT, szText);
                }
            }
        }
        break;
    }

    case WM_COMMAND: {
        WORD id = LOWORD(wParam);
        WORD code = HIWORD(wParam);

        if (code == BN_CLICKED) {
            switch (id) {
            case IDC_CHK_USE_MACRO:
                vUseMacro = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_MACRO_ENGLISH:
                vUseMacroInEnglishMode = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_AUTO_CAPS_MACRO:
                vAutoCapsMacro = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_BTN_MACRO_ADD: {
                wchar_t szKey[512] = {};
                wchar_t szText[65536] = {};
                GetDlgItemTextW(hDlg, IDC_EDIT_MACRO_KEY, szKey, 512);
                GetDlgItemTextW(hDlg, IDC_EDIT_MACRO_TEXT, szText, 65536);

                std::string u8Key = WideToUtf8(szKey);
                std::string u8Text = WideToUtf8(szText);

                if (u8Key.empty()) {
                    MessageBoxW(hDlg, L"Vui lòng nhập từ gõ tắt.", L"Thông báo", MB_ICONWARNING | MB_OK);
                    return TRUE;
                }
                if (u8Key.length() > 255) {
                    MessageBoxW(hDlg, L"Từ gõ tắt không được vượt quá 255 byte.", L"Lỗi", MB_ICONWARNING | MB_OK);
                    return TRUE;
                }
                if (u8Text.length() > 65535) {
                    MessageBoxW(hDlg, L"Nội dung gõ tắt không được vượt quá 65535 byte.", L"Lỗi", MB_ICONWARNING | MB_OK);
                    return TRUE;
                }

                if (!addMacro(u8Key, u8Text)) {
                    MessageBoxW(hDlg, L"Không thể thêm từ gõ tắt.", L"Lỗi", MB_ICONWARNING | MB_OK);
                } else {
                    Settings::Save();
                    ReloadMacroListView(GetDlgItem(hDlg, IDC_LIST_MACRO));
                }
                return TRUE;
            }

            case IDC_BTN_MACRO_DEL: {
                wchar_t szKey[512] = {};
                GetDlgItemTextW(hDlg, IDC_EDIT_MACRO_KEY, szKey, 512);
                std::string u8Key = WideToUtf8(szKey);
                if (!u8Key.empty()) {
                    deleteMacro(u8Key);
                    Settings::Save();
                    ReloadMacroListView(GetDlgItem(hDlg, IDC_LIST_MACRO));
                    SetDlgItemTextW(hDlg, IDC_EDIT_MACRO_KEY, L"");
                    SetDlgItemTextW(hDlg, IDC_EDIT_MACRO_TEXT, L"");
                }
                return TRUE;
            }

            case IDC_BTN_MACRO_IMPORT: {
                wchar_t szFile[MAX_PATH] = {};
                OPENFILENAMEW ofn = {};
                ofn.lStructSize = sizeof(ofn);
                ofn.hwndOwner = hDlg;
                ofn.lpstrFile = szFile;
                ofn.nMaxFile = MAX_PATH;
                ofn.lpstrFilter = L"Tệp văn bản (*.txt)\0*.txt\0Tất cả tệp (*.*)\0*.*\0";
                ofn.nFilterIndex = 1;
                ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

                if (GetOpenFileNameW(&ofn)) {
                    std::string u8Path = WideToUtf8(szFile);
                    std::vector<Byte> backupData;
                    getMacroSaveData(backupData);

                    readFromFile(u8Path, true);

                    std::vector<std::vector<Uint32>> k;
                    std::vector<std::string> t;
                    std::vector<std::string> c;
                    getAllMacro(k, t, c);
                    if (t.empty() && !backupData.empty()) {
                        initMacroMap(backupData.data(), static_cast<int>(backupData.size()));
                        MessageBoxW(hDlg, L"Không thể nhập dữ liệu macro từ tệp này hoặc tệp không hợp lệ.",
                                    L"Lỗi nhập", MB_ICONWARNING | MB_OK);
                    } else {
                        Settings::Save();
                        ReloadMacroListView(GetDlgItem(hDlg, IDC_LIST_MACRO));
                        MessageBoxW(hDlg, L"Đã nhập bảng gõ tắt thành công.", L"Thông báo", MB_ICONINFORMATION | MB_OK);
                    }
                }
                return TRUE;
            }

            case IDC_BTN_MACRO_EXPORT: {
                wchar_t szFile[MAX_PATH] = L"MyOpenKey_Macro.txt";
                OPENFILENAMEW ofn = {};
                ofn.lStructSize = sizeof(ofn);
                ofn.hwndOwner = hDlg;
                ofn.lpstrFile = szFile;
                ofn.nMaxFile = MAX_PATH;
                ofn.lpstrFilter = L"Tệp văn bản (*.txt)\0*.txt\0Tất cả tệp (*.*)\0*.*\0";
                ofn.nFilterIndex = 1;
                ofn.lpstrDefExt = L"txt";
                ofn.Flags = OFN_PATHMUSTEXIST | OFN_OVERWRITEPROMPT;

                if (GetSaveFileNameW(&ofn)) {
                    std::string u8Path = WideToUtf8(szFile);
                    saveToFile(u8Path);
                    MessageBoxW(hDlg, L"Đã xuất bảng gõ tắt thành công.", L"Thông báo", MB_ICONINFORMATION | MB_OK);
                }
                return TRUE;
            }
            }
        }
        break;
    }
    }
    return FALSE;
}

// -------------------------------------------------------------
// Tab 4: System (Hệ thống)
// -------------------------------------------------------------
static INT_PTR CALLBACK TabSystemDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    (void)lParam;
    switch (uMsg) {
    case WM_INITDIALOG:
        CheckDlgButton(hDlg, IDC_CHK_RUN_STARTUP, Settings::IsRunOnStartup() ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_FIX_BROWSER, vFixRecommendBrowser ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_TEMP_OFF_SPELL, vTempOffSpelling ? BST_CHECKED : BST_UNCHECKED);
        CheckDlgButton(hDlg, IDC_CHK_TEMP_OFF_ENGINE, vTempOffOpenKey ? BST_CHECKED : BST_UNCHECKED);
        return TRUE;

    case WM_COMMAND: {
        WORD id = LOWORD(wParam);
        if (HIWORD(wParam) == BN_CLICKED) {
            switch (id) {
            case IDC_CHK_RUN_STARTUP: {
                bool enable = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED);
                Settings::SetRunOnStartup(enable);
                return TRUE;
            }

            case IDC_CHK_FIX_BROWSER:
                vFixRecommendBrowser = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_TEMP_OFF_SPELL:
                vTempOffSpelling = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_CHK_TEMP_OFF_ENGINE:
                vTempOffOpenKey = (IsDlgButtonChecked(hDlg, id) == BST_CHECKED) ? 1 : 0;
                Settings::Save();
                return TRUE;

            case IDC_BTN_HOMEPAGE:
                ShellExecuteW(NULL, L"open", L"https://github.com/hqdvn/MyOpenKey", NULL, NULL, SW_SHOWNORMAL);
                return TRUE;
            }
        }
        break;
    }
    }
    return FALSE;
}

// -------------------------------------------------------------
// Main Settings Dialog Procedure
// -------------------------------------------------------------
static INT_PTR CALLBACK SettingsDlgProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    (void)lParam;
    switch (uMsg) {
    case WM_INITDIALOG: {
        s_hwndSettings = hDlg;

        HINSTANCE hInst = GetModuleHandleW(NULL);
        HICON hIconBig = static_cast<HICON>(LoadImageW(hInst, MAKEINTRESOURCEW(IDI_APPICON), IMAGE_ICON,
                                           GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), 0));
        HICON hIconSm = static_cast<HICON>(LoadImageW(hInst, MAKEINTRESOURCEW(IDI_APPICON), IMAGE_ICON,
                                          GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), 0));
        if (hIconBig) {
            SendMessageW(hDlg, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(hIconBig));
        }
        if (hIconSm) {
            SendMessageW(hDlg, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(hIconSm));
        }

        s_hTab = GetDlgItem(hDlg, IDC_TAB_MAIN);

        TCITEMW tie = {};
        tie.mask = TCIF_TEXT;
        wchar_t tab1[] = L"Bộ gõ";
        tie.pszText = tab1;
        TabCtrl_InsertItem(s_hTab, 0, &tie);
        wchar_t tab2[] = L"Chính tả && gõ nhanh";
        tie.pszText = tab2;
        TabCtrl_InsertItem(s_hTab, 1, &tie);
        wchar_t tab3[] = L"Gõ tắt";
        tie.pszText = tab3;
        TabCtrl_InsertItem(s_hTab, 2, &tie);
        wchar_t tab4[] = L"Hệ thống";
        tie.pszText = tab4;
        TabCtrl_InsertItem(s_hTab, 3, &tie);

        s_hChildTabs[0] = CreateDialogParamW(hInst, MAKEINTRESOURCEW(IDD_TAB_INPUT), hDlg, TabInputDlgProc, 0);
        s_hChildTabs[1] = CreateDialogParamW(hInst, MAKEINTRESOURCEW(IDD_TAB_SPELLING), hDlg, TabSpellingDlgProc, 0);
        s_hChildTabs[2] = CreateDialogParamW(hInst, MAKEINTRESOURCEW(IDD_TAB_MACRO), hDlg, TabMacroDlgProc, 0);
        s_hChildTabs[3] = CreateDialogParamW(hInst, MAKEINTRESOURCEW(IDD_TAB_SYSTEM), hDlg, TabSystemDlgProc, 0);

        RECT rc = {};
        GetClientRect(s_hTab, &rc);
        TabCtrl_AdjustRect(s_hTab, FALSE, &rc);
        MapWindowPoints(s_hTab, hDlg, reinterpret_cast<POINT*>(&rc), 2);

        s_activeTab = 0;
        for (int i = 0; i < 4; ++i) {
            if (s_hChildTabs[i]) {
                MoveWindow(s_hChildTabs[i], rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top, FALSE);
                ShowWindow(s_hChildTabs[i], (i == 0) ? SW_SHOW : SW_HIDE);
            }
        }
        return TRUE;
    }

    case WM_NOTIFY: {
        NMHDR* pnm = reinterpret_cast<NMHDR*>(lParam);
        if (pnm && pnm->idFrom == IDC_TAB_MAIN && pnm->code == TCN_SELCHANGE) {
            int sel = TabCtrl_GetCurSel(s_hTab);
            if (sel >= 0 && sel < 4 && sel != s_activeTab) {
                if (s_hChildTabs[s_activeTab]) {
                    ShowWindow(s_hChildTabs[s_activeTab], SW_HIDE);
                }
                s_activeTab = sel;
                if (s_hChildTabs[s_activeTab]) {
                    ShowWindow(s_hChildTabs[s_activeTab], SW_SHOW);
                }
            }
        }
        return TRUE;
    }

    case WM_COMMAND: {
        WORD id = LOWORD(wParam);
        if (id == IDCANCEL || id == IDOK) {
            DestroyWindow(hDlg);
            return TRUE;
        }
        break;
    }

    case WM_DESTROY: {
        for (int i = 0; i < 4; ++i) {
            if (s_hChildTabs[i]) {
                DestroyWindow(s_hChildTabs[i]);
                s_hChildTabs[i] = NULL;
            }
        }
        s_hwndSettings = NULL;
        NotifyParentStateChanged();
        return TRUE;
    }
    }
    return FALSE;
}

void Show(HINSTANCE hInstance, HWND hwndParent) {
    s_hwndMainOwner = hwndParent;
    if (s_hwndSettings && IsWindow(s_hwndSettings)) {
        if (IsIconic(s_hwndSettings)) {
            ShowWindow(s_hwndSettings, SW_RESTORE);
        }
        BringWindowToTop(s_hwndSettings);
        SetForegroundWindow(s_hwndSettings);
        return;
    }

    s_hwndSettings = CreateDialogParamW(hInstance, MAKEINTRESOURCEW(IDD_SETTINGS), NULL, SettingsDlgProc, 0);
    if (s_hwndSettings) {
        ShowWindow(s_hwndSettings, SW_SHOW);
        SetForegroundWindow(s_hwndSettings);
    }
}

HWND GetHwnd() {
    return s_hwndSettings;
}

} // namespace SettingsDlg
