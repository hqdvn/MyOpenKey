#pragma once

#include <windows.h>

#define WM_APP_LANGUAGE_CHANGED (WM_APP + 2)

namespace Hook {
    bool Install(HWND hwndMain);
    void Uninstall();
    void CheckHealth();
    void Reinstall();
    void ClearSyncKey();
    void SwitchLanguage();
}
