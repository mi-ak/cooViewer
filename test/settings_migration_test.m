#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "COArchivedSettings.h"
#import "COFileBookmarks.h"

static void Check(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"%@", message);
        exit(1);
    }
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSUserDefaults *defaults = [[[NSUserDefaults alloc] initWithSuiteName:@"cooViewerMigrationTest"] autorelease];
        [defaults removePersistentDomainForName:@"cooViewerMigrationTest"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSColor *color = [NSColor colorWithCalibratedRed:0.2 green:0.3 blue:0.4 alpha:0.5];
        [defaults setObject:[NSArchiver archivedDataWithRootObject:color] forKey:@"Color"];
        NSFont *font = [NSFont systemFontOfSize:17];
        [defaults setObject:[NSArchiver archivedDataWithRootObject:font] forKey:@"Font"];
#pragma clang diagnostic pop
        Check([COReadArchivedSetting(defaults, @"Color", [NSColor class]) isEqual:color], @"Legacy color migration failed");
        Check([COReadArchivedSetting(defaults, @"Font", [NSFont class]) isEqual:font], @"Legacy font migration failed");
        Check([NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:[defaults dataForKey:@"Color"] error:nil] != nil, @"Color was not rewritten as keyed archive");
        Check([NSKeyedUnarchiver unarchivedObjectOfClass:[NSFont class] fromData:[defaults dataForKey:@"Font"] error:nil] != nil, @"Font was not rewritten as keyed archive");
        COWriteArchivedSetting(defaults, @"Color", [NSColor whiteColor]);
        Check([COReadArchivedSetting(defaults, @"Color", [NSColor class]) isEqual:[NSColor whiteColor]], @"New color roundtrip failed");

        NSData *modern = COBookmarkDataFromPath(path);
        Check(modern != nil, @"Could not create bookmark");
        Check([COPathFromStoredBookmark(modern) isEqualToString:path], @"Bookmark roundtrip failed");
        NSString *folder = [path stringByDeletingLastPathComponent];
        Check([COPathFromStoredBookmark(COBookmarkDataFromPath(folder)) isEqualToString:folder], @"Folder bookmark roundtrip failed");

        NSString *missingPath = [folder stringByAppendingPathComponent:@"missing-book.txt"];
        [[NSFileManager defaultManager] createFileAtPath:missingPath contents:[NSData data] attributes:nil];
        NSData *missingBookmark = COBookmarkDataFromPath(missingPath);
        Check(missingBookmark != nil, @"Could not create missing-file bookmark fixture");
        [[NSFileManager defaultManager] removeItemAtPath:missingPath error:nil];
        NSDictionary *missingEntry = [NSDictionary dictionaryWithObjectsAndKeys:missingBookmark, @"alias", missingPath, @"temppath", nil];
        Check([COPathFromStoredEntry(missingEntry) isEqualToString:missingPath], @"Deleted file lost its saved path");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        FSRef ref;
        Check(FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation], &ref, NULL) == noErr, @"Could not create FSRef fixture");
        AliasHandle alias = NULL;
        Check(FSNewAlias(NULL, &ref, &alias) == noErr, @"Could not create alias fixture");
        NSData *legacy = [NSData dataWithBytes:*alias length:GetHandleSize((Handle)alias)];
        DisposeHandle((Handle)alias);
#pragma clang diagnostic pop
        NSData *converted = COBookmarkDataFromStoredData(legacy);
        Check(converted != nil, @"Legacy alias conversion failed");
        Check(![converted isEqualToData:legacy], @"Legacy alias was not rewritten as bookmark data");
        Check([COPathFromStoredBookmark(converted) isEqualToString:path], @"Converted alias path failed");
        NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:legacy, @"alias", @7, @"page", nil];
        BOOL changed = NO;
        NSArray *recents = COMigrateStoredBookmarksInCollection([NSArray arrayWithObject:entry], &changed);
        Check(changed && [[[recents objectAtIndex:0] objectForKey:@"page"] intValue] == 7, @"Recent page migration lost metadata");
        Check([COPathFromStoredBookmark([[recents objectAtIndex:0] objectForKey:@"alias"]) isEqualToString:path], @"Recent page alias was not migrated");
        NSDictionary *books = COMigrateStoredBookmarksInCollection([NSDictionary dictionaryWithObject:entry forKey:@"book"], &changed);
        Check(changed && [COPathFromStoredBookmark([[books objectForKey:@"book"] objectForKey:@"alias"]) isEqualToString:path], @"Book settings alias was not migrated");
        [defaults removePersistentDomainForName:@"cooViewerMigrationTest"];
        NSLog(@"Settings and file bookmark migration tests passed.");
    }
    return 0;
}
