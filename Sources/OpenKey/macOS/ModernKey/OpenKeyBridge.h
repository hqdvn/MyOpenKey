//
//  OpenKeyBridge.h
//  MyOpenKey
//
//  Bridge between C++/Objective-C OpenKey engine and modern SwiftUI settings.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kOpenKeySettingsDidChangeNotification;

@interface OpenKeyBridge : NSObject

+ (instancetype)shared;

// Core Input
@property (nonatomic, assign) NSInteger inputMethod; // 1: Tiếng Việt, 0: English
@property (nonatomic, assign) NSInteger inputType;   // 0: Telex, 1: VNI, 2: Simple Telex 1, 3: Simple Telex 2
@property (nonatomic, assign) NSInteger codeTable;   // Index in getTableCodes
@property (nonatomic, readonly) NSArray<NSString *> *availableCodeTables;
@property (nonatomic, readonly) NSArray<NSString *> *availableInputTypes;

// Switch key configuration & presets
@property (nonatomic, assign) NSInteger switchKeyPreset;
@property (nonatomic, readonly) NSArray<NSString *> *availableSwitchKeyPresets;
@property (nonatomic, readonly) NSArray<NSString *> *excludedApps;
- (void)addExcludedApp:(NSString *)bundleId;
- (void)removeExcludedApp:(NSString *)bundleId;
- (NSString *)displayNameForBundleId:(NSString *)bundleId;
@property (nonatomic, assign) BOOL switchKeyControl;
@property (nonatomic, assign) BOOL switchKeyOption;
@property (nonatomic, assign) BOOL switchKeyCommand;
@property (nonatomic, assign) BOOL switchKeyShift;
@property (nonatomic, assign) BOOL switchKeyBeep;
@property (nonatomic, copy) NSString *switchKeyChar;
// Spelling & Orthography
@property (nonatomic, assign) BOOL modernOrthography;
@property (nonatomic, assign) BOOL spelling;
@property (nonatomic, assign) BOOL restoreIfInvalidWord;
@property (nonatomic, assign) BOOL allowConsonantZFWJ;
@property (nonatomic, assign) BOOL tempOffSpelling;
@property (nonatomic, assign) BOOL fixRecommendBrowser;

// Typing Utilities
@property (nonatomic, assign) BOOL smartSwitchKey;
@property (nonatomic, assign) BOOL rememberCode;
@property (nonatomic, assign) BOOL tempOffOpenKey;
@property (nonatomic, assign) BOOL upperCaseFirstChar;
@property (nonatomic, assign) BOOL otherLanguage;

// Macro
@property (nonatomic, assign) BOOL useMacro;
@property (nonatomic, assign) BOOL quickTelex;
@property (nonatomic, assign) BOOL useMacroInEnglishMode;
@property (nonatomic, assign) BOOL autoCapsMacro;
@property (nonatomic, assign) BOOL quickStartConsonant;
@property (nonatomic, assign) BOOL quickEndConsonant;

// System & Compatibility
@property (nonatomic, assign) BOOL runOnStartup;
@property (nonatomic, assign) BOOL showUIOnStartup;
@property (nonatomic, assign) BOOL showIconOnDock;
@property (nonatomic, assign) BOOL grayIcon;
@property (nonatomic, assign) BOOL sendKeyStepByStep;
@property (nonatomic, assign) BOOL fixChromiumBrowser;
@property (nonatomic, assign) BOOL performLayoutCompat;
@property (nonatomic, assign) BOOL checkNewVersionOnStartup;

// Metadata
@property (nonatomic, readonly) NSString *appVersion;
@property (nonatomic, readonly) NSString *appBuild;
@property (nonatomic, readonly) NSString *buildDate;

// Actions
- (void)reloadFromUserDefaults;
- (void)resetToDefaults;
- (void)openMacroWindow;
- (void)checkNewVersion:(nullable NSWindow *)window callback:(void(^)(void))callback;

@end

NS_ASSUME_NONNULL_END
