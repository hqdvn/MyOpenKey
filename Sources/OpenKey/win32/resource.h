#pragma once

#define IDI_APPICON             1

#ifndef IDC_STATIC
#define IDC_STATIC              (-1)
#endif

// Main dialog & tabs
#define IDD_SETTINGS            100
#define IDD_TAB_INPUT           101
#define IDD_TAB_SPELLING        102
#define IDD_TAB_MACRO           103
#define IDD_TAB_SYSTEM          104

#define IDC_TAB_MAIN            1001

// Tab 1: Input (Bộ gõ)
#define IDC_COMBO_INPUT_TYPE    1101
#define IDC_COMBO_CODE_TABLE    1102
#define IDC_RADIO_CTRL_SHIFT    1103
#define IDC_RADIO_ALT_Z         1104
#define IDC_CHK_BEEP            1105

// Tab 2: Spelling & Quick typing (Chính tả & gõ nhanh)
#define IDC_CHK_SPELLING        1201
#define IDC_CHK_MODERN_ORTHO    1202
#define IDC_CHK_RESTORE_SPELL   1203
#define IDC_CHK_FREE_MARK       1204
#define IDC_CHK_QUICK_TELEX     1205
#define IDC_CHK_QUICK_START     1206
#define IDC_CHK_QUICK_END       1207
#define IDC_CHK_ALLOW_ZFWJ      1208
#define IDC_CHK_AUTO_UPPER      1209

// Tab 3: Macro (Gõ tắt)
#define IDC_CHK_USE_MACRO       1301
#define IDC_CHK_MACRO_ENGLISH   1302
#define IDC_CHK_AUTO_CAPS_MACRO 1303
#define IDC_LIST_MACRO          1304
#define IDC_EDIT_MACRO_KEY      1305
#define IDC_EDIT_MACRO_TEXT     1306
#define IDC_BTN_MACRO_ADD       1307
#define IDC_BTN_MACRO_DEL       1308
#define IDC_BTN_MACRO_IMPORT    1309
#define IDC_BTN_MACRO_EXPORT    1310

// Tab 4: System (Hệ thống)
#define IDC_CHK_RUN_STARTUP     1401
#define IDC_CHK_FIX_BROWSER     1402
#define IDC_CHK_TEMP_OFF_SPELL  1403
#define IDC_CHK_TEMP_OFF_ENGINE 1404
#define IDC_STATIC_VERSION      1405
#define IDC_BTN_HOMEPAGE        1406
