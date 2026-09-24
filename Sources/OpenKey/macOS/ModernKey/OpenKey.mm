//
//  OpenKey.m
//  OpenKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#include <libproc.h>
#import "Engine.h"
#import "AppDelegate.h"
#import "OpenKeyManager.h"
#import "ViewController.h"

#define OTHER_CONTROL_KEY (_flag & kCGEventFlagMaskCommand) || (_flag & kCGEventFlagMaskControl) || \
                            (_flag & kCGEventFlagMaskAlternate) || (_flag & kCGEventFlagMaskSecondaryFn) || \
                            (_flag & kCGEventFlagMaskNumericPad) || (_flag & kCGEventFlagMaskHelp)

#define DYNA_DATA(macro, pos) (macro ? pData->macroData[pos] : pData->charData[pos])
#define MAX_UNICODE_STRING  20
#define EMPTY_HOTKEY 0xFE0000FE
#define LOAD_DATA(VAR, KEY) VAR = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@#KEY]

// Ignore code for Modifier keys and numpad
// Reference: https://eastmanreference.com/complete-list-of-applescript-key-codes
NSDictionary *keyStringToKeyCodeMap = @{
    // Characters from number row
    @"`": @50, @"~": @50, @"1": @18, @"!": @18, @"2": @19, @"@": @19, @"3": @20, @"#": @20, @"4": @21, @"$": @21,
    @"5": @23, @"%": @23, @"6": @22, @"^": @22, @"7": @26, @"&": @26, @"8": @28, @"*": @28, @"9": @25, @"(": @25,
    @"0": @29, @")": @29, @"-": @27, @"_": @27, @"=": @24, @"+": @24,
    // Characters from first keyboard row
    @"q": @12, @"w": @13, @"e": @14, @"r": @15, @"t": @17, @"y": @16, @"u": @32, @"i": @34, @"o": @31, @"p": @35,
    @"[": @33, @"{": @33, @"]": @30, @"}": @30, @"\\": @42, @"|": @42,
    // Characters from second keyboard row
    @"a": @0, @"s": @1, @"d": @2, @"f": @3, @"g": @5, @"h": @4, @"j": @38, @"k": @40, @"l": @37,
    @";": @41, @":": @41, @"'": @39, @"\"": @39,
    // Characters from second third row
    @"z": @6, @"x": @7, @"c": @8, @"v": @9, @"b": @11, @"n": @45, @"m": @46,
    @",": @43, @"<": @43, @".": @47, @">": @47, @"/": @44, @"?": @44
};

extern ViewController* viewController;

extern AppDelegate* appDelegate;
extern int vSendKeyStepByStep;
extern int vFixChromiumBrowser;
extern int vPerformLayoutCompat;

