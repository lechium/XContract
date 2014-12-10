//
//  NSString+Additions.h
//  XContract
//
//  Created by Kevin Bradley on 7/30/13.
//  Copyright (c) 2013 nito LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (Additions)

- (NSDate *)dateFromDateString;
+ (NSString *)uniqueID;
+ (NSString *)myStringWithFormat:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1,2);
+ (NSString *)stringFromInt:(int)theValue;
@end
