//
//  OpenKeyManager.m
//  OpenKey
//
//  Created by Tuyen on 1/27/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//  Modified 2026 by Huỳnh Quốc Đạt for MyOpenKey (GPLv3).
//

#import "OpenKeyManager.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

extern void OpenKeyInit(void);

extern CGEventRef OpenKeyCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern NSString* ConvertUtil(NSString* str);

@interface OpenKeyManager ()

@end

@implementation OpenKeyManager {

}
static BOOL _isInited = NO;

CFMachPortRef      eventTap;
static CGEventMask        eventMask;
static CFRunLoopSourceRef runLoopSource;
static dispatch_source_t  tapWatchdog;
static id                 wakeObserver, sessionObserver;

static void reviveEventTap(void) {
    if (eventTap && !CGEventTapIsEnabled(eventTap)) {
        CGEventTapEnable(eventTap, true);
    }
}

+(BOOL)isInited {
    return _isInited;
}

+(BOOL)initEventTap {
    if (_isInited)
        return true;
    
    //init modernKey
    OpenKeyInit();
    
    // Create an event tap. We are interested in key presses.
    eventMask = ((1 << kCGEventKeyDown) |
                 (1 << kCGEventKeyUp) |
                 (1 << kCGEventFlagsChanged) |
                 (1 << kCGEventLeftMouseDown) |
                 (1 << kCGEventRightMouseDown));
    
    eventTap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                0,
                                eventMask,
                                OpenKeyCallback,
                                NULL);
    
    if (!eventTap) {
        
        fprintf(stderr, "failed to create event tap\n");
        return NO;
    }
    
    _isInited = YES;
    
    // Create a run loop source.
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    
    // Add to the current run loop.
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
    // Enable the event tap.
    CGEventTapEnable(eventTap, true);
    
    // Callback revives the tap on timeout/user-input disable. Sleep/wake and
    // session switches can kill it silently: revive on those notifications,
    // plus a slow watchdog as last-resort fallback (5s keeps CPU idle).
    NSNotificationCenter* wsCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
    wakeObserver = [wsCenter addObserverForName:NSWorkspaceDidWakeNotification object:nil
                                          queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification* n) { reviveEventTap(); }];
    sessionObserver = [wsCenter addObserverForName:NSWorkspaceSessionDidBecomeActiveNotification object:nil
                                             queue:[NSOperationQueue mainQueue]
                                        usingBlock:^(NSNotification* n) { reviveEventTap(); }];
    tapWatchdog = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(tapWatchdog, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), 5 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(tapWatchdog, ^{ reviveEventTap(); });
    dispatch_resume(tapWatchdog);
    
    return YES;
}
+(BOOL)stopEventTap {
    if (_isInited) { //release all object
        if (tapWatchdog) {
            dispatch_source_cancel(tapWatchdog);
            tapWatchdog = nil;
        }
        NSNotificationCenter* wsCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
        if (wakeObserver) { [wsCenter removeObserver:wakeObserver]; wakeObserver = nil; }
        if (sessionObserver) { [wsCenter removeObserver:sessionObserver]; sessionObserver = nil; }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        runLoopSource = nil;
        
        CFMachPortInvalidate(eventTap);
        CFRelease(eventTap);
        eventTap = nil;
        
        _isInited = false;
    }
    return YES;
}

+(NSArray*)getTableCodes {
    return [[NSArray alloc] initWithObjects:
            @"Unicode",
            @"TCVN3 (ABC)",
            @"VNI Windows",
            @"Unicode tổ hợp",
            @"Vietnamese Locale CP 1258", nil];
}

+(NSString*)getBuildDate {
    return [NSString stringWithUTF8String:__DATE__];
}

#pragma mark -Convert feature
+(BOOL)quickConvert {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray<NSPasteboardType> *types = pasteboard.types;
    if (types == nil || types.count == 0) {
        [self showMessage:nil message:@"Không có dữ liệu trong clipboard!" subMsg:@"Hãy sao chép một đoạn văn bản để chuyển đổi."];
        return NO;
    }

    NSSet<NSString *> *allowedTypes = [NSSet setWithObjects:
        NSPasteboardTypeString,
        NSPasteboardTypeHTML,
        @"public.utf8-plain-text",
        @"public.utf16-plain-text",
        @"public.utf16-external-plain-text",
        @"public.html",
        @"NSStringPboardType",
        @"NSHTMLPboardType",
        @"Apple HTML pasteboard type",
        nil];

    for (NSPasteboardType type in types) {
        if ([allowedTypes containsObject:type]) continue;
        UTType *ut = [UTType typeWithIdentifier:type];
        if (ut && ([ut conformsToType:UTTypePlainText] || [ut conformsToType:UTTypeHTML])) {
            continue;
        }
        [self showMessage:nil
                  message:@"Không thể chuyển mã!"
                   subMsg:@"Clipboard chứa định dạng dữ liệu khác ngoài văn bản thuần hoặc HTML. Đã huỷ chuyển mã để tránh mất dữ liệu."];
        return NO;
    }

    NSString *htmlString = [pasteboard stringForType:NSPasteboardTypeHTML];
    NSString *rawString = [pasteboard stringForType:NSPasteboardTypeString];
    bool converted = false;
    if (htmlString != nil) {
        htmlString = ConvertUtil(htmlString);
        converted = true;
    }
    if (rawString != nil) {
        rawString = ConvertUtil(rawString);
        converted = true;
    }
    if (converted) {
        [pasteboard clearContents];
        if (htmlString != nil)
            [pasteboard setString:htmlString forType:NSPasteboardTypeHTML];
        if (rawString != nil)
            [pasteboard setString:rawString forType:NSPasteboardTypeString];
        
        return YES;
    }
    return NO;
}

+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msg];
    [alert setInformativeText:subMsg];
    [alert addButtonWithTitle:@"OK"];
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        }];
    } else {
        [alert runModal];
    }
}

@end
