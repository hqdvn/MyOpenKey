//
//  ConvertToolViewController.h
//  MyOpenKey
//
//  Created by Tuyen on 9/4/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//  Modified 2026 by Huỳnh Quốc Đạt for MyOpenKey (GPLv3).
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConvertToolBridge : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) NSInteger fromCode;
@property (nonatomic, assign) NSInteger toCode;
@property (nonatomic, readonly) NSArray<NSString *> *availableCodeTables;

@property (nonatomic, assign) NSInteger caseOption; // 0: Giữ nguyên, 1: SANG CHỮ HOA, 2: sang chữ thường, 3: Viết hoa chữ cái đầu câu, 4: Viết Hoa Mỗi Từ
@property (nonatomic, assign) BOOL removeMark;
@property (nonatomic, assign) BOOL alertWhenCompleted;

@property (nonatomic, assign) NSInteger hotKeyPreset;
@property (nonatomic, readonly) NSArray<NSString *> *availableHotKeyPresets;

- (void)reverseCodes;
- (BOOL)convertClipboard:(nullable NSWindow *)window;

@end

@interface ConvertToolViewController : NSViewController
@end

NS_ASSUME_NONNULL_END
