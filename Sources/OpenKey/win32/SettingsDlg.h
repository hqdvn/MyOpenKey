#pragma once

#include <windows.h>

namespace SettingsDlg {
    void Show(HINSTANCE hInstance, HWND hwndParent);
    HWND GetHwnd();
}
