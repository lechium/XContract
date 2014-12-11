//
//  XContractWindowController.h
//  XContract
//
//  Created by Kevin Bradley on 12/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XCModel.h"

@protocol XContractWindowControllerDelegate <NSObject>

- (NSString *)currentActiveProject;

@end

@interface XContractWindowController : NSWindowController

@property (nonatomic, assign) id delegate;
@property (nonatomic, strong) IBOutlet NSPanel *preferenceWindow;

@end
