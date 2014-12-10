//
//  NSDate+Additions.h
//  XContract
//
//  Created by Kevin Bradley on 2/21/13.
//
//

#import <Foundation/Foundation.h>

#define PROPER_DATE_FORMAT @"MM/dd/yyyy"

@interface NSDate (Additions)

- (NSString *) standardDateFormat;

- (NSString *)timeStringFromCurrentDate;
- (NSString *)elapsedTimeString;
@end
