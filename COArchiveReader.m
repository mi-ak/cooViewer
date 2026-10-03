//
//  COArchiveReader.m
//  cooViewer
//

#import "COArchiveReader.h"
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

/*
 * The macOS SDK ships libarchive as a system library, but does not ship its
 * C headers.  These are the stable, opaque-handle APIs used by this reader.
 * The application links to -larchive; no third-party framework is embedded.
 */
struct archive;
struct archive_entry;
typedef long long COArchiveSSSize;

extern struct archive *archive_read_new(void);
extern int archive_read_support_filter_all(struct archive *);
extern int archive_read_support_format_all(struct archive *);
extern int archive_read_support_format_raw(struct archive *);
extern int archive_read_set_option(struct archive *, const char *, const char *, const char *);
extern int archive_read_add_passphrase(struct archive *, const char *);
extern int archive_read_open_filename(struct archive *, const char *, size_t);
extern int archive_read_next_header(struct archive *, struct archive_entry **);
extern COArchiveSSSize archive_read_data(struct archive *, void *, size_t);
extern int archive_read_data_skip(struct archive *);
extern int archive_read_has_encrypted_entries(struct archive *);
extern int archive_read_close(struct archive *);
extern int archive_read_free(struct archive *);
extern const char *archive_error_string(struct archive *);

extern const char *archive_entry_pathname(struct archive_entry *);
extern const char *archive_entry_pathname_utf8(struct archive_entry *);
extern long long archive_entry_size(struct archive_entry *);
extern int archive_entry_filetype(struct archive_entry *);
extern int archive_entry_is_encrypted(struct archive_entry *);

enum {
    COArchiveOK = 0,
    COArchiveEOF = 1,
    COArchiveWarn = -20,
    COArchiveDirectory = 0040000,
    COArchiveMaxDataSize = 512 * 1024 * 1024
};

static NSString *COArchiveStringFromBytes(const char *bytes, NSStringEncoding encoding)
{
    if (!bytes) return nil;
    return [[[NSString alloc] initWithBytes:bytes
                                    length:strlen(bytes)
                                  encoding:encoding] autorelease];
}

static NSString *COArchivePathFromEntry(struct archive_entry *entry)
{
    const char *utf8 = archive_entry_pathname_utf8(entry);
    NSString *path = COArchiveStringFromBytes(utf8, NSUTF8StringEncoding);
    if (path && [path length] > 0) return path;

    const char *raw = archive_entry_pathname(entry);
    path = COArchiveStringFromBytes(raw, NSUTF8StringEncoding);
    if (path && [path length] > 0) return path;

    // Old Japanese archives often contain Shift-JIS/CP932 bytes without a
    // Unicode flag.  libarchive normally converts these via hdrcharset; this
    // fallback handles readers/archives where the UTF-8 accessor is absent.
    for (NSNumber *encodingNumber in [NSArray arrayWithObjects:
            [NSNumber numberWithUnsignedInteger:NSShiftJISStringEncoding],
            [NSNumber numberWithUnsignedInteger:NSJapaneseEUCStringEncoding],
            nil]) {
        path = COArchiveStringFromBytes(raw, [encodingNumber unsignedIntegerValue]);
        if (path && [path length] > 0) return path;
    }
    return nil;
}

static BOOL COArchiveEntryIsDirectory(struct archive_entry *entry, NSString *path)
{
    if (archive_entry_filetype(entry) == COArchiveDirectory) return YES;
    return [path hasSuffix:@"/"];
}

static BOOL COArchiveShouldTryRawFormat(NSString *path)
{
    NSString *extension = [[path pathExtension] lowercaseString];
    return [@[@"gz", @"gzip", @"bz", @"bz2", @"bzip2", @"xz", @"z", @"lzma"] containsObject:extension];
}

@interface COArchiveReader ()
- (void)loadEntries;
- (struct archive *)openArchive;
- (void)setErrorFromArchive:(struct archive *)archive fallback:(NSString *)fallback;
- (NSData *)dataForArchiveIndex:(NSInteger)targetIndex;
- (BOOL)extractArchiveIndex:(NSInteger)targetIndex toPath:(NSString *)destination;
@end

