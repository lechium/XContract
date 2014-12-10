//
//  NSDate+Additions.m
//  XContract
//
//  Created by Kevin Bradley on 2/21/13.
//
//



#import "NSDate+Additions.h"

@implementation NSDate (Additions)

- (NSString *) standardDateFormat
{
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:PROPER_DATE_FORMAT];
    return [df stringFromDate:self];
}


- (NSString *)elapsedTimeString
{
    NSTimeInterval timeInt = [self timeIntervalSinceDate:self];
    // NSLog(@"timeInt: %f", timeInt);
    NSInteger minutes = floor(timeInt/60);
    NSInteger seconds = round(timeInt - minutes * 60);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

- (NSString *)timeStringFromCurrentDate
{
    NSDate *currentDate = [NSDate date];
    NSTimeInterval timeInt = [currentDate timeIntervalSinceDate:self];
    // NSLog(@"timeInt: %f", timeInt);
    NSInteger minutes = floor(timeInt/60);
    NSInteger seconds = round(timeInt - minutes * 60);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
    
}

@end
