//
//  ConvertToolViewController.mm
//  MyOpenKey
//
//  Created by Tuyen on 9/4/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//  Modified 2026 by Huỳnh Quốc Đạt for MyOpenKey (GPLv3).
//

#import "ConvertToolViewController.h"
#import "MyOpenKey-Swift.h"
#import "AppDelegate.h"
#import "OpenKeyManager.h"
#include "ConvertTool.h"

extern AppDelegate* appDelegate;

@implementation ConvertToolBridge

+ (instancetype)shared {
    static ConvertToolBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ConvertToolBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        _fromCode = [defs integerForKey:@"convertToolFromCode"];
        _toCode = [defs integerForKey:@"convertToolToCode"];
        _removeMark = [defs integerForKey:@"convertToolRemoveMark"] != 0;
        _alertWhenCompleted = ![defs boolForKey:@"convertToolDontAlertWhenCompleted"];

        if ([defs integerForKey:@"convertToolToAllCaps"]) {
            _caseOption = 1;
        } else if ([defs integerForKey:@"convertToolToAllNonCaps"]) {
            _caseOption = 2;
        } else if ([defs integerForKey:@"convertToolToCapsFirstLetter"]) {
            _caseOption = 3;
        } else if ([defs integerForKey:@"convertToolToCapsEachWord"]) {
            _caseOption = 4;
        } else {
            _caseOption = 0;
        }
    }
    return self;
}

- (NSArray<NSString *> *)availableCodeTables {
    return [OpenKeyManager getTableCodes];
}

- (void)setFromCode:(NSInteger)fromCode {
    _fromCode = fromCode;
    convertToolFromCode = (Uint8)fromCode;
    [[NSUserDefaults standardUserDefaults] setInteger:fromCode forKey:@"convertToolFromCode"];
}

- (void)setToCode:(NSInteger)toCode {
    _toCode = toCode;
    convertToolToCode = (Uint8)toCode;
    [[NSUserDefaults standardUserDefaults] setInteger:toCode forKey:@"convertToolToCode"];
}

- (void)reverseCodes {
    NSInteger temp = self.fromCode;
    self.fromCode = self.toCode;
    self.toCode = temp;
}

- (void)setCaseOption:(NSInteger)option {
    _caseOption = option;
    convertToolToAllCaps = (option == 1);
    convertToolToAllNonCaps = (option == 2);
    convertToolToCapsFirstLetter = (option == 3);
    convertToolToCapsEachWord = (option == 4);

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setInteger:convertToolToAllCaps forKey:@"convertToolToAllCaps"];
    [defs setInteger:convertToolToAllNonCaps forKey:@"convertToolToAllNonCaps"];
    [defs setInteger:convertToolToCapsFirstLetter forKey:@"convertToolToCapsFirstLetter"];
    [defs setInteger:convertToolToCapsEachWord forKey:@"convertToolToCapsEachWord"];
}

- (void)setRemoveMark:(BOOL)removeMark {
    _removeMark = removeMark;
    convertToolRemoveMark = removeMark;
    [[NSUserDefaults standardUserDefaults] setInteger:removeMark ? 1 : 0 forKey:@"convertToolRemoveMark"];
}

- (void)setAlertWhenCompleted:(BOOL)alertWhenCompleted {
    _alertWhenCompleted = alertWhenCompleted;
    convertToolDontAlertWhenCompleted = !alertWhenCompleted;
    [[NSUserDefaults standardUserDefaults] setBool:!alertWhenCompleted forKey:@"convertToolDontAlertWhenCompleted"];
}

- (NSArray<NSString *> *)availableHotKeyPresets {
    return @[
        @"⌃ Control + ⌥ Option + C",
        @"⌥ Option + ⌘ Command + C",
        @"⌃ Control + ⇧ Shift + C",
        @"⌃ Control + ⌘ Command + C",
        @"Không dùng phím tắt"
    ];
}

- (NSInteger)hotKeyPreset {
    unsigned int raw = (unsigned int)(convertToolHotKey & (~0x8000));
    switch (raw) {
        case 0x63000308: return 0; // Ctrl + Opt + C
        case 0x63000608: return 1; // Opt + Cmd + C
        case 0x63000908: return 2; // Ctrl + Shift + C
        case 0x63000508: return 3; // Ctrl + Cmd + C
        case 0xFE0000FE: return 4; // Disabled
        default: return 0;
    }
}

- (void)setHotKeyPreset:(NSInteger)preset {
    unsigned int newHotKey = 0x63000308; // default Ctrl + Opt + C
    switch (preset) {
        case 0: newHotKey = 0x63000308; break; // Ctrl + Opt + C
        case 1: newHotKey = 0x63000608; break; // Opt + Cmd + C
        case 2: newHotKey = 0x63000908; break; // Ctrl + Shift + C
        case 3: newHotKey = 0x63000508; break; // Ctrl + Cmd + C
        case 4: newHotKey = 0xFE0000FE; break; // Disabled
        default: newHotKey = 0x63000308; break;
    }
    convertToolHotKey = (int)newHotKey;
    [[NSUserDefaults standardUserDefaults] setInteger:convertToolHotKey forKey:@"convertToolHotKey"];
    [appDelegate setQuickConvertString];
}

- (BOOL)convertClipboard:(nullable NSWindow *)window {
    if ([OpenKeyManager quickConvert]) {
        if (self.alertWhenCompleted) {
            [OpenKeyManager showMessage:window message:@"Chuyển mã thành công!" subMsg:@"Kết quả đã được lưu trong clipboard."];
        }
        return YES;
    } else {
        [OpenKeyManager showMessage:window message:@"Không có dữ liệu trong clipboard!" subMsg:@"Hãy sao chép một đoạn văn bản trước khi chuyển mã."];
        return NO;
    }
}

@end

@implementation ConvertToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    for (NSView *subview in [self.view.subviews copy]) {
        [subview removeFromSuperview];
    }

    NSViewController *modernConvertVC = [ModernConvertPanel createViewController];
    [self addChildViewController:modernConvertVC];
    modernConvertVC.view.frame = self.view.bounds;
    modernConvertVC.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.view addSubview:modernConvertVC.view];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    self.view.window.title = @"Công cụ chuyển mã";
    [self.view.window setContentSize:NSMakeSize(580, 570)];
}

@end
