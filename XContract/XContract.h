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

@interface XContract : NSObject
{
    NSTextField *manualProjectNameField;
}
+ (instancetype)sharedPlugin;

@property (nonatomic, strong, readonly) NSBundle* bundle;
@property (nonatomic, strong) NSString *currentTrackedProject;
@property (nonatomic, strong) NSDate *startDate;
@property (readwrite, assign) NSInteger priorElapsedTime;
@end