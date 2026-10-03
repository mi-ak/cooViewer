#import <Foundation/Foundation.h>
#import "NSString_Compare.h"

int main(void)
{
    @autoreleasepool {
        if ([@"page2.jpg" finderCompareS:@"page10.jpg"] != NSOrderedAscending) {
            NSLog(@"Numeric filename ordering failed");
            return 1;
        }
        NSString *prefix = [@"a" stringByPaddingToLength:10000 withString:@"a" startingAtIndex:0];
        NSString *first = [prefix stringByAppendingString:@"2.jpg"];
        NSString *second = [prefix stringByAppendingString:@"10.jpg"];
        if ([first finderCompareS:second] != NSOrderedAscending) {
            NSLog(@"Long filename ordering failed");
            return 1;
        }
        NSLog(@"Filename sorting tests passed.");
    }
    return 0;
}