extern "C" {
    //app which must sent special empty character
    NSArray* _niceSpaceApp = @[@"com.sublimetext.3",
                               @"com.sublimetext.2",
                             ];
    
    //app which error with unicode Compound
    NSArray* _unicodeCompoundApp = @[@"com.apple.",
                                     @"com.google.Chrome", @"com.brave.Browser",
                                     @"com.microsoft.edgemac.Dev", @"com.microsoft.edgemac.Beta", @"com.microsoft.Edge.Dev", @"com.microsoft.Edge"];
    NSArray* _recommendWorkaroundDisabledApp = @[@"com.apple.Spotlight"];

    //design apps render the U+202F/U+200C autocomplete trick as a missing-glyph
    //box and may swallow the following backspace; they have no inline completion.
    //Prefix match. Ported from mkey (github.com/maclifevn/mkey, GPLv3).
    NSArray* _recommendWorkaroundSkipPrefix = @[@"com.adobe.", @"com.seriflabs."];

    //overlay search fields that process input asynchronously: synthesized
    //backspaces race with the inline completion. Edit via Accessibility instead.
    //Spotlight is a non-activating panel, so detect via the AX-focused element's pid.
    NSArray* _axSlowPathApp = @[@"com.apple.Spotlight",
                                @"com.apple.campo",              //new Spotlight (macOS 26+)
                                @"com.apple.launchpad.launcher",
                                //Raycast omitted: its field ignores AX edits (drops chars); key events work
                                @"com.runningwithcrayons.Alfred"];

    //"other language" check: cached, refreshed on input-source change notification
    bool _isEnglishInputSource = true;
    
    CGEventSourceRef myEventSource = NULL;
    vKeyHookState* pData;
    UniChar _newChar, _newCharHi;
    CGEventRef _newEventDown, _newEventUp;
    CGKeyCode _keycode;
    CGEventFlags _flag, _lastFlag = 0, _privateFlag;
    CGEventTapProxy _proxy;
    
    Uint16 _newCharString[MAX_UNICODE_STRING];
    Uint16 _newCharSize;
    bool _willContinuteSending = false;
    bool _willSendControlKey = false;
    
    vector<Uint16> _syncKey;
    
    Uint16 _uniChar[2];
    int _i, _j, _k;
    Uint32 _tempChar;
    bool _hasJustUsedHotKey = false;

    int _languageTemp = 0; //use for smart switch key
    vector<Byte> savedSmartSwitchKeyData; ////use for smart switch key
    
    NSString* _frontMostApp = @"UnknownApp";
    //app receiving the current event (resolved from its target pid, cached);
    //set at callback entry, valid for all Send* helpers during that event
    NSString* _targetApp = nil;

    void UpdateInputSourceCache(void);
    void AXInvalidateFocusCache(void);
    CFAbsoluteTime _axLastKeyTime = 0;
    
    void OpenKeyInit() {
        //load saved data
        vFreeMark = 0;//(int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FreeMark"];
        LOAD_DATA(vCodeTable, CodeTable); if (vCodeTable < 0) vCodeTable = 0;
        LOAD_DATA(vCheckSpelling, Spelling);
        LOAD_DATA(vQuickTelex, QuickTelex);
        LOAD_DATA(vUseModernOrthography, ModernOrthography);
        LOAD_DATA(vRestoreIfWrongSpelling, RestoreIfInvalidWord);
        LOAD_DATA(vFixRecommendBrowser, FixRecommendBrowser);
        LOAD_DATA(vUseMacro, UseMacro);
        LOAD_DATA(vUseMacroInEnglishMode, UseMacroInEnglishMode);
        LOAD_DATA(vAutoCapsMacro, vAutoCapsMacro);
        LOAD_DATA(vSendKeyStepByStep, SendKeyStepByStep);
        LOAD_DATA(vUseSmartSwitchKey, UseSmartSwitchKey);
        LOAD_DATA(vUpperCaseFirstChar, UpperCaseFirstChar);
        
        LOAD_DATA(vTempOffSpelling, vTempOffSpelling);
        LOAD_DATA(vAllowConsonantZFWJ, vAllowConsonantZFWJ);
        LOAD_DATA(vQuickEndConsonant, vQuickEndConsonant);
        LOAD_DATA(vQuickStartConsonant, vQuickStartConsonant);
        LOAD_DATA(vRememberCode, vRememberCode);
        LOAD_DATA(vOtherLanguage, vOtherLanguage);
        LOAD_DATA(vTempOffOpenKey, vTempOffOpenKey);
        
        LOAD_DATA(vFixChromiumBrowser, vFixChromiumBrowser);
        
        LOAD_DATA(vPerformLayoutCompat, vPerformLayoutCompat);
        
        myEventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);

        UpdateInputSourceCache();
        static bool inputSourceObserved = false;
        if (!inputSourceObserved) {
            inputSourceObserved = true;
            [[NSDistributedNotificationCenter defaultCenter] addObserverForName:(__bridge NSString*)kTISNotifySelectedKeyboardInputSourceChanged
                                                                         object:nil queue:[NSOperationQueue mainQueue]
                                                                     usingBlock:^(NSNotification* note) { UpdateInputSourceCache(); }];
        }
        pData = (vKeyHookState*)vKeyInit();

        
        //init and load macro data
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSData *data = [prefs objectForKey:@"macroData"];
        initMacroMap((Byte*)data.bytes, (int)data.length);
        
        //init and load smart switch key data
        data = [prefs objectForKey:@"smartSwitchKey"];
        initSmartSwitchKey((Byte*)data.bytes, (int)data.length);
        
        //init convert tool
        convertToolDontAlertWhenCompleted = ![prefs boolForKey:@"convertToolDontAlertWhenCompleted"];
        convertToolToAllCaps = [prefs boolForKey:@"convertToolToAllCaps"];
        convertToolToAllNonCaps = [prefs boolForKey:@"convertToolToAllNonCaps"];
        convertToolToCapsFirstLetter = [prefs boolForKey:@"convertToolToCapsFirstLetter"];
        convertToolToCapsEachWord = [prefs boolForKey:@"convertToolToCapsEachWord"];
        convertToolRemoveMark = [prefs boolForKey:@"convertToolRemoveMark"];
        convertToolFromCode = [prefs integerForKey:@"convertToolFromCode"];
        convertToolToCode = [prefs integerForKey:@"convertToolToCode"];
        convertToolHotKey = (int)[prefs integerForKey:@"convertToolHotKey"];
        if (convertToolHotKey == 0) {
            convertToolHotKey = EMPTY_HOTKEY;
        }
    }
    

    void RequestNewSession() {
        AXInvalidateFocusCache();
        //send event signal to Engine
        vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);
        
        if (IS_DOUBLE_CODE(vCodeTable)) { //VNI
            _syncKey.clear();
        }
    }
    
    void queryFrontMostApp() {
        if ([[[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier compare:OPENKEY_BUNDLE] != 0) {
            _frontMostApp = [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier;
            if (_frontMostApp == nil)
                _frontMostApp = [[NSWorkspace sharedWorkspace] frontmostApplication].localizedName != nil ?
                [[NSWorkspace sharedWorkspace] frontmostApplication].localizedName : @"UnknownApp";
        }
    }
    
    NSString* ConvertUtil(NSString* str) {
        return [NSString stringWithUTF8String:convertUtil([str UTF8String]).c_str()];
    }
    
    BOOL containUnicodeCompoundApp(NSString* topApp) {
        if (topApp == nil) return false;
        for (_j = 0; _j < [_unicodeCompoundApp count]; _j++) {
            if ([topApp hasPrefix:[_unicodeCompoundApp objectAtIndex:_j]] || [[_unicodeCompoundApp objectAtIndex:_j] isEqualToString:topApp])
                return true;
        }
        return false;
    }

    NSString* getTargetApp(CGEventRef event) {
        int64_t targetPID = CGEventGetIntegerValueField(event, kCGEventTargetUnixProcessID);
        static int64_t _cachedPID = -1;
        static NSString* _cachedApp = nil;
        if (targetPID > 0) {
            if (targetPID == _cachedPID && _cachedApp != nil) {
                return _cachedApp;
            }
            NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:(pid_t)targetPID];
            if (app && app.bundleIdentifier) {
                _cachedPID = targetPID;
                _cachedApp = app.bundleIdentifier;
                return _cachedApp;
            }
        }
        return [[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier;
    }

    BOOL isSpotlightApp(NSString* app) {
        if (!app) return false;
        return [app isEqualToString:@"com.apple.Spotlight"] || [app hasPrefix:@"com.apple.Spotlight"];
    }

    BOOL shouldUseRecommendWorkaround(NSString* topApp) {
        if (!vFixRecommendBrowser) return false;
        if (isSpotlightApp(topApp)) return false;
        if (topApp == nil) return true;
        for (NSString* prefix in _recommendWorkaroundSkipPrefix) {
            if ([topApp hasPrefix:prefix]) return false;
        }
        return ![_recommendWorkaroundDisabledApp containsObject:topApp];
    }

    void UpdateInputSourceCache() {
        TISInputSourceRef isource = TISCopyCurrentKeyboardInputSource();
        if (isource == NULL) return;
        CFArrayRef languages = (CFArrayRef)TISGetInputSourceProperty(isource, kTISPropertyInputSourceLanguages);
        if (languages != NULL && CFArrayGetCount(languages) > 0) {
            NSString* lang = (__bridge NSString*)CFArrayGetValueAtIndex(languages, 0);
            _isEnglishInputSource = [lang isLike:@"en"];
        }
        CFRelease(isource);
    }

    // ---- Accessibility edit path (Spotlight/Alfred). Ported from mkey. ----
    // ponytail: slow-path app list is hardcoded; add a user-editable list + toggle
    // when someone needs AX editing in another app.
    AXUIElementRef _axSystemWide = NULL;
    AXUIElementRef _axFocused = NULL;
    bool _axFocusedIsSlow = false;
    bool _axCacheValid = false;

    void AXInvalidateFocusCache() {
        if (_axFocused) { CFRelease(_axFocused); _axFocused = NULL; }
        _axFocusedIsSlow = false;
        _axCacheValid = false;
    }

    //one AX IPC per focus change; invalidated by mouse, app switch, ⌘/⌃ keys
    void AXRefreshFocusCache() {
        if (_axCacheValid) return;
        AXInvalidateFocusCache();
        _axCacheValid = true;
        if (_axSystemWide == NULL) {
            _axSystemWide = AXUIElementCreateSystemWide();
            //AX calls run inside the tap callback: a hung target app would block
            //typing for the 6s default and get the tap disabled. Cap at 100ms.
            AXUIElementSetMessagingTimeout(_axSystemWide, 0.1);
        }
        AXUIElementRef focused = NULL;
        if (AXUIElementCopyAttributeValue(_axSystemWide, kAXFocusedUIElementAttribute, (CFTypeRef*)&focused) != kAXErrorSuccess || focused == NULL)
            return;
        AXUIElementSetMessagingTimeout(focused, 0.1);
        _axFocused = focused;
        pid_t pid = 0;
        if (AXUIElementGetPid(focused, &pid) != kAXErrorSuccess) return;
        NSString* bid = [NSRunningApplication runningApplicationWithProcessIdentifier:pid].bundleIdentifier;
        if (bid != nil && [_axSlowPathApp containsObject:bid]) {
            _axFocusedIsSlow = true;
            return;
        }
        //new Spotlight may run without a bundle id: match executable path
        char path[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(pid, path, sizeof(path)) > 0) {
            _axFocusedIsSlow = strstr(path, "/Spotlight.app/") != NULL || strstr(path, "/Campo.app/") != NULL;
        }
    }

    bool AXSlowPathActive() {
        if (vCodeTable != 0) return false; //Unicode only: AX strings are UTF-16
        AXRefreshFocusCache();
        return _axFocusedIsSlow && _axFocused != NULL;
    }

    //Atomically replace deleteCount chars before the caret (plus any selected
    //inline completion) with insert. False → caller falls back to key events.
    bool AXReplaceTextDirect(long deleteCount, NSString* insert) {
        AXUIElementRef focused = _axFocused;
        if (focused == NULL) return false;

        AXValueRef rangeVal = NULL;
        if (AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute, (CFTypeRef*)&rangeVal) != kAXErrorSuccess || rangeVal == NULL) {
            AXInvalidateFocusCache();
            return false;
        }
        CFRange sel = CFRangeMake(0, 0);
        bool gotRange = AXValueGetValue(rangeVal, (AXValueType)kAXValueCFRangeType, &sel);
        CFRelease(rangeVal);
        if (!gotRange || sel.location < deleteCount) return false;
        CFRange replaceRange = CFRangeMake(sel.location - deleteCount, deleteCount + sel.length);

        //strategy 1: select range, set selected text
        AXValueRef newRangeVal = AXValueCreate((AXValueType)kAXValueCFRangeType, &replaceRange);
        AXError err = AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute, newRangeVal);
        CFRelease(newRangeVal);
        if (err == kAXErrorSuccess &&
            AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute, (__bridge CFTypeRef)insert) == kAXErrorSuccess)
            return true;

        //strategy 2: rewrite whole value, restore caret
        CFTypeRef valueRef = NULL;
        if (AXUIElementCopyAttributeValue(focused, kAXValueAttribute, &valueRef) != kAXErrorSuccess || valueRef == NULL) {
            AXInvalidateFocusCache();
            return false;
        }
        if (CFGetTypeID(valueRef) != CFStringGetTypeID()) { CFRelease(valueRef); return false; }
        NSString* value = (__bridge_transfer NSString*)valueRef;
        if ((NSUInteger)(replaceRange.location + replaceRange.length) > value.length) return false;
        NSString* newValue = [value stringByReplacingCharactersInRange:NSMakeRange(replaceRange.location, replaceRange.length) withString:insert];
        if (AXUIElementSetAttributeValue(focused, kAXValueAttribute, (__bridge CFTypeRef)newValue) != kAXErrorSuccess) {
            AXInvalidateFocusCache();
            return false;
        }
        CFRange caret = CFRangeMake(replaceRange.location + (long)insert.length, 0);
        AXValueRef caretVal = AXValueCreate((AXValueType)kAXValueCFRangeType, &caret);
        AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute, caretVal);
        CFRelease(caretVal);
        return true;
    }

    //engine char data (Unicode table) → UTF-16; 0 on unmappable key
    Uint16 AXCharFromData(Uint32 t) {
        if (t & PURE_CHARACTER_MASK) return (Uint16)t;
        if (!(t & CHAR_CODE_MASK)) return keyCodeToCharacter(t);
        return (Uint16)t;
    }

    bool TryAXProcessKey() {
        if (pData->newCharCount > MAX_BUFF) return false;
        Uint16 buf[MAX_BUFF + 1];
        int n = 0;
        for (int k = pData->newCharCount - 1; k >= 0; k--) {
            if ((buf[n++] = AXCharFromData(pData->charData[k])) == 0) return false;
        }
        if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
            Uint16 keyChar = keyCodeToCharacter(_keycode | ((_flag & kCGEventFlagMaskAlphaShift) || (_flag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
            if (keyChar == 0) return false; //restore ends with control key: event path handles it
            buf[n++] = keyChar;
        }
        if (!AXReplaceTextDirect(pData->backspaceCount, [NSString stringWithCharacters:buf length:n]))
            return false;
        if (pData->code == vRestoreAndStartNewSession)
            startNewSession();
        return true;
    }

    bool TryAXProcessMacro() {
        NSMutableString* s = [NSMutableString stringWithCapacity:pData->macroData.size()];
        for (size_t k = 0; k < pData->macroData.size(); k++) {
            Uint16 ch = AXCharFromData(pData->macroData[k]);
            if (ch == 0) return false;
            [s appendFormat:@"%C", ch];
        }
        return AXReplaceTextDirect(pData->backspaceCount, s);
    }

    void saveSmartSwitchKeyData() {
        getSmartSwitchKeySaveData(savedSmartSwitchKeyData);
        NSData* _data = [NSData dataWithBytes:savedSmartSwitchKeyData.data() length:savedSmartSwitchKeyData.size()];
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs setObject:_data forKey:@"smartSwitchKey"];
    }
    
    BOOL isAppExcluded(NSString* bundleId) {
        if (!bundleId) return false;
        NSArray* list = [[NSUserDefaults standardUserDefaults] arrayForKey:@"excludedApps"];
        return [list containsObject:bundleId];
    }

    void OnActiveAppChanged() { //use for smart switch key; improved on Sep 28th, 2019
        AXInvalidateFocusCache();
        queryFrontMostApp();

        // Manual app exclusion: force English while inside, restore on leave.
        static BOOL _inExcludedApp = false;
        static int _languageBeforeExclusion = 1;
        if (isAppExcluded(_frontMostApp)) {
            if (!_inExcludedApp) {
                _inExcludedApp = true;
                _languageBeforeExclusion = vLanguage;
            }
            if (vLanguage != 0) {
                vLanguage = 0;
                [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"InputMethod"];
                [appDelegate fillData];
                startNewSession();
            }
            return;
        }
        if (_inExcludedApp) {
            _inExcludedApp = false;
            if (vLanguage != _languageBeforeExclusion) {
                vLanguage = _languageBeforeExclusion;
                [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:@"InputMethod"];
                [appDelegate fillData];
                startNewSession();
            }
        }

        if (!vUseSmartSwitchKey && !vRememberCode)
            return;

        _languageTemp = getAppInputMethodStatus(string(_frontMostApp.UTF8String), vLanguage | (vCodeTable << 1));
        if (vUseSmartSwitchKey && (_languageTemp & 0x01) != vLanguage) { //for input method
            if (_languageTemp != -1) {
                vLanguage = _languageTemp;
                [appDelegate onImputMethodChanged:NO];
                startNewSession();
            } else {
                saveSmartSwitchKeyData();
            }
        }
        if (vRememberCode && (_languageTemp >> 1) != vCodeTable) { //for remember table code feature
            if (_languageTemp != -1) {
                [appDelegate onCodeTableChanged:(_languageTemp >> 1)];
            } else {
                saveSmartSwitchKeyData();
            }
        }
    }
    
    void OnTableCodeChange() {
        onTableCodeChange();
        if (vRememberCode) {
            queryFrontMostApp();
            setAppInputMethodStatus(string(_frontMostApp.UTF8String), vLanguage | (vCodeTable << 1));
            saveSmartSwitchKeyData();
        }
    }
    
    void OnInputMethodChanged() {
        if (vUseSmartSwitchKey) {
            queryFrontMostApp();
            setAppInputMethodStatus(string(_frontMostApp.UTF8String), vLanguage | (vCodeTable << 1));
            saveSmartSwitchKeyData();
        }
    }
    
    void OnSpellCheckingChanged() {
        vSetCheckSpelling();
    }
    
    void InsertKeyLength(const Uint8& len) {
        _syncKey.push_back(len);
    }
    
    void SendPureCharacter(const Uint16& ch) {
        _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
        _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
        CGEventKeyboardSetUnicodeString(_newEventDown, 1, &ch);
        CGEventKeyboardSetUnicodeString(_newEventUp, 1, &ch);
        CGEventTapPostEvent(_proxy, _newEventDown);
        CGEventTapPostEvent(_proxy, _newEventUp);
        CFRelease(_newEventDown);
        CFRelease(_newEventUp);
        if (IS_DOUBLE_CODE(vCodeTable)) {
            InsertKeyLength(1);
        }
    }
    
    void SendKeyCode(Uint32 data) {
        _newChar = (Uint16)data;
        if (!(data & CHAR_CODE_MASK)) {
            if (IS_DOUBLE_CODE(vCodeTable)) //VNI
                InsertKeyLength(1);
            
            _newEventDown = CGEventCreateKeyboardEvent(myEventSource, _newChar, true);
            _newEventUp = CGEventCreateKeyboardEvent(myEventSource, _newChar, false);
            _privateFlag = CGEventGetFlags(_newEventDown);
            
            if (data & CAPS_MASK) {
                _privateFlag |= kCGEventFlagMaskShift;
            } else {
                _privateFlag &= ~kCGEventFlagMaskShift;
            }
            _privateFlag |= kCGEventFlagMaskNonCoalesced;
            
            CGEventSetFlags(_newEventDown, _privateFlag);
            CGEventSetFlags(_newEventUp, _privateFlag);
            CGEventTapPostEvent(_proxy, _newEventDown);
            CGEventTapPostEvent(_proxy, _newEventUp);
        } else {
            if (vCodeTable == 0) { //unicode 2 bytes code
                _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                CGEventKeyboardSetUnicodeString(_newEventDown, 1, &_newChar);
                CGEventKeyboardSetUnicodeString(_newEventUp, 1, &_newChar);
                CGEventTapPostEvent(_proxy, _newEventDown);
                CGEventTapPostEvent(_proxy, _newEventUp);
            } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { //others such as VNI Windows, TCVN3: 1 byte code
                _newCharHi = HIBYTE(_newChar);
                _newChar = LOBYTE(_newChar);
                
                _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                CGEventKeyboardSetUnicodeString(_newEventDown, 1, &_newChar);
                CGEventKeyboardSetUnicodeString(_newEventUp, 1, &_newChar);
                CGEventTapPostEvent(_proxy, _newEventDown);
                CGEventTapPostEvent(_proxy, _newEventUp);
                if (_newCharHi > 32) {
                    if (vCodeTable == 2) //VNI
                        InsertKeyLength(2);
                    CFRelease(_newEventDown);
                    CFRelease(_newEventUp);
                    _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                    _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                    CGEventKeyboardSetUnicodeString(_newEventDown, 1, &_newCharHi);
                    CGEventKeyboardSetUnicodeString(_newEventUp, 1, &_newCharHi);
                    CGEventTapPostEvent(_proxy, _newEventDown);
                    CGEventTapPostEvent(_proxy, _newEventUp);
                } else {
                    if (vCodeTable == 2) //VNI
                        InsertKeyLength(1);
                }
            } else if (vCodeTable == 3) { //Unicode Compound
                _newCharHi = (_newChar >> 13);
                _newChar &= 0x1FFF;
                _uniChar[0] = _newChar;
                _uniChar[1] = _newCharHi > 0 ? (_unicodeCompoundMark[_newCharHi - 1]) : 0;
                InsertKeyLength(_newCharHi > 0 ? 2 : 1);
                _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
                _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
                CGEventKeyboardSetUnicodeString(_newEventDown, (_newCharHi > 0 ? 2 : 1), _uniChar);
                CGEventKeyboardSetUnicodeString(_newEventUp, (_newCharHi > 0 ? 2 : 1), _uniChar);
                CGEventTapPostEvent(_proxy, _newEventDown);
                CGEventTapPostEvent(_proxy, _newEventUp);
            }
        }
        CFRelease(_newEventDown);
        CFRelease(_newEventUp);
    }
    
    void SendEmptyCharacter() {
        if (IS_DOUBLE_CODE(vCodeTable)) //VNI or Unicode Compound
            InsertKeyLength(1);
        
        _newChar = 0x202F; //empty char
        if ([_niceSpaceApp containsObject:_targetApp]) {
            _newChar = 0x200C; //Unicode character with empty space
        }
        
        _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
        _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
        CGEventKeyboardSetUnicodeString(_newEventDown, 1, &_newChar);
        CGEventKeyboardSetUnicodeString(_newEventUp, 1, &_newChar);
        CGEventTapPostEvent(_proxy, _newEventDown);
        CGEventTapPostEvent(_proxy, _newEventUp);
        CFRelease(_newEventDown);
        CFRelease(_newEventUp);
    }
    
    void SendVirtualKey(const Byte& vKey) {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, vKey, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, vKey, false);
        
        CGEventTapPostEvent(_proxy, eventVkeyDown);
        CGEventTapPostEvent(_proxy, eventVkeyUp);
        
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }
    // Reused CGEventRefs desync WindowServer sequence numbers on modern macOS
    // (Apple Mail / WebKit key queue stalls), so allocate per send.
    void PostBackspaceEvent() {
        CGEventRef down = CGEventCreateKeyboardEvent(myEventSource, 51, true);
        CGEventRef up = CGEventCreateKeyboardEvent(myEventSource, 51, false);
        CGEventTapPostEvent(_proxy, down);
        CGEventTapPostEvent(_proxy, up);
        CFRelease(down);
        CFRelease(up);
    }


    void SendBackspace() {
        PostBackspaceEvent();
        
        if (IS_DOUBLE_CODE(vCodeTable)) { //VNI or Unicode Compound
            if (_syncKey.back() > 1) {
                if (!(vCodeTable == 3 && containUnicodeCompoundApp(_targetApp))) {
                    PostBackspaceEvent();
                }
            }
            _syncKey.pop_back();
        }
    }
    
    void SendShiftAndLeftArrow() {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, KEY_LEFT, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, KEY_LEFT, false);
        _privateFlag = CGEventGetFlags(eventVkeyDown);
        _privateFlag |= kCGEventFlagMaskShift;
        CGEventSetFlags(eventVkeyDown, _privateFlag);
        CGEventSetFlags(eventVkeyUp, _privateFlag);
        
        CGEventTapPostEvent(_proxy, eventVkeyDown);
        CGEventTapPostEvent(_proxy, eventVkeyUp);
        
        if (IS_DOUBLE_CODE(vCodeTable)) { //VNI or Unicode Compound
            if (_syncKey.back() > 1) {
                if (!(vCodeTable == 3 && containUnicodeCompoundApp(_targetApp))) {
                    CGEventTapPostEvent(_proxy, eventVkeyDown);
                    CGEventTapPostEvent(_proxy, eventVkeyUp);
                }
            }
            _syncKey.pop_back();
        }
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }
    
    void SendCutKey() {
        CGEventRef eventVkeyDown = CGEventCreateKeyboardEvent (myEventSource, KEY_X, true);
        CGEventRef eventVkeyUp = CGEventCreateKeyboardEvent (myEventSource, KEY_X, false);
        _privateFlag = CGEventGetFlags(eventVkeyDown);
        _privateFlag |= NX_COMMANDMASK;
        CGEventSetFlags(eventVkeyDown, _privateFlag);
        CGEventSetFlags(eventVkeyUp, _privateFlag);
        
        CGEventTapPostEvent(_proxy, eventVkeyDown);
        CGEventTapPostEvent(_proxy, eventVkeyUp);
        
        CFRelease(eventVkeyDown);
        CFRelease(eventVkeyUp);
    }
    
    void SendNewCharString(const bool& dataFromMacro=false, const Uint16& offset=0) {
        _j = 0;
        _newCharSize = dataFromMacro ? pData->macroData.size() : pData->newCharCount;
        _willContinuteSending = false;
        _willSendControlKey = false;
        
        if (_newCharSize > 0) {
            for (_k = dataFromMacro ? offset : pData->newCharCount - 1 - offset;
                 dataFromMacro ? _k < pData->macroData.size() : _k >= 0;
                 dataFromMacro ? _k++ : _k--) {
                
                if (_j >= 16) {
                    _willContinuteSending = true;
                    break;
                }
                
                _tempChar = DYNA_DATA(dataFromMacro, _k);
                if (_tempChar & PURE_CHARACTER_MASK) {
                    _newCharString[_j++] = _tempChar;
                    if (IS_DOUBLE_CODE(vCodeTable)) {
                        InsertKeyLength(1);
                    }
                } else if (!(_tempChar & CHAR_CODE_MASK)) {
                    if (IS_DOUBLE_CODE(vCodeTable)) //VNI
                        InsertKeyLength(1);
                    _newCharString[_j++] = keyCodeToCharacter(_tempChar);
                } else {
                    if (vCodeTable == 0) {  //unicode 2 bytes code
                        _newCharString[_j++] = _tempChar;
                    } else if (vCodeTable == 1 || vCodeTable == 2 || vCodeTable == 4) { //others such as VNI Windows, TCVN3: 1 byte code
                        _newChar = _tempChar;
                        _newCharHi = HIBYTE(_newChar);
                        _newChar = LOBYTE(_newChar);
                        _newCharString[_j++] = _newChar;
                        
                        if (_newCharHi > 32) {
                            if (vCodeTable == 2) //VNI
                                InsertKeyLength(2);
                            _newCharString[_j++] = _newCharHi;
                            _newCharSize++;
                        } else {
                            if (vCodeTable == 2) //VNI
                                InsertKeyLength(1);
                        }
                    } else if (vCodeTable == 3) { //Unicode Compound
                        _newChar = _tempChar;
                        _newCharHi = (_newChar >> 13);
                        _newChar &= 0x1FFF;
                        
                        InsertKeyLength(_newCharHi > 0 ? 2 : 1);
                        _newCharString[_j++] = _newChar;
                        if (_newCharHi > 0) {
                            _newCharSize++;
                            _newCharString[_j++] = _unicodeCompoundMark[_newCharHi - 1];
                        }
                        
                    }
                }
            }//end for
        }
        
        if (!_willContinuteSending && (pData->code == vRestore || pData->code == vRestoreAndStartNewSession)) { //if is restore
            if (keyCodeToCharacter(_keycode) != 0) {
                _newCharSize++;
                _newCharString[_j++] = keyCodeToCharacter(_keycode | ((_flag & kCGEventFlagMaskAlphaShift) || (_flag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
            } else {
                _willSendControlKey = true;
            }
        }
        if (!_willContinuteSending && pData->code == vRestoreAndStartNewSession) {
            startNewSession();
        }
        
        _newEventDown = CGEventCreateKeyboardEvent(myEventSource, 0, true);
        _newEventUp = CGEventCreateKeyboardEvent(myEventSource, 0, false);
        CGEventKeyboardSetUnicodeString(_newEventDown, _willContinuteSending ? 16 : _newCharSize - offset, _newCharString);
        CGEventKeyboardSetUnicodeString(_newEventUp, _willContinuteSending ? 16 : _newCharSize - offset, _newCharString);
        CGEventTapPostEvent(_proxy, _newEventDown);
        CGEventTapPostEvent(_proxy, _newEventUp);
        CFRelease(_newEventDown);
        CFRelease(_newEventUp);

        if (_willContinuteSending) {
            SendNewCharString(dataFromMacro, dataFromMacro ? _k : 16);
        }
        
        //the case when hCode is vRestore or vRestoreAndStartNewSession, the word is invalid and last key is control key such as TAB, LEFT ARROW, RIGHT ARROW,...
        if (_willSendControlKey) {
            SendKeyCode(_keycode);
        }
    }
            
    bool checkHotKey(int hotKeyData, bool checkKeyCode=true) {
        if ((hotKeyData & (~0x8000)) == EMPTY_HOTKEY)
            return false;
        if (HAS_CONTROL(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskControl))
            return false;
        if (HAS_OPTION(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskAlternate))
            return false;
        if (HAS_COMMAND(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskCommand))
            return false;
        if (HAS_SHIFT(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskShift))
            return false;
        if (HAS_FN(hotKeyData) ^ GET_BOOL(_lastFlag & kCGEventFlagMaskSecondaryFn))
            return false;
        if (checkKeyCode) {
            if (GET_SWITCH_KEY(hotKeyData) != _keycode)
                return false;
        }
        return true;
    }
    
    void switchLanguage() {
        if (vLanguage == 0)
            vLanguage = 1;
        else
            vLanguage = 0;
        if (HAS_BEEP(vSwitchKeyStatus)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSSound *sound = [NSSound soundNamed:@"Tink"];
                if (sound) {
                    [sound play];
                } else {
                    NSBeep();
                }
            });
        }
        [appDelegate onImputMethodChanged:YES];
        startNewSession();
    }
    
    void handleMacro() {
        //Spotlight-like fields: atomic AX replace, then deliver trigger key normally
        if (AXSlowPathActive() && TryAXProcessMacro()) {
            SendKeyCode(_keycode | (_flag & kCGEventFlagMaskShift ? CAPS_MASK : 0));
            return;
        }

        //fix autocomplete
        if (shouldUseRecommendWorkaround(_targetApp)) {
            SendEmptyCharacter();
            pData->backspaceCount++;
        }
        
        //send backspace
        if (pData->backspaceCount > 0) {
            for (int i = 0; i < pData->backspaceCount; i++) {
                SendBackspace();
            }
        }
        //send real data
        if (!vSendKeyStepByStep) {
            SendNewCharString(true);
        } else {
            for (int i = 0; i < pData->macroData.size(); i++) {
                if (pData->macroData[i] & PURE_CHARACTER_MASK) {
                    SendPureCharacter(pData->macroData[i]);
                } else {
                    SendKeyCode(pData->macroData[i]);
                }
            }
        }
        SendKeyCode(_keycode | (_flag & kCGEventFlagMaskShift ? CAPS_MASK : 0));
    }

    // TODO: Research API to convert character into CGKeyCode more elegantly!
    int ConvertKeyStringToKeyCode(NSString *keyString, CGKeyCode fallback) {
        // Infomation about capitalization (shift/caps) is already included
        // in the original CGEvent, only find out which position on keyboard a key is pressed
        NSString *lowercasedKeyString = [keyString lowercaseString];
        if (!lowercasedKeyString) {
            return fallback;
        }
        
        NSNumber *keycode = [keyStringToKeyCodeMap objectForKey:lowercasedKeyString];

        if (keycode) {
            return [keycode intValue];
        }
        return fallback;
    }

    // If conversion fails, return fallbackKeyCode
    CGKeyCode ConvertEventToKeyboadLayoutCompatKeyCode(CGEventRef keyEvent, CGKeyCode fallbackKeyCode) {
        NSEvent *kbLayoutCompatEvent = [NSEvent eventWithCGEvent:keyEvent];
        NSString *kbLayoutCompatKeyString = kbLayoutCompatEvent.charactersIgnoringModifiers;
        return ConvertKeyStringToKeyCode(kbLayoutCompatKeyString,
                                         fallbackKeyCode);
    }

    /**
     * MAIN HOOK entry, very important function.
     * MAIN Callback.
     */
    CGEventRef OpenKeyCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
        // macOS kills taps on callback timeout or secure input; revive immediately.
        if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
            CGEventTapEnable(eventTap, true);
            return event;
        }
        //dont handle my event
        if (CGEventGetIntegerValueField(event, kCGEventSourceStateID) == CGEventSourceGetSourceStateID(myEventSource)) {
            return event;
        }
        
        NSString* targetApp = _targetApp = getTargetApp(event);
        
        _flag = CGEventGetFlags(event);
        _keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        
        if (type == kCGEventKeyDown && vPerformLayoutCompat) {
            // If conversion fail, use current keycode
           _keycode = ConvertEventToKeyboadLayoutCompatKeyCode(event, _keycode);
        }
        
        //switch language shortcut; convert hotkey
        if (type == kCGEventKeyDown) {
            if (GET_SWITCH_KEY(vSwitchKeyStatus) != _keycode && GET_SWITCH_KEY(convertToolHotKey) != _keycode) {
                _lastFlag = 0;
            } else {
                if (GET_SWITCH_KEY(vSwitchKeyStatus) == _keycode && checkHotKey(vSwitchKeyStatus, GET_SWITCH_KEY(vSwitchKeyStatus) != 0xFE)){
                    switchLanguage();
                    _lastFlag = 0;
                    _hasJustUsedHotKey = true;
                    return NULL;
                }
                if (GET_SWITCH_KEY(convertToolHotKey) == _keycode && checkHotKey(convertToolHotKey, GET_SWITCH_KEY(convertToolHotKey) != 0xFE)){
                    [appDelegate onQuickConvert];
                    _lastFlag = 0;
                    _hasJustUsedHotKey = true;
                    return NULL;
                }
            }
            _hasJustUsedHotKey = _lastFlag != 0;
        } else if (type == kCGEventFlagsChanged) {
            if (_lastFlag == 0 || _lastFlag < _flag) {
                _lastFlag = _flag;
            } else if (_lastFlag > _flag)  {
                //check switch
                if (checkHotKey(vSwitchKeyStatus, GET_SWITCH_KEY(vSwitchKeyStatus) != 0xFE)) {
                    _lastFlag = 0;
                    switchLanguage();
                    _hasJustUsedHotKey = true;
                    return NULL;
                }
                if (checkHotKey(convertToolHotKey, GET_SWITCH_KEY(convertToolHotKey) != 0xFE)) {
                    _lastFlag = 0;
                    [appDelegate onQuickConvert];
                    _hasJustUsedHotKey = true;
                    return NULL;
                }
                //check temporarily turn off spell checking
                if (vTempOffSpelling && !_hasJustUsedHotKey && _lastFlag & kCGEventFlagMaskControl) {
                    vTempOffSpellChecking();
                }
                if (vTempOffOpenKey && !_hasJustUsedHotKey && _lastFlag & kCGEventFlagMaskCommand) {
                    vTempOffEngine();
                }
                _lastFlag = 0;
                _hasJustUsedHotKey = false;
            }
        }

        // Also check correct event hooked
        if ((type != kCGEventKeyDown) && (type != kCGEventKeyUp) &&
            (type != kCGEventLeftMouseDown) && (type != kCGEventRightMouseDown))
            return event;
        
        _proxy = proxy;
        
        //If is in english mode
        if (vLanguage == 0) {
            if (vUseMacro && vUseMacroInEnglishMode && type == kCGEventKeyDown) {
                vEnglishMode((type == kCGEventKeyDown ? vKeyEventState::KeyDown : vKeyEventState::MouseDown),
                             _keycode,
                             (_flag & kCGEventFlagMaskShift) || (_flag & kCGEventFlagMaskAlphaShift),
                             OTHER_CONTROL_KEY);
                
                if (pData->code == vReplaceMaro) { //handle macro in english mode
                    handleMacro();
                    return NULL;
                }
            }
            return event;
        }
        
        //handle mouse
        if (type == kCGEventLeftMouseDown || type == kCGEventRightMouseDown) {
            RequestNewSession();
            return event;
        }

        //if "turn off Vietnamese when in other language" mode on (cached, see UpdateInputSourceCache)
        if (vOtherLanguage && !_isEnglishInputSource) {
            return event;
        }
        
        //handle keyboard
        if (type == kCGEventKeyDown) {
            //⌘/⌃ often moves focus without a click (⌘Space opens Spotlight);
            //a typing pause may mean a new field (⌥Space launchers): re-detect lazily
            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
            if ((_flag & (kCGEventFlagMaskCommand | kCGEventFlagMaskControl)) || now - _axLastKeyTime > 0.5) {
                AXInvalidateFocusCache();
            }
            _axLastKeyTime = now;
            //send event signal to Engine
            vKeyHandleEvent(vKeyEvent::Keyboard,
                            vKeyEventState::KeyDown,
                            _keycode,
                            _flag & kCGEventFlagMaskShift ? 1 : (_flag & kCGEventFlagMaskAlphaShift ? 2 : 0),
                            OTHER_CONTROL_KEY);
            if (pData->code == vDoNothing) { //do nothing
                if (IS_DOUBLE_CODE(vCodeTable)) { //VNI
                    if (pData->extCode == 1) { //break key
                        _syncKey.clear();
                    } else if (pData->extCode == 2) { //delete key
                        if (_syncKey.size() > 0) {
                            if (_syncKey.back() > 1 && (vCodeTable == 2 || !containUnicodeCompoundApp(targetApp))) {
                                //send one more backspace
                                PostBackspaceEvent();
                            }
                            _syncKey.pop_back();
                        }
                       
                    } else if (pData->extCode == 3) { //normal key
                        InsertKeyLength(1);
                    }
                }
                return event;
            } else if (pData->code == vWillProcess || pData->code == vRestore || pData->code == vRestoreAndStartNewSession) { //handle result signal

                //Spotlight/Alfred: atomic AX edit; falls through on failure
                if (AXSlowPathActive() && TryAXProcessKey()) {
                    return NULL;
                }

                //fix autocomplete
                if (shouldUseRecommendWorkaround(targetApp) && pData->extCode != 4) {
                    if (vFixChromiumBrowser && [_unicodeCompoundApp containsObject:targetApp]) {
                        if (pData->backspaceCount > 0) {
                            SendShiftAndLeftArrow();
                            if (pData->backspaceCount == 1)
                                pData->backspaceCount--;
                        }
                    } else {
                        SendEmptyCharacter();
                        pData->backspaceCount++;
                    }
                }
                
                //send backspace
                if (pData->backspaceCount > 0 && pData->backspaceCount < MAX_BUFF) {
                    for (_i = 0; _i < pData->backspaceCount; _i++) {
                        SendBackspace();
                    }
                }
                
                //send new character
                if (!vSendKeyStepByStep) {
                    SendNewCharString();
                } else {
                    if (pData->newCharCount > 0 && pData->newCharCount <= MAX_BUFF) {
                        for (int i = pData->newCharCount - 1; i >= 0; i--) {
                            SendKeyCode(pData->charData[i]);
                        }
                    }
                    if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
                        SendKeyCode(_keycode | ((_flag & kCGEventFlagMaskAlphaShift) || (_flag & kCGEventFlagMaskShift) ? CAPS_MASK : 0));
                    }
                    if (pData->code == vRestoreAndStartNewSession) {
                        startNewSession();
                    }
                }
            } else if (pData->code == vReplaceMaro) { //MACRO
                handleMacro();
            }
            
            return NULL;
        }
        
        return event;
    }
}
