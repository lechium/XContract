//
//  XContract.h
//  XContract
//
//  Created by Kevin Bradley on 12/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "XCModel.h"
#import "XContractWindowController.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>

@interface XContract : NSObject
{
    NSTextField *manualProjectNameField;
    NSTimer *autoSaveTimer;
    NSAlert *heartBeatAlert;
    NSTimer *stillWorkingTimer;
    NSInteger autoDismissTime;
}
+ (instancetype)sharedPlugin;

@property (nonatomic, strong, readonly) NSBundle* bundle;
@property (nonatomic, strong) NSString *currentTrackedProject;
@property (nonatomic, strong) NSDate *startDate;
@property (readwrite, assign) NSInteger priorElapsedTime;
@end