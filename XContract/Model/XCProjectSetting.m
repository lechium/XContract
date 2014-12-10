//
//  XCProjectSetting
//  XToDo
//
//  Created by shuice on 2014-03-08.
//  Copyright (c) 2014. All rights reserved.
//

#import "XCProjectSetting.h"
#import "XCModel.h"

@implementation XCProjectSetting

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.includeDirs ? self.includeDirs : @[]  forKey:@"includeDirs"];
    [aCoder encodeObject:self.excludeDirs ? self.excludeDirs : @[]  forKey:@"excludeDirs"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        self.includeDirs = [aDecoder decodeObjectForKey:@"includeDirs"];
        self.excludeDirs = [aDecoder decodeObjectForKey:@"excludeDirs"];
    }
    return self;
}

+ (XCProjectSetting *) defaultProjectSetting
{
    XCProjectSetting *projectSetting = [[XCProjectSetting alloc] init];
    projectSetting.includeDirs = @[[XCModel rootPathMacro]];
    projectSetting.excludeDirs = @[[XCModel addPathSlash:[[XCModel rootPathMacro] stringByAppendingPathComponent:@"Pods"]]];
    return projectSetting;
}

- (NSString *)firstIncludeDir
{
    NSString *firstDir = [self.includeDirs count] ? [self.includeDirs objectAtIndex:0] : @"";
    if ([firstDir length] == 0)
    {
        firstDir = [XCModel rootPathMacro];
    }
    return firstDir;
}

@end
