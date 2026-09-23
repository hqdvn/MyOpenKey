//
//  OpenKeyBridge.m
//  MyOpenKey
//

#import "OpenKeyBridge.h"
#import "OpenKeyManager.h"
#import "AppDelegate.h"
#import <Carbon/Carbon.h>
#import <ServiceManagement/ServiceManagement.h>

extern AppDelegate* appDelegate;
extern void OnSpellCheckingChanged(void);
extern void OnTableCodeChange(void);
extern void OnInputMethodChanged(void);

extern int vFreeMark;
extern int vCheckSpelling;
extern int vUseModernOrthography;
extern int vSwitchKeyStatus;
extern int vQuickTelex;
extern int vRestoreIfWrongSpelling;
extern int vFixRecommendBrowser;
extern int vUseMacro;
extern int vUseMacroInEnglishMode;
extern int vSendKeyStepByStep;
extern int vUseSmartSwitchKey;
extern int vUpperCaseFirstChar;
extern int vTempOffSpelling;
extern int vAllowConsonantZFWJ;
extern int vQuickStartConsonant;
extern int vQuickEndConsonant;
extern int vRememberCode;
extern int vOtherLanguage;
extern int vTempOffOpenKey;
extern int vShowIconOnDock;
extern int vAutoCapsMacro;
extern int vFixChromiumBrowser;
extern int vPerformLayoutCompat;
extern int vLanguage;
extern int vInputType;
extern int vCodeTable;

NSString * const kOpenKeySettingsDidChangeNotification = @"OpenKeySettingsDidChangeNotification";

@implementation OpenKeyBridge

+ (instancetype)shared {
    static OpenKeyBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OpenKeyBridge alloc] init];
        [instance reloadFromUserDefaults];
    });
    return instance;
}

- (void)reloadFromUserDefaults {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    _inputMethod = [defs integerForKey:@"InputMethod"];
    _inputType = [defs integerForKey:@"InputType"];
    _codeTable = [defs integerForKey:@"CodeTable"];

    _switchKeyControl = (vSwitchKeyStatus & 0x100) != 0;
    _switchKeyOption  = (vSwitchKeyStatus & 0x200) != 0;
    _switchKeyCommand = (vSwitchKeyStatus & 0x400) != 0;
    _switchKeyShift   = (vSwitchKeyStatus & 0x800) != 0;
    _switchKeyBeep    = (vSwitchKeyStatus & 0x8000) != 0;

    unsigned char chr = (unsigned char)((vSwitchKeyStatus >> 24) & 0xFF);
    if (chr == kVK_Space) {
        _switchKeyChar = @"Space";
    } else if (chr == 0xFE || chr == 0) {
        _switchKeyChar = @"";
    } else {
        _switchKeyChar = [NSString stringWithFormat:@"%c", chr];
    }

    _modernOrthography = [defs integerForKey:@"ModernOrthography"] != 0;
    _spelling = [defs integerForKey:@"Spelling"] != 0;
    _restoreIfInvalidWord = [defs integerForKey:@"RestoreIfInvalidWord"] != 0;
    _allowConsonantZFWJ = [defs integerForKey:@"vAllowConsonantZFWJ"] != 0;
    _tempOffSpelling = [defs integerForKey:@"vTempOffSpelling"] != 0;
    _fixRecommendBrowser = [defs integerForKey:@"FixRecommendBrowser"] != 0;

    _smartSwitchKey = [defs integerForKey:@"UseSmartSwitchKey"] != 0;
    _rememberCode = [defs integerForKey:@"vRememberCode"] != 0;
    _tempOffOpenKey = [defs integerForKey:@"vTempOffOpenKey"] != 0;
    _upperCaseFirstChar = [defs integerForKey:@"UpperCaseFirstChar"] != 0;
    _otherLanguage = [defs integerForKey:@"vOtherLanguage"] != 0;

    _useMacro = [defs integerForKey:@"UseMacro"] != 0;
    _quickTelex = [defs integerForKey:@"QuickTelex"] != 0;
    _useMacroInEnglishMode = [defs integerForKey:@"UseMacroInEnglishMode"] != 0;
    _autoCapsMacro = [defs integerForKey:@"vAutoCapsMacro"] != 0;
    _quickStartConsonant = [defs integerForKey:@"vQuickStartConsonant"] != 0;
    _quickEndConsonant = [defs integerForKey:@"vQuickEndConsonant"] != 0;

    if (@available(macOS 13.0, *)) {
        _runOnStartup = [SMAppService mainAppService].status == SMAppServiceStatusEnabled;
    } else {
        _runOnStartup = [defs integerForKey:@"RunOnStartup"] != 0;
    }
    _showUIOnStartup = [defs integerForKey:@"ShowUIOnStartup"] != 0;
    _showIconOnDock = [defs integerForKey:@"vShowIconOnDock"] != 0;
    _grayIcon = [defs integerForKey:@"GrayIcon"] != 0;
    _sendKeyStepByStep = [defs integerForKey:@"SendKeyStepByStep"] != 0;
    _fixChromiumBrowser = [defs integerForKey:@"vFixChromiumBrowser"] != 0;
    _performLayoutCompat = [defs integerForKey:@"vPerformLayoutCompat"] != 0;
    _checkNewVersionOnStartup = [defs integerForKey:@"DontCheckUpdate"] == 0;

    [[NSNotificationCenter defaultCenter] postNotificationName:kOpenKeySettingsDidChangeNotification object:self];
}

