//
//  ViewController.h
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//  Modified 2026 by Huỳnh Quốc Đạt for MyOpenKey (GPLv3).
//

#import <Cocoa/Cocoa.h>
#import "MyTextField.h"

@interface ViewController : NSViewController<MyTextFieldDelegate>
@property (strong) IBOutlet NSView *viewParent;
@property (weak) IBOutlet NSSegmentedControl *tabSegment;
@property (weak) IBOutlet NSBox *tabviewPrimary;
@property (weak) IBOutlet NSBox *tabviewMacro;
@property (weak) IBOutlet NSBox *tabviewSystem;
@property (weak) IBOutlet NSBox *tabviewInfo;

@property (weak) IBOutlet NSPopUpButton *popupInputType;
@property (weak) IBOutlet NSPopUpButton *popupCode;

@property (weak) IBOutlet NSBox *appOK;
@property (weak) IBOutlet NSBox *permissionWarning;
@property (weak) IBOutlet NSButton *retryButton;

@property (weak) IBOutlet NSButton *VietButton;
@property (weak) IBOutlet NSButton *EngButton;

@property (weak) IBOutlet NSButton *FreeMarkButton;
@property (weak) IBOutlet NSSwitch *UseModernOrthography;

@property (weak) IBOutlet NSSwitch *CheckSpellingButton;

@property (weak) IBOutlet NSSwitch *RunOnStartupButton;
@property (weak) IBOutlet NSSwitch *ShowUIButton;

@property (weak) IBOutlet NSSwitch *UseGrayIcon;
@property (weak) IBOutlet NSSwitch *QuickTelex;

@property (weak) IBOutlet NSSwitch *RestoreIfInvalidWord;
@property (weak) IBOutlet NSSwitch *FixRecommendBrowser;
@property (weak) IBOutlet NSSwitch *AllowZWJF;
@property (weak) IBOutlet NSSwitch *TempOffSpellChecking;

@property (weak) IBOutlet NSSwitch *UseMacro;
@property (weak) IBOutlet NSSwitch *UseMacroInEnglishMode;

@property (weak) IBOutlet NSSwitch *SendKeyStepByStep;
@property (weak) IBOutlet NSSwitch *AutoRememberSwitchKey;
@property (weak) IBOutlet NSSwitch *UpperCaseFirstChar;
@property (weak) IBOutlet NSSwitch *QuickStartConsonant;
@property (weak) IBOutlet NSSwitch *QuickEndConsonant;

@property (weak) IBOutlet NSSwitch *RememberTableCode;
@property (weak) IBOutlet NSSwitch *OtherLanguage;

@property (weak) IBOutlet NSSwitch *TempOffOpenKey;
@property (weak) IBOutlet NSSwitch *AutoCapsMacro;
@property (weak) IBOutlet NSSwitch *ShowIconOnDock;
@property (weak) IBOutlet NSSwitch *CheckNewVersionOnStartup;
@property (weak) IBOutlet NSSwitch *FixChromiumBrowser;
@property (weak) IBOutlet NSSwitch *PerformLayoutCompat;

@property (weak) IBOutlet NSButton *CheckNewVersionButton;
@property (weak) IBOutlet NSTextField *VersionInfo;

@property (weak) IBOutlet NSImageView *cursorImage;

-(void)fillData;
@end

