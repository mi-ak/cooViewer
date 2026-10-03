#import <Cocoa/Cocoa.h>

static inline NSData *COBookmarkDataFromPath(NSString *path);

static inline NSData *COBookmarkDataFromStoredData(NSData *data)
{
    if (![data isKindOfClass:[NSData class]]) return nil;
    BOOL stale = NO;
    NSURL *url = [NSURL URLByResolvingBookmarkData:data
                   options:NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting
                   relativeToURL:nil bookmarkDataIsStale:&stale error:nil];
    if (url) return stale ? (COBookmarkDataFromPath([url path]) ?: data) : data;

    // Only used to convert AliasHandle records from older releases.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CFDataRef converted = CFURLCreateBookmarkDataFromAliasRecord(kCFAllocatorDefault, (CFDataRef)data);
#pragma clang diagnostic pop
    return [(NSData *)converted autorelease];
}

static inline NSString *COPathFromStoredBookmark(NSData *data)
{
    NSData *bookmark = COBookmarkDataFromStoredData(data);
    if (!bookmark) return nil;
    BOOL stale = NO;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                   options:NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting
                   relativeToURL:nil bookmarkDataIsStale:&stale error:nil];
    return [url path];
}

static inline NSString *COPathFromStoredEntry(NSDictionary *entry)
{
    NSString *path = COPathFromStoredBookmark([entry objectForKey:@"alias"]);
    if (path) return path;
    id savedPath = [entry objectForKey:@"temppath"];
    return [savedPath isKindOfClass:[NSString class]] ? savedPath : nil;
}

static inline NSData *COBookmarkDataFromPath(NSString *path)
{
    if (![path length]) return nil;
    return [[NSURL fileURLWithPath:path] bookmarkDataWithOptions:0
                                includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
}

static inline id COMigrateStoredBookmarksInCollection(id collection, BOOL *changed)
{
    BOOL isDictionary = [collection isKindOfClass:[NSDictionary class]];
    if (!isDictionary && ![collection isKindOfClass:[NSArray class]]) return collection;
    id migrated = isDictionary ? (id)[NSMutableDictionary dictionaryWithDictionary:collection]
                               : (id)[NSMutableArray arrayWithArray:collection];
    BOOL didChange = NO;
    NSArray *entryKeys = isDictionary ? [collection allKeys] : collection;
    for (NSUInteger index = 0; index < [entryKeys count]; index++) {
        id entryKey = [entryKeys objectAtIndex:index];
        id entry = isDictionary ? [collection objectForKey:entryKey] : entryKey;
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSData *oldData = [entry objectForKey:@"alias"];
        NSData *newData = COBookmarkDataFromStoredData(oldData);
        if (newData && ![newData isEqualToData:oldData]) {
            NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:entry];
            [updated setObject:newData forKey:@"alias"];
            if (isDictionary) [migrated setObject:updated forKey:entryKey];
            else [migrated replaceObjectAtIndex:index withObject:updated];
            didChange = YES;
        }
    }
    if (changed) *changed = didChange;
    return migrated;
}