#pragma mark - Setters & Sync

- (void)setInputMethod:(NSInteger)val {
    _inputMethod = val;
    vLanguage = (int)val;
    [[NSUserDefaults standardUserDefaults] setInteger:val forKey:@"InputMethod"];
    if (vSwitchKeyStatus & 0x8000) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSSound soundNamed:@"Tink"] play];
        });
    }
    [appDelegate fillData];
    OnInputMethodChanged();
}

- (void)setInputType:(NSInteger)val {
    _inputType = val;
    vInputType = (int)val;
    [[NSUserDefaults standardUserDefaults] setInteger:val forKey:@"InputType"];
    [appDelegate onInputTypeSelectedIndex:(int)val];
}

- (void)setCodeTable:(NSInteger)val {
    _codeTable = val;
    vCodeTable = (int)val;
    [[NSUserDefaults standardUserDefaults] setInteger:val forKey:@"CodeTable"];
    [appDelegate onCodeTableChanged:(int)val];
}

- (NSArray<NSString *> *)availableSwitchKeyPresets {
    return @[
        @"⌥ Option + Z",
        @"⌃ Control + ⇧ Shift",
        @"⌘ Command +  Shift",
        @" Control + Space",
        @"Nhấn phím ⌥ Option",
        @"Nhấn phím ⌃ Control",
        @"🌐 Fn (Globe)"
    ];
}

- (NSArray<NSString *> *)excludedApps {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:@"excludedApps"] ?: @[];
}

- (void)addExcludedApp:(NSString *)bundleId {
    if (!bundleId) return;
    NSMutableArray *list = [NSMutableArray arrayWithArray:[self excludedApps]];
    if (![list containsObject:bundleId]) {
        [list addObject:bundleId];
        [[NSUserDefaults standardUserDefaults] setObject:list forKey:@"excludedApps"];
    }
}

- (void)removeExcludedApp:(NSString *)bundleId {
    NSMutableArray *list = [NSMutableArray arrayWithArray:[self excludedApps]];
    [list removeObject:bundleId];
    [[NSUserDefaults standardUserDefaults] setObject:list forKey:@"excludedApps"];
}

- (NSString *)displayNameForBundleId:(NSString *)bundleId {
    NSURL *url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:bundleId];
    if (url) {
        NSDictionary *info = [NSBundle bundleWithURL:url].infoDictionary;
        NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"];
        if (name.length) return name;
    }
    return bundleId;
}

- (NSInteger)switchKeyPreset {
    unsigned int raw = (unsigned int)(vSwitchKeyStatus & (~0x8000));
    switch (raw) {
        case 0x7A000206: return 0; // Option + Z
        case 0xFE0009FE: return 1; // Control + Shift
        case 0xFE000CFE: return 2; // Command + Shift
        case 0x31000131: return 3; // Control + Space
        case 0xFE0002FE: return 4; // Option alone
        case 0xFE0001FE: return 5; // Control alone
        case 0xFE0010FE: return 6; // Fn (Globe) alone
        default: return 0;
    }
}