@implementation COArchiveEntry

- (id)initWithPath:(NSString *)inPath
           reader:(COArchiveReader *)inReader
     archiveIndex:(NSInteger)inArchiveIndex
              size:(unsigned long long)inSize
{
    self = [super init];
    if (self) {
        path = [inPath copy];
        reader = [inReader retain];
        archiveIndex = inArchiveIndex;
        size = inSize;
    }
    return self;
}

- (void)dealloc
{
    [path release];
    [reader release];
    [super dealloc];
}

- (NSString *)path { return path; }
- (NSData *)data { return [reader dataForArchiveIndex:archiveIndex]; }
- (NSInteger)archiveIndex { return archiveIndex; }
- (unsigned long long)size { return size; }

@end

@implementation COArchiveReader

- (id)initWithPath:(NSString *)pathValue
{
    self = [super init];
    if (self) {
        filePath = [pathValue copy];
        contentArray = [[NSMutableArray alloc] init];
        useJapaneseNameEncoding = YES;
        useRawFormat = NO;
        [self loadEntries];
    }
    return self;
}

- (void)dealloc
{
    [filePath release];
    [contentArray release];
    [password release];
    [lastError release];
    [super dealloc];
}

- (void)loadEntries
{
    struct archive *archive = [self openArchive];
    if (!archive) {
        if (useJapaneseNameEncoding) {
            useJapaneseNameEncoding = NO;
            [lastError release];
            lastError = nil;
            [self loadEntries];
        } else if (!useRawFormat && COArchiveShouldTryRawFormat(filePath)) {
            useRawFormat = YES;
            [lastError release];
            lastError = nil;
            [self loadEntries];
        }
        return;
    }

    int hasEncryptedEntries = archive_read_has_encrypted_entries(archive);
    if (hasEncryptedEntries > 0) encrypted = YES;

    NSInteger archiveIndex = 0;
    BOOL shouldRetryWithDefaultEncoding = NO;
    struct archive_entry *entry = NULL;
    while (YES) {
        int result = archive_read_next_header(archive, &entry);
        if (result == -1) {
            [self setErrorFromArchive:archive fallback:@"アーカイブを読み込めませんでした。"];
            shouldRetryWithDefaultEncoding = YES;
            break;
        }
        if (result == COArchiveEOF) break;
        if (result == COArchiveWarn && useJapaneseNameEncoding) {
            // A UTF-8 archive can legitimately contain names without a
            // Unicode flag.  Forcing CP932 in that case makes libarchive
            // return ARCHIVE_WARN ("Pathname cannot be converted...") and
            // the entry pathname accessors become NULL.  Reopen the archive
            // with libarchive's normal encoding rules instead of silently
            // dropping every entry.
            shouldRetryWithDefaultEncoding = YES;
            break;
        }
        if (result < 0 && result != COArchiveWarn) {
            [self setErrorFromArchive:archive fallback:@"アーカイブの形式を認識できませんでした。"]; 
            shouldRetryWithDefaultEncoding = YES;
            break;
        }

        NSString *entryPath = COArchivePathFromEntry(entry);
        if (useRawFormat) {
            entryPath = [[[filePath lastPathComponent] stringByDeletingPathExtension] copy];
            [entryPath autorelease];
        }
        if (archive_entry_is_encrypted(entry)) encrypted = YES;
        long long entrySize = archive_entry_size(entry);
        if (entryPath && !COArchiveEntryIsDirectory(entry, entryPath) && (entrySize > 0 || useRawFormat)) {
            COArchiveEntry *item = [[COArchiveEntry alloc] initWithPath:entryPath
                                                                  reader:self
                                                            archiveIndex:archiveIndex
                                                                     size:(unsigned long long)entrySize];
            [contentArray addObject:item];
            [item release];
        }
        archive_read_data_skip(archive);
        archiveIndex++;
    }

    archive_read_close(archive);
    archive_read_free(archive);

    if (shouldRetryWithDefaultEncoding && useJapaneseNameEncoding) {
        [contentArray removeAllObjects];
        useJapaneseNameEncoding = NO;
        [lastError release];
        lastError = nil;
        [self loadEntries];
        return;
    }

    if (!useRawFormat && [contentArray count] == 0 && COArchiveShouldTryRawFormat(filePath)) {
        useRawFormat = YES;
        [lastError release];
        lastError = nil;
        [self loadEntries];
    }
}

