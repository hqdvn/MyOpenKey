#include "Settings.h"
#include "Macro.h"
#include <vector>
#include <cwchar>

// Engine globals definition (required by Engine.h)
int vLanguage = 1;
int vInputType = 0;
int vFreeMark = 0;
int vCodeTable = 0;
int vSwitchKeyStatus = 0xFE0009FE; // Default Ctrl+Shift
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vQuickTelex = 0;
int vRestoreIfWrongSpelling = 0;
int vFixRecommendBrowser = 1;
int vUseMacro = 1;
int vUseMacroInEnglishMode = 1;
int vAutoCapsMacro = 0;
int vUseSmartSwitchKey = 0;
int vUpperCaseFirstChar = 0;
int vTempOffSpelling = 0;
int vAllowConsonantZFWJ = 0;
int vQuickStartConsonant = 0;
int vQuickEndConsonant = 0;
int vRememberCode = 0;
int vOtherLanguage = 0;
int vTempOffOpenKey = 0;

// Host extra variables
int vSendKeyStepByStep = 0;
int vShowIconOnDock = 0;
int vPerformLayoutCompat = 0;

static const wchar_t* REG_KEY_PATH = L"Software\\MyOpenKey";
static const wchar_t* REG_RUN_PATH = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
static const wchar_t* RUN_VALUE_NAME = L"MyOpenKey";

static inline int Clamp(int val, int minVal, int maxVal) {
    if (val < minVal) return minVal;
    if (val > maxVal) return maxVal;
    return val;
}

static DWORD ReadDword(HKEY hKey, const wchar_t* name, DWORD defaultValue) {
    DWORD type = 0;
    DWORD value = 0;
    DWORD size = sizeof(value);
    if (RegQueryValueExW(hKey, name, NULL, &type, reinterpret_cast<LPBYTE>(&value), &size) == ERROR_SUCCESS && type == REG_DWORD) {
        return value;
    }
    return defaultValue;
}

static void WriteDword(HKEY hKey, const wchar_t* name, DWORD value) {
    RegSetValueExW(hKey, name, 0, REG_DWORD, reinterpret_cast<const BYTE*>(&value), sizeof(value));
}

namespace Settings {

void Load() {
    HKEY hKey = NULL;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, REG_KEY_PATH, 0, KEY_READ, &hKey) != ERROR_SUCCESS) {
        return;
    }

    vLanguage = Clamp(static_cast<int>(ReadDword(hKey, L"Language", 1)), 0, 1);
    vInputType = Clamp(static_cast<int>(ReadDword(hKey, L"InputType", 0)), 0, 3);
    vCodeTable = Clamp(static_cast<int>(ReadDword(hKey, L"CodeTable", 0)), 0, 4);
    vCheckSpelling = Clamp(static_cast<int>(ReadDword(hKey, L"CheckSpelling", 1)), 0, 1);
    vUseModernOrthography = Clamp(static_cast<int>(ReadDword(hKey, L"ModernOrthography", 1)), 0, 1);
    vQuickTelex = Clamp(static_cast<int>(ReadDword(hKey, L"QuickTelex", 0)), 0, 1);
    vSwitchKeyStatus = static_cast<int>(ReadDword(hKey, L"SwitchKeyStatus", 0xFE0009FE));
    vRestoreIfWrongSpelling = Clamp(static_cast<int>(ReadDword(hKey, L"RestoreIfWrongSpelling", 0)), 0, 1);
    vFixRecommendBrowser = Clamp(static_cast<int>(ReadDword(hKey, L"FixRecommendBrowser", 1)), 0, 1);
    vUseMacro = Clamp(static_cast<int>(ReadDword(hKey, L"UseMacro", 1)), 0, 1);
    vUseMacroInEnglishMode = Clamp(static_cast<int>(ReadDword(hKey, L"UseMacroInEnglishMode", 1)), 0, 1);
    vAutoCapsMacro = Clamp(static_cast<int>(ReadDword(hKey, L"AutoCapsMacro", 0)), 0, 1);
    vUpperCaseFirstChar = Clamp(static_cast<int>(ReadDword(hKey, L"UpperCaseFirstChar", 0)), 0, 1);
    vTempOffSpelling = Clamp(static_cast<int>(ReadDword(hKey, L"TempOffSpelling", 0)), 0, 1);
    vAllowConsonantZFWJ = Clamp(static_cast<int>(ReadDword(hKey, L"AllowConsonantZFWJ", 0)), 0, 1);
    vQuickStartConsonant = Clamp(static_cast<int>(ReadDword(hKey, L"QuickStartConsonant", 0)), 0, 1);
    vQuickEndConsonant = Clamp(static_cast<int>(ReadDword(hKey, L"QuickEndConsonant", 0)), 0, 1);
    vRememberCode = Clamp(static_cast<int>(ReadDword(hKey, L"RememberCode", 0)), 0, 1);
    vOtherLanguage = Clamp(static_cast<int>(ReadDword(hKey, L"OtherLanguage", 0)), 0, 1);
    vTempOffOpenKey = Clamp(static_cast<int>(ReadDword(hKey, L"TempOffOpenKey", 0)), 0, 1);
    vFreeMark = Clamp(static_cast<int>(ReadDword(hKey, L"FreeMark", 0)), 0, 1);

    DWORD dwType = 0;
    DWORD cbData = 0;
    if (RegQueryValueExW(hKey, L"MacroData", NULL, &dwType, NULL, &cbData) == ERROR_SUCCESS && dwType == REG_BINARY && cbData > 0) {
        std::vector<Byte> buf(cbData);
        if (RegQueryValueExW(hKey, L"MacroData", NULL, &dwType, buf.data(), &cbData) == ERROR_SUCCESS) {
            initMacroMap(buf.data(), static_cast<int>(buf.size()));
        }
    }

    RegCloseKey(hKey);
}