- (void)setSwitchKeyPreset:(NSInteger)preset {
    unsigned int beepBit = (vSwitchKeyStatus & 0x8000);
    unsigned int newStatus = 0x7A000206; // default Option + Z
    switch (preset) {
        case 0: newStatus = 0x7A000206; break; // Option + Z
        case 1: newStatus = 0xFE0009FE; break; // Control + Shift
        case 2: newStatus = 0xFE000CFE; break; // Command + Shift
        case 3: newStatus = 0x31000131; break; // Control + Space
        case 4: newStatus = 0xFE0002FE; break; // Option alone
        case 5: newStatus = 0xFE0001FE; break; // Control alone
        case 6: newStatus = 0xFE0010FE; break; // Fn (Globe) alone
        default: newStatus = 0x7A000206; break;
    }
    vSwitchKeyStatus = (int)(newStatus | beepBit);
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
    [self reloadFromUserDefaults];
}
- (void)setSwitchKeyControl:(BOOL)val {
    _switchKeyControl = val;
    vSwitchKeyStatus &= (~0x100);
    vSwitchKeyStatus |= (val ? 1 : 0) << 8;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (void)setSwitchKeyOption:(BOOL)val {
    _switchKeyOption = val;
    vSwitchKeyStatus &= (~0x200);
    vSwitchKeyStatus |= (val ? 1 : 0) << 9;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (void)setSwitchKeyCommand:(BOOL)val {
    _switchKeyCommand = val;
    vSwitchKeyStatus &= (~0x400);
    vSwitchKeyStatus |= (val ? 1 : 0) << 10;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (void)setSwitchKeyShift:(BOOL)val {
    _switchKeyShift = val;
    vSwitchKeyStatus &= (~0x800);
    vSwitchKeyStatus |= (val ? 1 : 0) << 11;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (void)setSwitchKeyBeep:(BOOL)val {
    _switchKeyBeep = val;
    vSwitchKeyStatus &= (~0x8000);
    vSwitchKeyStatus |= (val ? 1 : 0) << 15;
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
    if (val) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSSound soundNamed:@"Tink"] play];
        });
    }
}

- (void)setSwitchKeyChar:(NSString *)val {
    _switchKeyChar = [val copy];
    unsigned short keyCode = 0;
    unsigned short character = 0;
    if ([val isEqualToString:@"Space"]) {
        keyCode = kVK_Space;
        character = kVK_Space;
    } else if (val.length > 0) {
        character = [val characterAtIndex:0];
        // default letter keyCode fallback
        keyCode = kVK_ANSI_Z;
    } else {
        keyCode = 0xFE;
        character = 0xFE;
    }
    vSwitchKeyStatus &= 0xFFFFFF00;
    vSwitchKeyStatus |= keyCode;
    vSwitchKeyStatus &= 0x00FFFFFF;
    vSwitchKeyStatus |= ((unsigned int)character << 24);
    [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus forKey:@"SwitchKeyStatus"];
}

- (void)setModernOrthography:(BOOL)val {
    _modernOrthography = val;
    vUseModernOrthography = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vUseModernOrthography forKey:@"ModernOrthography"];
}

- (void)setSpelling:(BOOL)val {
    _spelling = val;
    vCheckSpelling = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vCheckSpelling forKey:@"Spelling"];
    OnSpellCheckingChanged();
}

- (void)setRestoreIfInvalidWord:(BOOL)val {
    _restoreIfInvalidWord = val;
    vRestoreIfWrongSpelling = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vRestoreIfWrongSpelling forKey:@"RestoreIfInvalidWord"];
}

- (void)setAllowConsonantZFWJ:(BOOL)val {
    _allowConsonantZFWJ = val;
    vAllowConsonantZFWJ = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vAllowConsonantZFWJ forKey:@"vAllowConsonantZFWJ"];
}

- (void)setTempOffSpelling:(BOOL)val {
    _tempOffSpelling = val;
    vTempOffSpelling = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vTempOffSpelling forKey:@"vTempOffSpelling"];
}

- (void)setFixRecommendBrowser:(BOOL)val {
    _fixRecommendBrowser = val;
    vFixRecommendBrowser = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vFixRecommendBrowser forKey:@"FixRecommendBrowser"];
}

- (void)setSmartSwitchKey:(BOOL)val {
    _smartSwitchKey = val;
    vUseSmartSwitchKey = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vUseSmartSwitchKey forKey:@"UseSmartSwitchKey"];
}

- (void)setRememberCode:(BOOL)val {
    _rememberCode = val;
    vRememberCode = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vRememberCode forKey:@"vRememberCode"];
}

- (void)setTempOffOpenKey:(BOOL)val {
    _tempOffOpenKey = val;
    vTempOffOpenKey = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vTempOffOpenKey forKey:@"vTempOffOpenKey"];
}