- (struct archive *)openArchive
{
    struct archive *archive = archive_read_new();
    if (!archive) {
        [self setErrorFromArchive:NULL fallback:@"アーカイブ読み込み用の領域を確保できませんでした。"];
        return NULL;
    }

    archive_read_support_filter_all(archive);
    if (useRawFormat) archive_read_support_format_raw(archive);
    else archive_read_support_format_all(archive);

    // Prefer the common Japanese legacy encoding for entries that do not
    // carry an explicit Unicode name. If the archive rejects this charset
    // (for example a UTF-8 tar/ZIP), loadEntries retries with the default.
    if (useJapaneseNameEncoding) {
        archive_read_set_option(archive, "zip", "hdrcharset", "CP932");
        archive_read_set_option(archive, "lha", "hdrcharset", "CP932");
        archive_read_set_option(archive, "rar", "hdrcharset", "CP932");
        archive_read_set_option(archive, "cab", "hdrcharset", "CP932");
    }

    if (password && [password length] > 0) {
        archive_read_add_passphrase(archive, [password UTF8String]);
    }

    int result = archive_read_open_filename(archive, [filePath fileSystemRepresentation], 10240);
    if (result != COArchiveOK) {
        [self setErrorFromArchive:archive fallback:@"アーカイブを開けませんでした。"];
        archive_read_free(archive);
        return NULL;
    }
    return archive;
}

- (void)setErrorFromArchive:(struct archive *)archive fallback:(NSString *)fallback
{
    const char *message = archive ? archive_error_string(archive) : NULL;
    [lastError release];
    lastError = [(message && strlen(message) > 0)
        ? [NSString stringWithUTF8String:message]
        : fallback copy];
}

- (int)itemCount { return (int)[contentArray count]; }

- (COArchiveEntry *)itemForPath:(NSString *)pathValue
{
    for (COArchiveEntry *entry in contentArray) {
        if ([[entry path] isEqualToString:pathValue]) return entry;
    }
    return nil;
}

- (COArchiveEntry *)itemAtIndex:(int)index
{
    if (index < 0 || (NSUInteger)index >= [contentArray count]) return nil;
    return [contentArray objectAtIndex:index];
}

- (NSArray *)contents { return contentArray; }
- (NSString *)filePath { return filePath; }
- (BOOL)crypted { return encrypted; }
- (NSString *)password { return password; }

- (void)setPassword:(NSString *)inPassword
{
    [password release];
    password = [inPassword copy];
}

- (BOOL)checkAndSetPassword:(NSString *)newPassword
{
    [self setPassword:newPassword];
    if ([contentArray count] == 0) return NO;
    return [self dataForArchiveIndex:[[contentArray objectAtIndex:0] archiveIndex]] != nil;
}

- (NSStringEncoding)encoding { return NSUTF8StringEncoding; }
- (NSString *)errorDescription { return lastError; }

