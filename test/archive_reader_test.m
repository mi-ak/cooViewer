#import "COArchiveReader.h"
#include <stdlib.h>

static void Require(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Require(argc == 5, @"fixture arguments");
    NSString *directory = [NSString stringWithUTF8String:argv[4]];

    COArchiveReader *good = [[COArchiveReader alloc] initWithPath:[NSString stringWithUTF8String:argv[1]]];
    Require([good itemCount] == 1, @"nested ZIP entry is listed");
    Require([[[good itemAtIndex:0] path] isEqualToString:@"pages/first.txt"], @"entry path is preserved");
    Require([[[[NSString alloc] initWithData:[[good itemAtIndex:0] data] encoding:NSUTF8StringEncoding] autorelease]
             isEqualToString:@"page one"], @"entry contents are readable");
    Require([good uncompress:0 toTempDir:directory], @"nested entry is extracted");
    NSString *extracted = [directory stringByAppendingPathComponent:@"pages/first.txt"];
    Require([[NSString stringWithContentsOfFile:extracted encoding:NSUTF8StringEncoding error:nil]
             isEqualToString:@"page one"], @"nested extraction has expected contents");
    [good release];

    COArchiveReader *unsafe = [[COArchiveReader alloc] initWithPath:[NSString stringWithUTF8String:argv[2]]];
    Require([unsafe itemCount] == 1, @"traversal fixture is listed");
    Require(![unsafe uncompress:0 toTempDir:directory], @"parent traversal is rejected");
    NSString *escaped = [[directory stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"escape.txt"];
    Require(![[NSFileManager defaultManager] fileExistsAtPath:escaped], @"no file escaped temporary directory");
    [unsafe release];

    COArchiveReader *corrupt = [[COArchiveReader alloc] initWithPath:[NSString stringWithUTF8String:argv[3]]];
    Require([corrupt itemCount] == 1, @"corrupt entry is listed");
    NSString *existing = [directory stringByAppendingPathComponent:@"existing.txt"];
    Require([@"keep" writeToFile:existing atomically:YES encoding:NSUTF8StringEncoding error:nil],
            @"existing file is created");
    Require(![corrupt uncompress:0 as:existing], @"corrupt entry cannot replace a file");
    Require([[NSString stringWithContentsOfFile:existing encoding:NSUTF8StringEncoding error:nil]
             isEqualToString:@"keep"], @"existing file survives failed extraction");
    [corrupt release];

    [pool drain];
    return 0;
}
