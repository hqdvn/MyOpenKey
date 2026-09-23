//
//  MacroViewController.h
//  OpenKey
//
//  Created by Tuyen on 8/4/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@interface MacroItem : NSObject
@property (nonatomic, copy) NSString *shortcut;
@property (nonatomic, copy) NSString *content;
+ (instancetype)itemWithShortcut:(NSString *)shortcut content:(NSString *)content;
@end

@interface MacroBridge : NSObject
+ (instancetype)shared;
- (NSArray<MacroItem *> *)allMacros;
- (BOOL)addOrUpdateMacro:(NSString *)shortcut content:(NSString *)content;
- (BOOL)deleteMacro:(NSString *)shortcut;
- (BOOL)loadFromFile:(NSString *)path keepCurrent:(BOOL)keepCurrent;
- (BOOL)exportToFile:(NSString *)path;
@property (nonatomic, assign) BOOL autoCapsMacro;
@end

@interface MacroViewController : NSViewController
@end

NS_ASSUME_NONNULL_END
