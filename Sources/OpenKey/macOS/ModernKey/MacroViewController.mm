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
#include <fstream>

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
    const char *sUtf8 = [shortcut UTF8String];
    const char *cUtf8 = [content UTF8String];
    if (!sUtf8 || !cUtf8) return NO;
    string s = sUtf8;
    string c = cUtf8;
    addMacro(s, c);
    [self saveMacroData];
    return YES;
}

- (BOOL)deleteMacro:(NSString *)shortcut {
    if (shortcut.length == 0) return NO;
    const char *sUtf8 = [shortcut UTF8String];
    if (!sUtf8) return NO;
    string s = sUtf8;
    if (deleteMacro(s)) {
        [self saveMacroData];
        return YES;
    }
    return NO;
}

- (BOOL)loadFromFile:(NSString *)path keepCurrent:(BOOL)keepCurrent {
    if (!path) return NO;
    const char *pUtf8 = path.UTF8String;
    if (!pUtf8) return NO;

    // Validate file and count valid macro entries before touching macroMap
    std::ifstream checkFile(pUtf8);
    if (!checkFile.is_open()) return NO;
    std::string line;
    int lineCount = 0;
    int validEntries = 0;
    while (std::getline(checkFile, line)) {
        lineCount++;
        if (lineCount == 1) continue;
        size_t pos = line.find(":");
        if (pos != std::string::npos) {
            std::string name = line.substr(0, pos);
            std::string content = line.substr(pos + 1);
            while (name.empty() && !content.empty()) {
                pos = content.find(":");
                if (pos != std::string::npos) {
                    name += ":";
                    name += content.substr(0, pos);
                    content = content.substr(pos + 1);
                } else {
                    break;
                }
            }
            if (!name.empty()) {
                validEntries++;
            }
        }
    }
    checkFile.close();

    if (validEntries == 0) {
        return NO;
    }

    // Backup current macros
    vector<Byte> backupData;
    getMacroSaveData(backupData);

    readFromFile(pUtf8, keepCurrent);

    // Verify macro map
    vector<vector<Uint32>> keys;
    vector<string> macroText;
    vector<string> macroContent;
    getAllMacro(keys, macroText, macroContent);
    if (macroText.empty() && !backupData.empty()) {
        initMacroMap(backupData.data(), (int)backupData.size());
        return NO;
    }

    [self saveMacroData];
    return YES;
}

- (BOOL)exportToFile:(NSString *)path {
    if (!path) return NO;
    const char *pUtf8 = path.UTF8String;
    if (!pUtf8) return NO;
    saveToFile(pUtf8);

    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (!attrs || [attrs fileSize] == 0) {
        return NO;
    }
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