- (NSData *)dataForArchiveIndex:(NSInteger)targetIndex
{
    if (targetIndex < 0) return nil;

    struct archive *archive = [self openArchive];
    if (!archive) return nil;

    NSInteger currentIndex = 0;
    struct archive_entry *entry = NULL;
    NSData *resultData = nil;
    while (YES) {
        int result = archive_read_next_header(archive, &entry);
        if (result == COArchiveEOF) break;
        if (result < 0 && result != COArchiveWarn) {
            [self setErrorFromArchive:archive fallback:@"アーカイブ項目を読み込めませんでした。"];
            break;
        }
        if (currentIndex == targetIndex) {
            long long expectedSize = archive_entry_size(entry);
            if (expectedSize < 0 || expectedSize > COArchiveMaxDataSize) {
                [self setErrorFromArchive:archive fallback:@"アーカイブ項目が大きすぎます。"];
                break;
            }

            NSMutableData *data = [[NSMutableData alloc] initWithCapacity:
                (NSUInteger)MIN(expectedSize, (long long)(4 * 1024 * 1024))];
            char buffer[64 * 1024];
            BOOL failed = NO;
            while (YES) {
                COArchiveSSSize length = archive_read_data(archive, buffer, sizeof(buffer));
                if (length == 0) break;
                if (length < 0 || [data length] + (NSUInteger)length > COArchiveMaxDataSize) {
                    failed = YES;
                    [self setErrorFromArchive:archive fallback:@"アーカイブ項目を安全に展開できませんでした。"];
                    break;
                }
                [data appendBytes:buffer length:(NSUInteger)length];
            }
            if (!failed) resultData = [data autorelease];
            else [data release];
            break;
        }
        archive_read_data_skip(archive);
        currentIndex++;
    }

    archive_read_close(archive);
    archive_read_free(archive);
    return resultData;
}

- (BOOL)extractArchiveIndex:(NSInteger)targetIndex toPath:(NSString *)destination
{
    if (targetIndex < 0 || !destination || [destination length] == 0) return NO;

    int fd = open([destination fileSystemRepresentation], O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd < 0) {
        [lastError release];
        lastError = [NSString stringWithFormat:@"展開先を作成できませんでした: %@", destination];
        return NO;
    }

    BOOL succeeded = NO;
    struct archive *archive = [self openArchive];
    if (archive) {
        NSInteger currentIndex = 0;
        struct archive_entry *entry = NULL;
        while (YES) {
            int result = archive_read_next_header(archive, &entry);
            if (result == COArchiveEOF) break;
            if (result < 0 && result != COArchiveWarn) {
                [self setErrorFromArchive:archive fallback:@"アーカイブ項目を展開できませんでした。"];
                break;
            }
            if (currentIndex == targetIndex) {
                char buffer[64 * 1024];
                BOOL readFailed = NO;
                while (YES) {
                    COArchiveSSSize length = archive_read_data(archive, buffer, sizeof(buffer));
                    if (length == 0) break;
                    if (length < 0) {
                        readFailed = YES;
                        break;
                    }

                    size_t offset = 0;
                    while (offset < (size_t)length) {
                        ssize_t written = write(fd, buffer + offset, (size_t)length - offset);
                        if (written > 0) {
                            offset += (size_t)written;
                        } else if (written < 0 && errno == EINTR) {
                            continue;
                        } else {
                            readFailed = YES;
                            break;
                        }
                    }
                    if (readFailed) break;
                }
                succeeded = !readFailed;
                if (!succeeded) [self setErrorFromArchive:archive fallback:@"アーカイブ項目を展開できませんでした。"];
                break;
            }
            archive_read_data_skip(archive);
            currentIndex++;
        }
        archive_read_close(archive);
        archive_read_free(archive);
    }
    close(fd);

    if (!succeeded) [[NSFileManager defaultManager] removeItemAtPath:destination error:nil];
    return succeeded;
}

- (BOOL)uncompress:(int)index toTempDir:(NSString *)dir
{
    if (index < 0 || (NSUInteger)index >= [contentArray count] || !dir) return NO;
    COArchiveEntry *entry = [contentArray objectAtIndex:index];
    return [self extractArchiveIndex:[entry archiveIndex]
                              toPath:[dir stringByAppendingPathComponent:[entry path]]];
}

- (BOOL)uncompress:(int)index as:(NSString *)fileName
{
    if (index < 0 || (NSUInteger)index >= [contentArray count]) return NO;
    COArchiveEntry *entry = [contentArray objectAtIndex:index];
    return [self extractArchiveIndex:[entry archiveIndex] toPath:fileName];
}

@end
