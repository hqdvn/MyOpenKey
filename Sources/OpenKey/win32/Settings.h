#pragma once

#include <windows.h>
#include "Engine.h"

namespace Settings {
    void Load();
    void Save();
    bool IsRunOnStartup();
    void SetRunOnStartup(bool enable);
}
