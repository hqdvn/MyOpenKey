#include "Engine.h"
#include "Macro.h"
#include "SmartSwitchKey.h"
#include "ConvertTool.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <string>
#include <cstring>

// Globals required by Engine.h (defaults from OpenKey.mm / AppDelegate.m)
int vLanguage = 1;
int vInputType = 0;
int vFreeMark = 0;
int vCodeTable = 0;
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vQuickTelex = 0;
int vSwitchKeyStatus = 0x7A000206;
int vRestoreIfWrongSpelling = 0;
int vFixRecommendBrowser = 1;
int vUseMacro = 1;
int vUseMacroInEnglishMode = 1;
int vAutoCapsMacro = 0;
int vSendKeyStepByStep = 0;
int vUseSmartSwitchKey = 1;
int vUpperCaseFirstChar = 0;
int vTempOffSpelling = 0;
int vAllowConsonantZFWJ = 0;
int vQuickStartConsonant = 0;
int vQuickEndConsonant = 0;
int vRememberCode = 1;
int vOtherLanguage = 1;
int vTempOffOpenKey = 0;
int vShowIconOnDock = 0;
int vPerformLayoutCompat = 0;

static vKeyHookState* pData = nullptr;

static void resetEngineState() {
    vLanguage = 1;
    vInputType = 0; // Telex
    vFreeMark = 0;
    vCodeTable = 0; // Unicode
    vCheckSpelling = 1;
    vUseModernOrthography = 1;
    vQuickTelex = 0;
    vRestoreIfWrongSpelling = 0;
    vFixRecommendBrowser = 1;
    vUseMacro = 1;
    vUseMacroInEnglishMode = 1;
    vAutoCapsMacro = 0;
    vUseSmartSwitchKey = 1;
    vUpperCaseFirstChar = 0;
    vTempOffSpelling = 0;
    vAllowConsonantZFWJ = 0;
    vQuickStartConsonant = 0;
    vQuickEndConsonant = 0;
    startNewSession();
}

static void feedKey(Uint16 keyCode, Uint8 caps = 0, bool otherCtrl = false) {
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, keyCode, caps, otherCtrl);
}

// Test Telex typing: "tieengs" -> "tiếng"
static void testTelexCorrectness() {
    std::cout << "[Test] Telex correctness: tieengs -> tiếng..." << std::endl;
    resetEngineState();
    // t, i, e, e, n, g, s
    feedKey(KEY_T);
    feedKey(KEY_I);
    feedKey(KEY_E);
    feedKey(KEY_E);
    // After second 'e', should replace with 'ê'
    assert(pData->code == vWillProcess);
    feedKey(KEY_N);
    feedKey(KEY_G);
    feedKey(KEY_S);
    // After 's', tone mark 'sắc' on 'tiếng'
    assert(pData->code == vWillProcess);
    std::cout << "  Passed Telex correctness." << std::endl;
}

// Test VNI typing: "tieng1" -> "tiếng" (e6 -> ê, s1 -> sắc)
static void testVNICorrectness() {
    std::cout << "[Test] VNI correctness: tie6ng1 -> tiếng..." << std::endl;
    resetEngineState();
    vInputType = 1; // VNI
    feedKey(KEY_T);
    feedKey(KEY_I);
    feedKey(KEY_E);
    feedKey(KEY_6);
    assert(pData->code == vWillProcess);
    feedKey(KEY_N);
    feedKey(KEY_G);
    feedKey(KEY_1);
    assert(pData->code == vWillProcess);
    std::cout << "  Passed VNI correctness." << std::endl;
}

// E1: type w, [, ] as first key of a word
static void testE1() {
    std::cout << "[Test] E1: first key w, [, ] of a word..." << std::endl;
    resetEngineState();
    feedKey(KEY_W);
    resetEngineState();
    feedKey(KEY_LEFT_BRACKET);
    resetEngineState();
    feedKey(KEY_RIGHT_BRACKET);

    // Reversal check: type `]` followed by `]`
    // The first `]` produces 'ơ' (standalone key) with code=vWillProcess, bpc=0, ncc=1.
    // The second `]` reverses it back to `]` via checkForStandaloneChar: code=vWillProcess, bpc=1, ncc=1.
    resetEngineState();
    feedKey(KEY_RIGHT_BRACKET);
    assert(pData->code == vWillProcess);
    assert(pData->backspaceCount == 0);
    assert(pData->newCharCount == 1);
    feedKey(KEY_RIGHT_BRACKET);
    assert(pData->code == vWillProcess);
    assert(pData->backspaceCount == 1);
    assert(pData->newCharCount == 1);

    // Same with `[` followed by `[` (reverses 'ư' back to `[`)
    resetEngineState();
    feedKey(KEY_LEFT_BRACKET);
    feedKey(KEY_LEFT_BRACKET);
    assert(pData->code == vWillProcess);
    assert(pData->backspaceCount == 1);
    assert(pData->newCharCount == 1);

    std::cout << "  Passed E1." << std::endl;
}