- (void)setUpperCaseFirstChar:(BOOL)val {
    _upperCaseFirstChar = val;
    vUpperCaseFirstChar = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vUpperCaseFirstChar forKey:@"UpperCaseFirstChar"];
}

- (void)setOtherLanguage:(BOOL)val {
    _otherLanguage = val;
    vOtherLanguage = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vOtherLanguage forKey:@"vOtherLanguage"];
}

- (void)setUseMacro:(BOOL)val {
    _useMacro = val;
    vUseMacro = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vUseMacro forKey:@"UseMacro"];
}

- (void)setQuickTelex:(BOOL)val {
    _quickTelex = val;
    vQuickTelex = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vQuickTelex forKey:@"QuickTelex"];
}

- (void)setUseMacroInEnglishMode:(BOOL)val {
    _useMacroInEnglishMode = val;
    vUseMacroInEnglishMode = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vUseMacroInEnglishMode forKey:@"UseMacroInEnglishMode"];
}

- (void)setAutoCapsMacro:(BOOL)val {
    _autoCapsMacro = val;
    vAutoCapsMacro = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vAutoCapsMacro forKey:@"vAutoCapsMacro"];
}

- (void)setQuickStartConsonant:(BOOL)val {
    _quickStartConsonant = val;
    vQuickStartConsonant = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vQuickStartConsonant forKey:@"vQuickStartConsonant"];
}

- (void)setQuickEndConsonant:(BOOL)val {
    _quickEndConsonant = val;
    vQuickEndConsonant = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vQuickEndConsonant forKey:@"vQuickEndConsonant"];
}

- (void)setRunOnStartup:(BOOL)val {
    _runOnStartup = val;
    [[NSUserDefaults standardUserDefaults] setInteger:(val ? 1 : 0) forKey:@"RunOnStartup"];
    [appDelegate setRunOnStartup:val];
}

- (void)setShowUIOnStartup:(BOOL)val {
    _showUIOnStartup = val;
    [[NSUserDefaults standardUserDefaults] setInteger:(val ? 1 : 0) forKey:@"ShowUIOnStartup"];
}

- (void)setShowIconOnDock:(BOOL)val {
    _showIconOnDock = val;
    vShowIconOnDock = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vShowIconOnDock forKey:@"vShowIconOnDock"];
    [appDelegate showIconOnDock:val];
}

- (void)setGrayIcon:(BOOL)val {
    _grayIcon = val;
    [[NSUserDefaults standardUserDefaults] setInteger:(val ? 1 : 0) forKey:@"GrayIcon"];
    [appDelegate setGrayIcon:val];
}

- (void)setSendKeyStepByStep:(BOOL)val {
    _sendKeyStepByStep = val;
    vSendKeyStepByStep = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vSendKeyStepByStep forKey:@"SendKeyStepByStep"];
}

- (void)setFixChromiumBrowser:(BOOL)val {
    _fixChromiumBrowser = val;
    vFixChromiumBrowser = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vFixChromiumBrowser forKey:@"vFixChromiumBrowser"];
}

- (void)setPerformLayoutCompat:(BOOL)val {
    _performLayoutCompat = val;
    vPerformLayoutCompat = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vPerformLayoutCompat forKey:@"vPerformLayoutCompat"];
}

- (void)setCheckNewVersionOnStartup:(BOOL)val {
    _checkNewVersionOnStartup = val;
    [[NSUserDefaults standardUserDefaults] setInteger:(val ? 0 : 1) forKey:@"DontCheckUpdate"];
}

#pragma mark - Lists & Metadata

- (NSArray<NSString *> *)availableInputTypes {
    return @[@"Telex", @"VNI", @"Simple Telex 1", @"Simple Telex 2"];
}

- (NSArray<NSString *> *)availableCodeTables {
    return [OpenKeyManager getTableCodes];
}

- (NSString *)appVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.1.00";
}

- (NSString *)appBuild {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"1";
}

- (NSString *)buildDate {
    return [OpenKeyManager getBuildDate] ?: @"";
}

#pragma mark - Actions

- (void)resetToDefaults {
    [appDelegate loadDefaultConfig];
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"ShowUIOnStartup"];
    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"RunOnStartup"];
    [self reloadFromUserDefaults];
}

- (void)openMacroWindow {
    [appDelegate onMacroSelected];
}

- (void)checkNewVersion:(nullable NSWindow *)window callback:(void(^)(void))callback {
    [OpenKeyManager checkNewVersion:window callbackFunc:callback];
}

@end
