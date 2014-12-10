//
//  NSString+Additions.m
//  XContract
//
//  Created by Kevin Bradley on 7/30/13.
//  Copyright (c) 2013 nito LLC. All rights reserved.
//

#import "NSString+Additions.h"
#import "NSDate+Additions.h"
//#import <CommonCrypto/CommonDigest.h>

@implementation NSString (Additions)


//check to see if a string contains another string, currently used when appending things like temperature indicators, BPM, mmHg, to make sure they arent already there

- (BOOL)containsString:(NSString *)theString
{
    if ([self rangeOfString:theString].location == NSNotFound)
        return NO;
    
    return YES;
}


- (NSDate *)dateFromDateString
{
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:PROPER_DATE_FORMAT];
    return [df dateFromString:self];
}


+ (NSString *)uniqueID
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidString = CFUUIDCreateString(NULL, uuid);
    NSString *cleanupString = (__bridge NSString*)uuidString;
    CFRelease(uuid);
    CFRelease(uuidString);
    return cleanupString;
}


+ (NSString *)stringFromInt:(int)theValue
{
    return [NSString stringWithFormat:@"%i", theValue];
}

- (BOOL)boolFromString
{
    if ([[self lowercaseString] isEqualToString:@"true"])
        return YES;
    if ([[self lowercaseString] isEqualToString:@"false"])
        return NO;
    
    return NO; //probably shouldnt default to no, but whatever.
}


+ (NSString *)myStringWithFormat:(NSString *)fmt, ...
{
    va_list args; 
    va_start(args, fmt);
    va_end(args);
    return [[NSString alloc] initWithFormat:fmt arguments:args];
}




@end
