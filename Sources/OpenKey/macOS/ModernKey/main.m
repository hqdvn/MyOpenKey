//
//  main.m
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewController.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] setObject:@[@"vi"] forKey:@"AppleLanguages"];
    }
    return NSApplicationMain(argc, argv);
}
