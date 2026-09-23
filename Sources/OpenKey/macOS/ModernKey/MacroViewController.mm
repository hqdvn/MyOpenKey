//
//  MacroViewController.mm
//  MyOpenKey
//
//  Created by Tuyen on 8/4/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//  Modified 2026 by Huỳnh Quốc Đạt for MyOpenKey (GPLv3).
//

#import "MacroViewController.h"
#import "MyOpenKey-Swift.h"
#include "Engine.h"

extern int vAutoCapsMacro;

@implementation MacroItem

+ (instancetype)itemWithShortcut:(NSString *)shortcut content:(NSString *)content {
    MacroItem *item = [[MacroItem alloc] init];
    item.shortcut = shortcut;
    item.content = content;
    return item;
}

@end

@implementation MacroBridge

+ (instancetype)shared {
    static MacroBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MacroBridge alloc] init];
    });
    return instance;
}

- (NSArray<MacroItem *> *)allMacros {
    vector<vector<Uint32>> keys;
    vector<string> macroText;
    vector<string> macroContent;
    getAllMacro(keys, macroText, macroContent);

    NSMutableArray<MacroItem *> *items = [NSMutableArray arrayWithCapacity:macroText.size()];
    for (size_t i = 0; i < macroText.size(); i++) {
        NSString *shortcut = [NSString stringWithUTF8String:macroText[i].c_str()];
        NSString *content = [NSString stringWithUTF8String:macroContent[i].c_str()];
        if (shortcut && content) {
            [items addObject:[MacroItem itemWithShortcut:shortcut content:content]];
        }
    }
    return items;
}

- (void)saveMacroData {
    vector<Byte> macroData;
    getMacroSaveData(macroData);
    NSData* data = [NSData dataWithBytes:macroData.data() length:macroData.size()];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"macroData"];
}

- (BOOL)addOrUpdateMacro:(NSString *)shortcut content:(NSString *)content {
    if (shortcut.length == 0 || content.length == 0) return NO;
    string s = [shortcut UTF8String];
    string c = [content UTF8String];
    addMacro(s, c);
    [self saveMacroData];
    return YES;
}

- (BOOL)deleteMacro:(NSString *)shortcut {
    if (shortcut.length == 0) return NO;
    string s = [shortcut UTF8String];
    if (deleteMacro(s)) {
        [self saveMacroData];
        return YES;
    }
    return NO;
}

- (BOOL)loadFromFile:(NSString *)path keepCurrent:(BOOL)keepCurrent {
    if (!path) return NO;
    readFromFile(path.UTF8String, keepCurrent);
    [self saveMacroData];
    return YES;
}

- (BOOL)exportToFile:(NSString *)path {
    if (!path) return NO;
    saveToFile(path.UTF8String);
    return YES;
}

- (BOOL)autoCapsMacro {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"vAutoCapsMacro"] != 0;
}

- (void)setAutoCapsMacro:(BOOL)val {
    vAutoCapsMacro = val ? 1 : 0;
    [[NSUserDefaults standardUserDefaults] setInteger:vAutoCapsMacro forKey:@"vAutoCapsMacro"];
}

@end

@implementation MacroViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    for (NSView *subview in [self.view.subviews copy]) {
        [subview removeFromSuperview];
    }

    NSViewController *modernMacroVC = [ModernMacroPanel createViewController];
    [self addChildViewController:modernMacroVC];
    modernMacroVC.view.frame = self.view.bounds;
    modernMacroVC.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.view addSubview:modernMacroVC.view];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    self.view.window.title = @"Thiết lập gõ tắt";
    [self.view.window setContentSize:NSMakeSize(620, 540)];
}

@end
