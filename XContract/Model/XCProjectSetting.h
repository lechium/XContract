//
//  XCProjectSetting
//  XToDo
//
//  Created by shuice on 2014-03-08.
//  Copyright (c) 2014. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface XCProjectSetting : NSObject<NSCoding>
@property NSArray  *includeDirs;
@property NSArray  *excludeDirs;
+ (XCProjectSetting *) defaultProjectSetting;
- (NSString *) firstIncludeDir;
@end