void Save() {
    HKEY hKey = NULL;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, REG_KEY_PATH, 0, NULL, 0, KEY_SET_VALUE, NULL, &hKey, NULL) != ERROR_SUCCESS) {
        return;
    }

    WriteDword(hKey, L"Language", static_cast<DWORD>(vLanguage));
    WriteDword(hKey, L"InputType", static_cast<DWORD>(vInputType));
    WriteDword(hKey, L"CodeTable", static_cast<DWORD>(vCodeTable));
    WriteDword(hKey, L"CheckSpelling", static_cast<DWORD>(vCheckSpelling));
    WriteDword(hKey, L"ModernOrthography", static_cast<DWORD>(vUseModernOrthography));
    WriteDword(hKey, L"QuickTelex", static_cast<DWORD>(vQuickTelex));
    WriteDword(hKey, L"SwitchKeyStatus", static_cast<DWORD>(vSwitchKeyStatus));
    WriteDword(hKey, L"RestoreIfWrongSpelling", static_cast<DWORD>(vRestoreIfWrongSpelling));
    WriteDword(hKey, L"FixRecommendBrowser", static_cast<DWORD>(vFixRecommendBrowser));
    WriteDword(hKey, L"UseMacro", static_cast<DWORD>(vUseMacro));
    WriteDword(hKey, L"UseMacroInEnglishMode", static_cast<DWORD>(vUseMacroInEnglishMode));
    WriteDword(hKey, L"AutoCapsMacro", static_cast<DWORD>(vAutoCapsMacro));
    WriteDword(hKey, L"UpperCaseFirstChar", static_cast<DWORD>(vUpperCaseFirstChar));
    WriteDword(hKey, L"TempOffSpelling", static_cast<DWORD>(vTempOffSpelling));
    WriteDword(hKey, L"AllowConsonantZFWJ", static_cast<DWORD>(vAllowConsonantZFWJ));
    WriteDword(hKey, L"QuickStartConsonant", static_cast<DWORD>(vQuickStartConsonant));
    WriteDword(hKey, L"QuickEndConsonant", static_cast<DWORD>(vQuickEndConsonant));
    WriteDword(hKey, L"RememberCode", static_cast<DWORD>(vRememberCode));
    WriteDword(hKey, L"OtherLanguage", static_cast<DWORD>(vOtherLanguage));
    WriteDword(hKey, L"TempOffOpenKey", static_cast<DWORD>(vTempOffOpenKey));
    WriteDword(hKey, L"FreeMark", static_cast<DWORD>(vFreeMark));

    std::vector<Byte> macroBuf;
    getMacroSaveData(macroBuf);
    if (!macroBuf.empty()) {
        RegSetValueExW(hKey, L"MacroData", 0, REG_BINARY, macroBuf.data(), static_cast<DWORD>(macroBuf.size()));
    } else {
        RegDeleteValueW(hKey, L"MacroData");
    }

    RegCloseKey(hKey);
}

bool IsRunOnStartup() {
    HKEY hKey = NULL;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, REG_RUN_PATH, 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        DWORD type = 0;
        DWORD size = 0;
        LONG res = RegQueryValueExW(hKey, RUN_VALUE_NAME, NULL, &type, NULL, &size);
        RegCloseKey(hKey);
        return (res == ERROR_SUCCESS && type == REG_SZ);
    }
    return false;
}

void SetRunOnStartup(bool enable) {
    HKEY hKey = NULL;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, REG_RUN_PATH, 0, NULL, 0, KEY_SET_VALUE, NULL, &hKey, NULL) == ERROR_SUCCESS) {
        if (enable) {
            wchar_t szPath[MAX_PATH];
            DWORD len = GetModuleFileNameW(NULL, szPath, MAX_PATH);
            if (len > 0 && len < MAX_PATH) {
                std::wstring cmd = L"\"" + std::wstring(szPath) + L"\"";
                RegSetValueExW(hKey, RUN_VALUE_NAME, 0, REG_SZ,
                               reinterpret_cast<const BYTE*>(cmd.c_str()),
                               static_cast<DWORD>((cmd.length() + 1) * sizeof(wchar_t)));
            }
        } else {
            RegDeleteValueW(hKey, RUN_VALUE_NAME);
        }
        RegCloseKey(hKey);
    }
}

} // namespace Settings