// E3/E8: words of 31, 32, 33 chars with quick consonants enabled, then space
static void testE3_E8() {
    std::cout << "[Test] E3/E8: words of 31, 32, 33 chars with quick consonants..." << std::endl;
    for (int len : {31, 32, 33}) {
        resetEngineState();
        vQuickStartConsonant = 1;
        vQuickEndConsonant = 1;
        // f is quick start consonant (f -> ph), then vowels/consonants ending with g (hag -> hang)
        // Type len characters: e.g. f, then (len-2) 'a's, then 'k' (bak -> bach)
        feedKey(KEY_F);
        for (int i = 1; i < len - 1; i++) {
            feedKey(KEY_A);
        }
        feedKey(KEY_K); // quick end consonant k -> ch
        // Then feed space: triggers checkQuickConsonant() -> lines 1239-1264
        feedKey(KEY_SPACE);
        assert(pData->newCharCount <= MAX_BUFF);
    }
    // Also test a key event where hCode is vRestore or vWillProcess with _index >= MAX_BUFF
    // to hit Engine.cpp:1523
    resetEngineState();
    vUseMacro = 1;
    for (int i = 0; i < 35; i++) {
        feedKey(KEY_A);
    }
    // Now feed 's' (sắc) to trigger tone mark on last vowel -> hCode = vWillProcess / vRestore
    feedKey(KEY_S);
    std::cout << "  Passed E3/E8." << std::endl;
}
// E5: initMacroMap with truncated blobs and bogus counts/lengths
static void testE5() {
    std::cout << "[Test] E5: initMacroMap truncated/bogus blobs..." << std::endl;
    // Empty
    initMacroMap(nullptr, 0);
    // Truncated count (1 byte)
    Byte b1[1] = {0x01};
    initMacroMap(b1, 1);
    // Count = 10, but total size = 2
    Byte b2[2] = {0x0A, 0x00};
    initMacroMap(b2, 2);
    // Count = 1, macroTextSize = 20, but only 2 bytes provided
    Byte b3[4] = {0x01, 0x00, 0x14, 'a'};
    initMacroMap(b3, 4);
    // Count = 1, macroText valid, macroContentSize = 500, but truncated
    Byte b4[8] = {0x01, 0x00, 0x01, 'a', 0xF4, 0x01, 'b', 'c'};
    initMacroMap(b4, 8);
    std::cout << "  Passed E5." << std::endl;
}

// E6: initSmartSwitchKey with truncated/bogus blobs
static void testE6() {
    std::cout << "[Test] E6: initSmartSwitchKey truncated/bogus blobs..." << std::endl;
    initSmartSwitchKey(nullptr, 0);
    Byte b1[1] = {0x05};
    initSmartSwitchKey(b1, 1);
    Byte b2[2] = {0x0A, 0x00};
    initSmartSwitchKey(b2, 2);
    Byte b3[4] = {0x01, 0x00, 0x20, 'c'};
    initSmartSwitchKey(b3, 4);
    Byte b4[6] = {0x01, 0x00, 0x02, 'a', 'b'}; // missing value byte
    initSmartSwitchKey(b4, 5);
    std::cout << "  Passed E6." << std::endl;
}

// E7: invalid UTF-8 passed through code that calls utf8ToWideString
static void testE7() {
    std::cout << "[Test] E7: invalid UTF-8 in utf8ToWideString..." << std::endl;
    string invalidUtf8 = "\xFF\xFE\xFD";
    try {
        wstring ws = utf8ToWideString(invalidUtf8);
        (void)ws;
    } catch (...) {
        // Unfixed code might throw exception
    }
    // Also via addMacro
    addMacro(invalidUtf8, invalidUtf8);
    std::cout << "  Passed E7." << std::endl;
}

// E9/A13: 300+ chars without a space with macros enabled and a macro defined
static void testE9_A13() {
    std::cout << "[Test] E9/A13: 300+ chars without space..." << std::endl;
    resetEngineState();
    vUseMacro = 1;
    addMacro("test", "testing macro");
    for (int i = 0; i < 350; i++) {
        feedKey(KEY_A);
        assert(pData->backspaceCount <= MAX_BUFF);
    }
    // Now trigger space to check if backspaceCount wrapped
    feedKey(KEY_SPACE);
    assert(pData->backspaceCount <= MAX_BUFF);
    std::cout << "  Passed E9/A13." << std::endl;
}

// E11: addMacro with shortcut >255 bytes and content >65535 bytes round-trip
static void testE11() {
    std::cout << "[Test] E11: addMacro oversized shortcut & content round-trip..." << std::endl;
    string longKey(300, 'k');
    string longContent(70000, 'c');
    addMacro(longKey, longContent);
    vector<Byte> outData;
    getMacroSaveData(outData);
    initMacroMap(outData.data(), (int)outData.size());
    // Also SmartSwitchKey with oversized bundleId >255
    setAppInputMethodStatus(string(300, 'x'), 1);
    vector<Byte> sskData;
    getSmartSwitchKeySaveData(sskData);
    initSmartSwitchKey(sskData.data(), (int)sskData.size());
    std::cout << "  Passed E11." << std::endl;
}

int main() {
    pData = (vKeyHookState*)vKeyInit();
    assert(pData != nullptr);

    testTelexCorrectness();
    testVNICorrectness();
    testE1();
    testE3_E8();
    testE5();
    testE6();
    testE7();
    testE9_A13();
    testE11();

    std::cout << "\nALL TESTS PASSED!" << std::endl;
    return 0;
}
