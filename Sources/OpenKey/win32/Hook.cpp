#include "Hook.h"
#include "Engine.h"
#include "DataType.h"
#include "Vietnamese.h"
#include "Macro.h"
#include "ChunkSplitter.h"
#include "Settings.h"

#include <vector>
#include <algorithm>

namespace Hook {

static const ULONG_PTR MYOPENKEY_EXTRA_INFO = 0x4D4F504B; // "MOPK"

static HWND s_hwndMain = NULL;
static HHOOK s_kbdHook = NULL;
static HHOOK s_mouseHook = NULL;
static vKeyHookState* s_pData = nullptr;
static std::vector<Uint16> s_syncKey;

// Modifier hotkey tracking state
static bool s_modHotKeyCandidate = false;
static bool s_modHotKeyDisqualified = false;
static bool s_lastModifierCtrl = false;
static bool s_lastModifierAlt = false;

static inline void AddBackspace(std::vector<INPUT>& inputs) {
    INPUT inDown = {};
    inDown.type = INPUT_KEYBOARD;
    inDown.ki.wVk = VK_BACK;
    inDown.ki.dwExtraInfo = MYOPENKEY_EXTRA_INFO;

    INPUT inUp = inDown;
    inUp.ki.dwFlags = KEYEVENTF_KEYUP;

    inputs.push_back(inDown);
    inputs.push_back(inUp);
}

static inline void AddUnicodeChar(std::vector<INPUT>& inputs, uint16_t ch) {
    INPUT inDown = {};
    inDown.type = INPUT_KEYBOARD;
    inDown.ki.wScan = ch;
    inDown.ki.dwFlags = KEYEVENTF_UNICODE;
    inDown.ki.dwExtraInfo = MYOPENKEY_EXTRA_INFO;

    INPUT inUp = inDown;
    inUp.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

    inputs.push_back(inDown);
    inputs.push_back(inUp);
}

static inline void AddVirtualKey(std::vector<INPUT>& inputs, WORD vk) {
    INPUT inDown = {};
    inDown.type = INPUT_KEYBOARD;
    inDown.ki.wVk = vk;
    inDown.ki.dwExtraInfo = MYOPENKEY_EXTRA_INFO;

    INPUT inUp = inDown;
    inUp.ki.dwFlags = KEYEVENTF_KEYUP;

    inputs.push_back(inDown);
    inputs.push_back(inUp);
}

static inline bool IsModifierKey(DWORD vk) {
    switch (vk) {
    case VK_SHIFT:
    case VK_LSHIFT:
    case VK_RSHIFT:
    case VK_CONTROL:
    case VK_LCONTROL:
    case VK_RCONTROL:
    case VK_MENU:
    case VK_LMENU:
    case VK_RMENU:
    case VK_LWIN:
    case VK_RWIN:
    case VK_CAPITAL:
        return true;
    default:
        return false;
    }
}

static bool IsForegroundPasswordField() {
    GUITHREADINFO gti = { sizeof(gti) };
    if (GetGUIThreadInfo(0, &gti)) {
        HWND hwndFocus = gti.hwndFocus ? gti.hwndFocus : gti.hwndActive;
        if (hwndFocus) {
            LONG style = GetWindowLongW(hwndFocus, GWL_STYLE);
            if (style & ES_PASSWORD) {
                return true;
            }
        }
    }
    return false;
}

void ClearSyncKey() {
    s_syncKey.clear();
}

void SwitchLanguage() {
    vLanguage = (vLanguage == 0) ? 1 : 0;
    startNewSession();
    ClearSyncKey();
    if (HAS_BEEP(vSwitchKeyStatus)) {
        MessageBeep(MB_OK);
    }
    if (s_hwndMain) {
        PostMessageW(s_hwndMain, WM_APP_LANGUAGE_CHANGED, 0, 0);
    }
}

static void SendReplacementOutput(const std::vector<Uint32>& tokens, Uint16 restoreChar, bool willSendControlKey, WORD vkFallback) {
    std::vector<INPUT> inputs;

    // 1. Backspaces
    int bsCount = std::min(static_cast<int>(s_pData->backspaceCount), MAX_BUFF);
    for (int i = 0; i < bsCount; i++) {
        AddBackspace(inputs);
        if (IS_DOUBLE_CODE(vCodeTable)) {
            if (!s_syncKey.empty()) {
                if (s_syncKey.back() > 1) {
                    AddBackspace(inputs);
                }
                s_syncKey.pop_back();
            }
        }
    }

    // 2. Bookkeeping for _syncKey
    if (IS_DOUBLE_CODE(vCodeTable)) {
        for (size_t i = 0; i < tokens.size(); i++) {
            CharUnits u = expandCharToken(tokens[i], vCodeTable, keyCodeToCharacter);
            if (u.syncKeyLength > 0) {
                s_syncKey.push_back(u.syncKeyLength);
            }
        }
    }

    // 3. Chunk splitting & Unicode inputs
    auto chunks = splitIntoChunks(tokens, vCodeTable, restoreChar, keyCodeToCharacter);
    for (const auto& chunk : chunks) {
        for (uint16_t ch : chunk) {
            AddUnicodeChar(inputs, ch);
        }
    }

    if (willSendControlKey && vkFallback != 0) {
        AddVirtualKey(inputs, vkFallback);
    }

    if (!inputs.empty()) {
        SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
    }
}

static LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode < 0) {
        return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
    }

    KBDLLHOOKSTRUCT* kbd = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);

    // Only skip our own injected events
    if (kbd->dwExtraInfo == MYOPENKEY_EXTRA_INFO) {
        return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
    }

    DWORD vk = kbd->vkCode;
    bool isKeyDown = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
    bool isKeyUp = (wParam == WM_KEYUP || wParam == WM_SYSKEYUP);

    // Track modifiers for hotkey and temp-off
    if (isKeyDown) {
        if (IsModifierKey(vk)) {
            // Check modifier-only hotkey candidate (e.g. Ctrl+Shift)
            if (GET_SWITCH_KEY(vSwitchKeyStatus) == 0xFE) {
                bool ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0 || (vk == VK_CONTROL || vk == VK_LCONTROL || vk == VK_RCONTROL);
                bool shift = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0 || (vk == VK_SHIFT || vk == VK_LSHIFT || vk == VK_RSHIFT);
                bool alt = (GetAsyncKeyState(VK_MENU) & 0x8000) != 0 || (vk == VK_MENU || vk == VK_LMENU || vk == VK_RMENU);
                bool win = (GetAsyncKeyState(VK_LWIN) & 0x8000) != 0 || (GetAsyncKeyState(VK_RWIN) & 0x8000) != 0 || (vk == VK_LWIN || vk == VK_RWIN);

                bool match = (ctrl == (HAS_CONTROL(vSwitchKeyStatus) != 0)) &&
                             (shift == (HAS_SHIFT(vSwitchKeyStatus) != 0)) &&
                             (alt == (HAS_OPTION(vSwitchKeyStatus) != 0)) &&
                             (win == (HAS_COMMAND(vSwitchKeyStatus) != 0));

                if (match && !s_modHotKeyDisqualified) {
                    s_modHotKeyCandidate = true;
                }
            }
            if (vk == VK_CONTROL || vk == VK_LCONTROL || vk == VK_RCONTROL) s_lastModifierCtrl = true;
            if (vk == VK_MENU || vk == VK_LMENU || vk == VK_RMENU) s_lastModifierAlt = true;
            return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
        } else {
            // Non-modifier key pressed: disqualify modifier-only hotkey
            s_modHotKeyCandidate = false;
            s_modHotKeyDisqualified = true;

            // Check normal key hotkey (e.g. Alt+Z)
            if (GET_SWITCH_KEY(vSwitchKeyStatus) != 0xFE && vk == static_cast<DWORD>(GET_SWITCH_KEY(vSwitchKeyStatus))) {
                bool ctrl = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
                bool shift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
                bool alt = (GetKeyState(VK_MENU) & 0x8000) != 0;
                bool win = (GetKeyState(VK_LWIN) & 0x8000) != 0 || (GetKeyState(VK_RWIN) & 0x8000) != 0;

                if (ctrl == (HAS_CONTROL(vSwitchKeyStatus) != 0) &&
                    shift == (HAS_SHIFT(vSwitchKeyStatus) != 0) &&
                    alt == (HAS_OPTION(vSwitchKeyStatus) != 0) &&
                    win == (HAS_COMMAND(vSwitchKeyStatus) != 0)) {
                    SwitchLanguage();
                    return 1; // swallow hotkey
                }
            }
        }
    } else if (isKeyUp) {
        if (IsModifierKey(vk)) {
            if (s_modHotKeyCandidate && !s_modHotKeyDisqualified) {
                SwitchLanguage();
                s_modHotKeyCandidate = false;
                s_modHotKeyDisqualified = true;
            } else {
                // Check temp off engine / spell checking
                if (vTempOffSpelling && s_lastModifierCtrl && (vk == VK_CONTROL || vk == VK_LCONTROL || vk == VK_RCONTROL)) {
                    vTempOffSpellChecking();
                }
                if (vTempOffOpenKey && s_lastModifierAlt && (vk == VK_MENU || vk == VK_LMENU || vk == VK_RMENU)) {
                    vTempOffEngine();
                }
            }

            bool anyModDown = ((GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0) ||
                              ((GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0) ||
                              ((GetAsyncKeyState(VK_MENU) & 0x8000) != 0) ||
                              ((GetAsyncKeyState(VK_LWIN) & 0x8000) != 0) ||
                              ((GetAsyncKeyState(VK_RWIN) & 0x8000) != 0);
            if (!anyModDown) {
                s_modHotKeyDisqualified = false;
                s_modHotKeyCandidate = false;
                s_lastModifierCtrl = false;
                s_lastModifierAlt = false;
            }
        }
        return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
    }

    if (!isKeyDown) {
        return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
    }

    // Skip processing when foreground control is a password field
    if (IsForegroundPasswordField()) {
        startNewSession();
        vEnglishMode(vKeyEventState::MouseDown, 0, false, 0);
        ClearSyncKey();
        return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
    }

    // Map numpad Enter to KEY_ENTER (0x0E), others preserve vkCode
    Uint16 keyCode = static_cast<Uint16>(vk);
    if (vk == VK_RETURN && (kbd->flags & LLKHF_EXTENDED)) {
        keyCode = KEY_ENTER;
    }

    bool isShift = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
    bool isCaps = (GetKeyState(VK_CAPITAL) & 0x0001) != 0;
    Uint8 capsStatus = isShift ? 1 : (isCaps ? 2 : 0);

    bool ctrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
    bool altDown = (GetKeyState(VK_MENU) & 0x8000) != 0;
    bool winDown = ((GetKeyState(VK_LWIN) & 0x8000) != 0) || ((GetKeyState(VK_RWIN) & 0x8000) != 0);
    bool otherControlKey = ctrlDown || altDown || winDown;

    // English mode
    if (vLanguage == 0) {
        if (vUseMacro && vUseMacroInEnglishMode) {
            vEnglishMode(vKeyEventState::KeyDown, keyCode, (capsStatus != 0), otherControlKey);
            if (s_pData && s_pData->code == vReplaceMaro) {
                SendReplacementOutput(s_pData->macroData, 0, true, static_cast<WORD>(vk));
                return 1;
            }
        }
        return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
    }

    // Vietnamese mode
    vKeyHandleEvent(vKeyEvent::Keyboard,
                    vKeyEventState::KeyDown,
                    keyCode,
                    capsStatus,
                    otherControlKey);

    if (!s_pData) {
        return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
    }

    if (s_pData->code == vDoNothing) {
        if (IS_DOUBLE_CODE(vCodeTable)) {
            if (s_pData->extCode == 1) { // Word break
                ClearSyncKey();
            } else if (s_pData->extCode == 2) { // Delete / backspace key
                if (!s_syncKey.empty()) {
                    if (s_syncKey.back() > 1) {
                        INPUT extraBs[2] = {};
                        extraBs[0].type = INPUT_KEYBOARD;
                        extraBs[0].ki.wVk = VK_BACK;
                        extraBs[0].ki.dwExtraInfo = MYOPENKEY_EXTRA_INFO;
                        extraBs[1] = extraBs[0];
                        extraBs[1].ki.dwFlags = KEYEVENTF_KEYUP;
                        SendInput(2, extraBs, sizeof(INPUT));
                    }
                    s_syncKey.pop_back();
                }
            } else if (s_pData->extCode == 3) { // Normal key
                s_syncKey.push_back(1);
            }
        }
        return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
    } else if (s_pData->code == vWillProcess || s_pData->code == vRestore || s_pData->code == vRestoreAndStartNewSession) {
        std::vector<Uint32> tokens;
        int count = std::min(static_cast<int>(s_pData->newCharCount), MAX_BUFF);
        for (int k = count - 1; k >= 0; k--) {
            tokens.push_back(s_pData->charData[k]);
        }

        Uint16 restoreChar = 0;
        bool willSendControlKey = false;
        if (s_pData->code == vRestore || s_pData->code == vRestoreAndStartNewSession) {
            if (keyCodeToCharacter(keyCode) != 0) {
                restoreChar = keyCodeToCharacter(keyCode | (capsStatus ? CAPS_MASK : 0));
            } else {
                willSendControlKey = true;
            }
        }

        SendReplacementOutput(tokens, restoreChar, willSendControlKey, static_cast<WORD>(vk));

        if (s_pData->code == vRestoreAndStartNewSession) {
            startNewSession();
        }

        return 1; // swallow original key
    } else if (s_pData->code == vReplaceMaro) {
        SendReplacementOutput(s_pData->macroData, 0, true, static_cast<WORD>(vk));
        return 1; // swallow original key
    }

    return CallNextHookEx(s_kbdHook, nCode, wParam, lParam);
}

static LRESULT CALLBACK LowLevelMouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode < 0) {
        return CallNextHookEx(s_mouseHook, nCode, wParam, lParam);
    }

    if (wParam == WM_LBUTTONDOWN || wParam == WM_RBUTTONDOWN || wParam == WM_MBUTTONDOWN) {
        startNewSession();
        vEnglishMode(vKeyEventState::MouseDown, 0, false, 0);
        ClearSyncKey();
    }

    return CallNextHookEx(s_mouseHook, nCode, wParam, lParam);
}

bool Install(HWND hwndMain) {
    s_hwndMain = hwndMain;
    if (!s_pData) {
        s_pData = static_cast<vKeyHookState*>(vKeyInit());
    }

    HINSTANCE hInst = GetModuleHandleW(NULL);
    if (!s_kbdHook) {
        s_kbdHook = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc, hInst, 0);
    }
    if (!s_mouseHook) {
        s_mouseHook = SetWindowsHookExW(WH_MOUSE_LL, LowLevelMouseProc, hInst, 0);
    }

    return (s_kbdHook != NULL && s_mouseHook != NULL);
}

void Uninstall() {
    if (s_kbdHook) {
        UnhookWindowsHookEx(s_kbdHook);
        s_kbdHook = NULL;
    }
    if (s_mouseHook) {
        UnhookWindowsHookEx(s_mouseHook);
        s_mouseHook = NULL;
    }
}

void Reinstall() {
    Uninstall();
    if (s_hwndMain) {
        Install(s_hwndMain);
    }
}

void CheckHealth() {
    if (!s_kbdHook || !s_mouseHook) {
        Reinstall();
    }
}

} // namespace Hook
