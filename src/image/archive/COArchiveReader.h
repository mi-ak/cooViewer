//
//  COArchiveReader.h
//  cooViewer
//
//  Small application-facing archive API backed by the macOS system
//  libarchive library.  Keeping this boundary here means the image loader
//  does not depend on an archive implementation.
//

#import <Cocoa/Cocoa.h>

@class COArchiveReader;

@interface COArchiveEntry : NSObject {
    NSString *path;
    COArchiveReader *reader;
    NSInteger archiveIndex;
    unsigned long long size;
}

- (id)initWithPath:(NSString *)inPath
           reader:(COArchiveReader *)inReader
     archiveIndex:(NSInteger)inArchiveIndex
              size:(unsigned long long)inSize;
- (NSString *)path;
- (NSData *)data;
- (NSInteger)archiveIndex;
- (unsigned long long)size;

@end

@interface COArchiveReader : NSObject {
    NSString *filePath;
    NSMutableArray *contentArray;
    NSString *password;
    NSString *lastError;
    BOOL encrypted;
    BOOL useJapaneseNameEncoding;
    BOOL useRawFormat;
}

- (id)initWithPath:(NSString *)path;

- (int)itemCount;
- (COArchiveEntry *)itemForPath:(NSString *)path;
- (COArchiveEntry *)itemAtIndex:(int)index;
- (NSArray *)contents;

- (NSString *)filePath;
- (BOOL)crypted;
- (NSString *)password;
- (void)setPassword:(NSString *)inPassword;
- (BOOL)checkAndSetPassword:(NSString *)newPassword;
- (NSStringEncoding)encoding;
- (NSString *)errorDescription;

- (BOOL)uncompress:(int)index toTempDir:(NSString *)dir;
- (BOOL)uncompress:(int)index as:(NSString *)fileName;

@end
