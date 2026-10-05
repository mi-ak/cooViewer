#import "COArchiveReader.h"
#import "Controller.h"
#import "COImageLoader.h"
#import "COPDFImage.h"
#import "COPDFImageRep.h"
#import "NSString_Compare.h"
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface COImageLoader (private)
-(void)content;
-(BOOL)checkArchiveContainer:(int)index;
-(BOOL)uncompressToTempDir:(NSString*)file;
@end

@interface COImageLoader ()
-(id)initWithPath:(NSString *)path displayPath:(NSString *)dispPath readSubFolder:(BOOL)boo controller:(id)ctr imagesOnly:(BOOL)imagesOnly;
-(NSImage *)imageWithData:(NSData *)data maxPixelSize:(NSUInteger)maxPixelSize;
-(NSImage *)imageWithData:(NSData *)data maxPixelSize:(NSUInteger)maxPixelSize fileName:(NSString *)fileName;
-(NSImage *)imageWithContentsOfFile:(NSString *)path maxPixelSize:(NSUInteger)maxPixelSize;
//-(BOOL)uncompressAllFileToTempDir;
@end
static NSArray *_COImageLoader_fileTypes=nil;
static NSArray *_COImageLoader_archiveTypes=nil;
static NSArray *_COImageLoader_imageFileTypes=nil;

@interface COAnimatedImage ()
- (id)initWithImageSource:(CGImageSourceRef)source data:(NSData *)data isWebP:(BOOL)isWebP;
- (void)drawFrame:(CGImageRef)frame clearCanvas:(BOOL)clearCanvas;
- (NSImage *)imageFromCompositingContext;
- (NSImage *)compositedImageForFrame:(CGImageRef)frame clearCanvas:(BOOL)clearCanvas;
@end

@implementation COAnimatedImage

+ (NSImage *)animatedImageWithData:(NSData *)data fileExtension:(NSString *)extension
{
	if (!data || [data length] == 0) return nil;
	NSString *lowercaseExtension = [extension lowercaseString];
	BOOL isWebP = [lowercaseExtension isEqualToString:@"webp"];
	if (!isWebP && ![lowercaseExtension isEqualToString:@"gif"]) return nil;

	NSData *imageData = [NSData dataWithData:data];
	CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
	if (!source) return nil;
	if (CGImageSourceGetCount(source) < 2) {
		CFRelease(source);
		return nil;
	}
	COAnimatedImage *image = [[[COAnimatedImage alloc] initWithImageSource:source data:imageData isWebP:isWebP] autorelease];
	CFRelease(source);
	return image;
}

- (id)initWithImageSource:(CGImageSourceRef)source data:(NSData *)data isWebP:(BOOL)isWebP
{
	CGImageRef firstFrame = CGImageSourceCreateImageAtIndex(source, 0, NULL);
	if (!firstFrame) {
		[self release];
		return nil;
	}
	NSSize imageSize = NSMakeSize(CGImageGetWidth(firstFrame), CGImageGetHeight(firstFrame));
	self = [super initWithSize:imageSize];
	if (self) {
		_imageSource = (CGImageSourceRef)CFRetain(source);
		_sourceData = [data copy];
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		_compositingContext = CGBitmapContextCreate(NULL,
			(size_t)imageSize.width, (size_t)imageSize.height, 8, 0, colorSpace,
			(CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
		CGColorSpaceRelease(colorSpace);
		_currentFrameImage = [[self compositedImageForFrame:firstFrame clearCanvas:YES] retain];

		NSMutableArray *durations = [NSMutableArray array];
		NSUInteger frameCount = CGImageSourceGetCount(_imageSource);
		for (NSUInteger index = 0; index < frameCount; index++) {
			NSDictionary *properties = [(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(_imageSource, index, NULL) autorelease];
			NSDictionary *formatProperties = nil;
			NSNumber *delay = nil;
			if (isWebP) {
				formatProperties = [properties objectForKey:(id)kCGImagePropertyWebPDictionary];
				id unclampedDelay = [formatProperties objectForKey:(id)kCGImagePropertyWebPUnclampedDelayTime];
				delay = unclampedDelay ? unclampedDelay : [formatProperties objectForKey:(id)kCGImagePropertyWebPDelayTime];
			} else {
				formatProperties = [properties objectForKey:(id)kCGImagePropertyGIFDictionary];
				id unclampedDelay = [formatProperties objectForKey:(id)kCGImagePropertyGIFUnclampedDelayTime];
				delay = unclampedDelay ? unclampedDelay : [formatProperties objectForKey:(id)kCGImagePropertyGIFDelayTime];
			}
			NSTimeInterval duration = [delay respondsToSelector:@selector(doubleValue)] ? [delay doubleValue] : 0.1;
			[durations addObject:[NSNumber numberWithDouble:MAX(0.02, duration)]];
		}
		_frameDurations = [[NSArray alloc] initWithArray:durations];

		NSDictionary *containerProperties = [(NSDictionary *)CGImageSourceCopyProperties(_imageSource, NULL) autorelease];
		NSDictionary *formatContainerProperties = nil;
		NSNumber *loopCount = nil;
		if (isWebP) {
			formatContainerProperties = [containerProperties objectForKey:(id)kCGImagePropertyWebPDictionary];
			loopCount = [formatContainerProperties objectForKey:(id)kCGImagePropertyWebPLoopCount];
		} else {
			formatContainerProperties = [containerProperties objectForKey:(id)kCGImagePropertyGIFDictionary];
			loopCount = [formatContainerProperties objectForKey:(id)kCGImagePropertyGIFLoopCount];
		}
		_loopCount = [loopCount respondsToSelector:@selector(unsignedIntegerValue)] ? [loopCount unsignedIntegerValue] : 0;
		_nextFrameTime = [NSDate timeIntervalSinceReferenceDate] + [[_frameDurations objectAtIndex:0] doubleValue];
		CGImageRelease(firstFrame);
		if (!_currentFrameImage) {
			[self release];
			return nil;
		}
	} else {
		CGImageRelease(firstFrame);
	}
	return self;
}

- (NSImage *)compositedImageForFrame:(CGImageRef)frame clearCanvas:(BOOL)clearCanvas
{
	if (!frame || !_compositingContext) return nil;
	[self drawFrame:frame clearCanvas:clearCanvas];
	return [self imageFromCompositingContext];
}

- (void)drawFrame:(CGImageRef)frame clearCanvas:(BOOL)clearCanvas
{
	if (!frame || !_compositingContext) return;
	CGRect canvasRect = CGRectMake(0, 0, [self size].width, [self size].height);
	if (clearCanvas) {
		CGContextClearRect(_compositingContext, canvasRect);
	}
	CGContextSetBlendMode(_compositingContext, kCGBlendModeNormal);
	CGRect frameRect = CGRectMake(0, 0, CGImageGetWidth(frame), CGImageGetHeight(frame));
	CGContextDrawImage(_compositingContext, frameRect, frame);
	}

- (NSImage *)imageFromCompositingContext
{
	if (!_compositingContext) return nil;
	NSInteger width = (NSInteger)[self size].width;
	NSInteger height = (NSInteger)[self size].height;
	NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
		pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
		isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0] autorelease];
	if (!rep) return nil;
	const uint8_t *source = (const uint8_t *)CGBitmapContextGetData(_compositingContext);
	uint8_t *destination = [rep bitmapData];
	size_t sourceBytesPerRow = CGBitmapContextGetBytesPerRow(_compositingContext);
	size_t destinationBytesPerRow = (size_t)[rep bytesPerRow];
	size_t rowBytes = (size_t)width * 4;
	for (NSInteger row = 0; row < height; row++) {
		memcpy(destination + (size_t)row * destinationBytesPerRow,
			source + (size_t)row * sourceBytesPerRow, rowBytes);
	}
	NSImage *frameImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
	[frameImage addRepresentation:rep];
	return frameImage;
}

- (NSTimeInterval)timeUntilNextFrame
{
	if (_animationFinished) return -1.0;
	return MAX(0.0, _nextFrameTime - [NSDate timeIntervalSinceReferenceDate]);
}

- (void)restartAnimation
{
	if (_currentFrame != 0) {
		CGImageRef cgFirstFrame = CGImageSourceCreateImageAtIndex(_imageSource, 0, NULL);
		NSImage *firstFrame = [self compositedImageForFrame:cgFirstFrame clearCanvas:YES];
		if (cgFirstFrame) CGImageRelease(cgFirstFrame);
		if (firstFrame) {
			[_currentFrameImage release];
			_currentFrameImage = [firstFrame retain];
		}
	}
	_currentFrame = 0;
	_completedLoops = 0;
	_animationFinished = NO;
	_nextFrameTime = [NSDate timeIntervalSinceReferenceDate] + [[_frameDurations objectAtIndex:0] doubleValue];
}

- (BOOL)advanceFrameIfNeeded
{
	if (_animationFinished || [self timeUntilNextFrame] > 0.0) return NO;
	NSUInteger frameCount = CGImageSourceGetCount(_imageSource);
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	BOOL didAdvance = NO;
	while (!_animationFinished && now >= _nextFrameTime) {
		NSUInteger nextFrame = _currentFrame + 1;
		if (nextFrame >= frameCount) {
			_completedLoops++;
			if (_loopCount > 0 && _completedLoops >= _loopCount) {
				_animationFinished = YES;
				break;
			}
			nextFrame = 0;
	CGContextClearRect(_compositingContext, CGRectMake(0, 0, [self size].width, [self size].height));
		}
		_currentFrame = nextFrame;
		_nextFrameTime += [[_frameDurations objectAtIndex:_currentFrame] doubleValue];
		CGImageRef cgFrame = CGImageSourceCreateImageAtIndex(_imageSource, _currentFrame, NULL);
		if (cgFrame) {
			[self drawFrame:cgFrame clearCanvas:NO];
			CGImageRelease(cgFrame);
		}
		didAdvance = YES;
	}
	if (didAdvance) {
		NSImage *frameImage = [self imageFromCompositingContext];
		if (frameImage) {
			[_currentFrameImage release];
			_currentFrameImage = [frameImage retain];
		}
	}
	return didAdvance;
}

- (void)drawInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(CGFloat)delta
{
	[_currentFrameImage drawInRect:dstRect fromRect:srcRect operation:op fraction:delta];
}

- (NSArray *)representations
{
	if (_currentFrameImage) return [_currentFrameImage representations];
	return [super representations];
}

- (BOOL)isValid
{
	return _currentFrameImage && [_currentFrameImage isValid];
}

- (void)dealloc
{
	if (_imageSource) CFRelease(_imageSource);
	if (_compositingContext) CGContextRelease(_compositingContext);
	[_sourceData release];
	[_frameDurations release];
	[_currentFrameImage release];
	[super dealloc];
}

@end

@implementation COImageLoader
+(NSArray *)imageFileTypes
{
	if (!_COImageLoader_imageFileTypes) {
		NSMutableSet *types = [NSMutableSet set];
		for (NSString *identifier in [NSImage imageTypes]) {
			UTType *type = [UTType typeWithIdentifier:identifier];
			NSArray *extensions = [[type tags] objectForKey:UTTagClassFilenameExtension];
			if (extensions) [types addObjectsFromArray:extensions];
		}
		// Some systems resolve only a few advertised type identifiers through
		// LaunchServices. Preserve the previous image extension set there.
		if ([types count] < 10) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			[types addObjectsFromArray:[NSImage imageFileTypes]];
#pragma clang diagnostic pop
		}
		// AVIF is supported by ImageIO on current macOS versions, but older
		// AppKit SDK/runtime combinations do not always advertise the extension.
		[types addObjectsFromArray:[NSArray arrayWithObjects:@"avif", @"webp", nil]];
		NSMutableSet *normalizedTypes = [NSMutableSet set];
		for (NSString *extension in types) {
			[normalizedTypes addObject:[extension lowercaseString]];
			[normalizedTypes addObject:[extension uppercaseString]];
		}
		_COImageLoader_imageFileTypes = [[[normalizedTypes allObjects] sortedArrayUsingSelector:@selector(compare:)] retain];
	}
	return _COImageLoader_imageFileTypes;
}

+(NSArray *)fileTypes
{
	//COImageLoaderで読み込める種類(スマートフォルダとフォルダ以外)
	if (!_COImageLoader_fileTypes) {
		id types = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDocumentTypes"];
		id object,inner;
		NSMutableArray *array = [NSMutableArray array];
		NSEnumerator *enu = [types objectEnumerator];
		while (object=[enu nextObject]) {
            if ((inner = [object objectForKey:@"CFBundleTypeExtensions"])) {
				[array addObjectsFromArray:inner];
			}
		}
		NSArray *imageTypes = [COImageLoader imageFileTypes];
		for (NSString *extension in [NSArray arrayWithArray:array]) {
			if ([imageTypes containsObject:[extension lowercaseString]]) {
				[array removeObject:extension];
			}
		}
		[array removeObjectsInArray:[NSArray arrayWithObjects:@"savedSearch",nil]];
		[array addObject:@"pdf"];
		_COImageLoader_fileTypes = [[NSArray arrayWithArray:array] retain];
		//NSLog(@"%@",_COImageLoader_fileTypes);
	}
	return _COImageLoader_fileTypes;
	//return [NSArray arrayWithObjects:@"zip",@"cbz",@"rar",@"cbr",@"lzh",@"lha",@"7z",@"pdf",@"cvbdl",nil];
}
+(NSArray *)archiveTypes
{
	//COImageLoaderで読み込めるアーカイブ
	if (!_COImageLoader_archiveTypes) {
		NSMutableArray *temp = [NSMutableArray arrayWithArray:[COImageLoader fileTypes]];
		[temp removeObjectsInArray:[NSArray arrayWithObjects:@"cvbdl",@"pdf",nil]];
		[temp removeObjectsInArray:[COImageLoader imageFileTypes]];
		_COImageLoader_archiveTypes = [[NSArray arrayWithArray:temp] retain];
		//NSLog(@"%@",_COImageLoader_archiveTypes);
	}
	return _COImageLoader_archiveTypes;
	//return [NSArray arrayWithObjects:@"zip",@"cbz",@"rar",@"cbr",@"lzh",@"lha",@"7z",nil];
}

- (NSString*)displayPath
{
	return displayPath;
}

- (id)initWithPath:(NSString *)path displayPath:(NSString *)dispPath readSubFolder:(BOOL)boo controller:(id)ctr;
{
	return [self initWithPath:path displayPath:dispPath readSubFolder:boo controller:ctr imagesOnly:NO];
}

- (id)initWithImagePath:(NSString *)path readSubFolder:(BOOL)boo controller:(id)ctr
{
	NSString *folder = [path stringByDeletingLastPathComponent];
	return [self initWithPath:folder displayPath:folder readSubFolder:boo controller:ctr imagesOnly:YES];
}

- (id)initWithPath:(NSString *)path displayPath:(NSString *)dispPath readSubFolder:(BOOL)boo controller:(id)ctr imagesOnly:(BOOL)imagesOnly
{
	
	self = [super init];
    if (self) {
		rightPassward = NO;
		controller = ctr;
		tempDir = nil;
		inTempDir = NO;
		inArchiveArray = [[NSMutableArray alloc] init];
		
		NSMutableArray *tempArray = [NSMutableArray arrayWithArray:[COImageLoader imageFileTypes]];
		if (imagesOnly) {
			// AppKit advertises PDF among its image types, but it is a separate book.
			[tempArray removeObjectsInArray:[NSArray arrayWithObjects:@"pdf", @"PDF", nil]];
		} else {
			[tempArray addObjectsFromArray:[COImageLoader fileTypes]];
		}
		
		filterArray = [[NSArray arrayWithArray:tempArray] retain];
		readSubFolder=boo;
		mode=-1;
		password=nil;
		filePath=[path retain];
		displayPath = [dispPath retain];
		archiveContainer = nil;
		subArchiveContainer = nil;
		contentPathArray = [[NSMutableArray alloc] init];
		contentPathDic = [[NSMutableDictionary alloc] init];
		rawContentPathArray = [[NSMutableArray alloc] init];
		pdfRep = nil;
		pdfDocument = nil;
		
		[self content];
	}
	if ([self itemCount]==0 && mode >= 0) {
		NSString *emptyPath = [[NSBundle mainBundle] pathForResource:@"empty" ofType:@"png"];
		if (emptyPath) [contentPathArray addObject:emptyPath];
	}
    return self;	
}

- (id)initWithPath:(NSString *)path readSubFolder:(BOOL)boo controller:(id)ctr;
{
	return [self initWithPath:path displayPath:path readSubFolder:boo controller:ctr];
}

- (void)dealloc
{
	if(tempDir) {
        [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:tempDir] error:nil];
		[tempDir release];
	}
	
	if(rawContentPathArray)[rawContentPathArray release];
	if(inArchiveArray)[inArchiveArray release];
	if(filePath)[filePath release];
	if(displayPath)[displayPath release];
	if(password)[password release];
	if(archiveContainer)[archiveContainer release];
	if(subArchiveContainer)[subArchiveContainer release];
	if(contentPathArray)[contentPathArray release];
	if(contentPathDic)[contentPathDic release];
	if(filterArray)[filterArray release];
	if(pdfRep)[pdfRep release];
	if(pdfDocument)[pdfDocument release];
	
	[super dealloc];
}

#pragma mark -
- (NSString *)filePath
{
	return filePath;
}

- (int)itemCount
{
	if(contentPathArray)	return (int)[contentPathArray count];
	return 0;
}
- (int)mode
{
	return mode;
}

- (NSString*)itemPathAtIndex:(int)index
{
	if ([inArchiveArray count] > 0) {
		NSString *fileName = [contentPathArray objectAtIndex:index];
		int i;
		for (i=0; i<[inArchiveArray count]; i++) {
			COImageLoader *inLoader = [inArchiveArray objectAtIndex:i];
			if (![inLoader isInTempDir] && [[inLoader pathArray] indexOfObject:fileName] != NSNotFound) {
				return [inLoader filePath];
			}
		}
	}
	if (mode==0 || mode==3 || mode==5) {
		return [contentPathArray objectAtIndex:index];
	} else {
		return filePath;
	}
}

- (NSString*)itemNameAtIndex:(int)index
{
	return [contentPathArray objectAtIndex:index];
}

- (BOOL)canSortByDate
{
	if ([inArchiveArray count]>0) {
		return NO;
	}
	if (mode==0 || mode==3) {
		return YES;
	}
	return NO;
}

- (NSString *)password
{
	return password;
}
- (NSMutableArray*)pathArray
{
	return contentPathArray;
}
#pragma mark -

- (id)itemAtIndex:(int)index
{
	return [self itemAtIndex:index maxPixelSize:0];
}

- (NSImage *)itemAtIndex:(int)index maxPixelSize:(NSUInteger)maxPixelSize
{
	if (index < 0 || index >= [contentPathArray count]) return nil;

	if ([inArchiveArray count] > 0) {
		NSString *fileName = [contentPathArray objectAtIndex:index];
		int i;
		for (i=0; i<[inArchiveArray count]; i++) {
			COImageLoader *inLoader = [inArchiveArray objectAtIndex:i];
			NSUInteger nestedIndex = [[inLoader pathArray] indexOfObject:fileName];
			if (nestedIndex != NSNotFound) {
				return [inLoader itemAtIndex:(int)nestedIndex maxPixelSize:maxPixelSize];
			}
		}
	}
	if (mode==4) {
		NSImage *image = [[[COPDFImage alloc] initWithPDFRep:pdfRep page:index] autorelease];
		if (image) return image;
	} else if(mode==2) {
		NSString *rawName = [contentPathDic objectForKey:[contentPathArray objectAtIndex:index]];
		NSImage *image = nil;
		COArchiveEntry *entry = [archiveContainer itemForPath:rawName];
		if (entry) {
			// Keep archive images in memory while ImageIO creates the image. An
			// NSImage loaded from a temporary URL may defer decoding until after
			// that URL has been removed; this is particularly visible with AVIF.
			NSData *data = [entry data];
			image = [self imageWithData:data maxPixelSize:maxPixelSize fileName:rawName];
		}
		if (image && [image isValid] && [[image representations] count] > 0) {
			return image;
		}
	} else {
		NSImage *image = [self imageWithContentsOfFile:[contentPathArray objectAtIndex:index]
			maxPixelSize:maxPixelSize];
		if (image && [image isValid] && [[image representations] count] > 0) {
			return image;
		}
	}
	static NSImage *brokenImage = nil;
	if (!brokenImage) {
		brokenImage = [[NSImage allocWithZone:NULL] initWithContentsOfFile:
			[[NSBundle mainBundle] pathForResource:@"broken" ofType:@"png"]];
	}
	return brokenImage;
}

- (NSImage *)imageWithData:(NSData *)data maxPixelSize:(NSUInteger)maxPixelSize
{
	return [self imageWithData:data maxPixelSize:maxPixelSize fileName:nil];
}

- (NSImage *)imageWithData:(NSData *)data maxPixelSize:(NSUInteger)maxPixelSize fileName:(NSString *)fileName
{
	if (!data || [data length] == 0) return nil;

	if (maxPixelSize > 0) {
		// libarchive returns mutable data. ImageIO's thumbnail path can retain
		// that buffer beyond the call, so hand it an immutable copy.
		NSData *imageData = [NSData dataWithData:data];
		CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
		if (source) {
			NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool:YES], (id)kCGImageSourceCreateThumbnailFromImageAlways,
				[NSNumber numberWithBool:YES], (id)kCGImageSourceCreateThumbnailWithTransform,
				[NSNumber numberWithUnsignedInteger:maxPixelSize], (id)kCGImageSourceThumbnailMaxPixelSize,
				nil];
			CGImageRef cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)options);
			if (cgImage) {
				NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithCGImage:cgImage] autorelease];
				NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(
					CGImageGetWidth(cgImage), CGImageGetHeight(cgImage))] autorelease];
				[image addRepresentation:rep];
				CGImageRelease(cgImage);
				CFRelease(source);
				return image;
			}
			CFRelease(source);
		}
	}
	if (maxPixelSize == 0 && fileName) {
		NSImage *animatedImage = [COAnimatedImage animatedImageWithData:data fileExtension:[fileName pathExtension]];
		if (animatedImage) return animatedImage;
	}

	return [[[NSImage allocWithZone:NULL] initWithData:data] autorelease];
}

- (NSImage *)imageWithContentsOfFile:(NSString *)path maxPixelSize:(NSUInteger)maxPixelSize
{
	if (!path || [path length] == 0) return nil;

	if (maxPixelSize > 0) {
		NSURL *url = [NSURL fileURLWithPath:path];
		CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
		if (source) {
			NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool:YES], (id)kCGImageSourceCreateThumbnailFromImageAlways,
				[NSNumber numberWithBool:YES], (id)kCGImageSourceCreateThumbnailWithTransform,
				[NSNumber numberWithUnsignedInteger:maxPixelSize], (id)kCGImageSourceThumbnailMaxPixelSize,
				nil];
			CGImageRef cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)options);
			if (cgImage) {
				NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithCGImage:cgImage] autorelease];
				NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(
					CGImageGetWidth(cgImage), CGImageGetHeight(cgImage))] autorelease];
				[image addRepresentation:rep];
				CGImageRelease(cgImage);
				CFRelease(source);
				return image;
			}
			CFRelease(source);
		}
	}
	if (maxPixelSize == 0) {
		NSString *extension = [path pathExtension];
		if ([[extension lowercaseString] isEqualToString:@"gif"] || [[extension lowercaseString] isEqualToString:@"webp"]) {
			NSData *imageData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
			NSImage *animatedImage = [COAnimatedImage animatedImageWithData:imageData fileExtension:extension];
			if (animatedImage) return animatedImage;
		}
	}

	NSImage *image = [[[NSImage allocWithZone:NULL] initWithContentsOfFile:path] autorelease];
	if (image && [image isValid] && [[image representations] count] > 0) return image;

	// Some ImageIO formats, notably AVIF on older AppKit combinations, are
	// recognized reliably from their bytes but not from a file URL. Keep the
	// normal URL path first for low memory use, then use the format detector.
	NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
	return [self imageWithData:data maxPixelSize:maxPixelSize];
}

#pragma mark -
- (int)nextFolder:(int)now
{
	int i = now-1;
	//NSLog(@"next startAt  %@",[contentPathArray objectAtIndex:now-1]);
	NSString *currentFolder = [[contentPathArray objectAtIndex:i] stringByDeletingLastPathComponent];
	for (i+=1;i<[contentPathArray count];i++) {
		NSString *nextFolder = [[contentPathArray objectAtIndex:i] stringByDeletingLastPathComponent];
		//NSLog(@"%@",[contentPathArray objectAtIndex:i]);
		if (![currentFolder isEqualToString:nextFolder]) {
			//NSLog(@"found1");
			return i;
		}
	}
	for (i=0;i<[contentPathArray count];i++) {
		if (i==now-1) {
			//NSLog(@"notFound");
			return 0;
		}
		NSString *nextFolder = [[contentPathArray objectAtIndex:i] stringByDeletingLastPathComponent];
		//NSLog(@"%@",[contentPathArray objectAtIndex:i]);
		if (![currentFolder isEqualToString:nextFolder]) {
			//NSLog(@"found2");
			return i;
		}
	}
	return 0;
	//NSLog(@"next end");
}
- (int)prevFolder:(int)now
{
	//NSLog(@"prev startAt %@",[contentPathArray objectAtIndex:now-1]);
	NSString *currentFolder = [[contentPathArray objectAtIndex:now-1] stringByDeletingLastPathComponent];
	if (now-2>0 && [currentFolder isEqualToString:[[contentPathArray objectAtIndex:now-2] stringByDeletingLastPathComponent]]) {
		//1つ前も同じフォルダだったらこのフォルダの先頭を検索
		NSString *prevFolder;
		int i = now-1;
		for (i;i>=0;i--) {
			if (i == 0) return 0;
			prevFolder = [[contentPathArray objectAtIndex:i] stringByDeletingLastPathComponent];
			if (![currentFolder isEqualToString:prevFolder]) {
				return i+1;
			}
		}
	} else {
		//1つ前が違うフォルダだったらそっちの先頭を検索
		NSString *prevFolder,*prevFolderHead;
		int i = now-1;
		for (i;i>=0;i--) {
			prevFolder = [[contentPathArray objectAtIndex:i] stringByDeletingLastPathComponent];
			//NSLog(@"%@ %i",[contentPathArray objectAtIndex:i],i);
			if (![currentFolder isEqualToString:prevFolder]) {
				int ii;
				for (ii=i;ii>=0;ii--) {
					if (ii == 0) return 0;
					prevFolderHead = [[contentPathArray objectAtIndex:ii] stringByDeletingLastPathComponent];
					//NSLog(@"%@",[contentPathArray objectAtIndex:ii]);
					if (![prevFolder isEqualToString:prevFolderHead]) {
						//NSLog(@"found1 %i",ii+1);
						return ii+1;
					}
				}
			}
		}
		i=(int)[contentPathArray count]-1;
		for (i;i>=0;i--) {
			if (i==now) {
				//NSLog(@"notFound");
				return now-1;
			}
			prevFolder = [[contentPathArray objectAtIndex:i] stringByDeletingLastPathComponent];
			//NSLog(@"%@",[contentPathArray objectAtIndex:i]);
			if (![currentFolder isEqualToString:prevFolder]) {
				int ii;
				for (ii=i;ii>=0;ii--) {
					if (ii == 0) return 0;
					prevFolderHead = [[contentPathArray objectAtIndex:ii] stringByDeletingLastPathComponent];
					if (![prevFolder isEqualToString:prevFolderHead]) {
						//NSLog(@"found2 %i",ii+1);
						return ii+1;
					}
				}
			}
		}
	}
	//NSLog(@"prev end");
	return now-1;
}
#pragma mark -

- (BOOL)crypted
{
	if (mode==2)
		return [archiveContainer crypted];
	if (mode==4)
		return [pdfDocument isEncrypted];
	
	return NO;
}

- (void)setPassword:(NSString *)inStr
{
	if (mode==4) {
		if (!pdfDocument || ![pdfDocument unlockWithPassword:(inStr ? inStr : @"")]) return;
		// Keep the unlocked representation in memory. PDFDocument's default
		// dataRepresentation preserves the original password requirement.
		NSData *data = [pdfDocument dataRepresentationWithOptions:
			[NSDictionary dictionaryWithObjectsAndKeys:@"", PDFDocumentOwnerPasswordOption,
				@"", PDFDocumentUserPasswordOption, nil]];
		COPDFImageRep *unlockedRep = data ? [COPDFImageRep imageRepWithData:data] : nil;
		if (unlockedRep && [unlockedRep pageCount] == [pdfDocument pageCount] &&
			[unlockedRep size].width > 0 && [unlockedRep size].height > 0) {
			[pdfRep release];
			pdfRep = [unlockedRep retain];
		}
		return;
	}
	if (mode==2) {
		if(password)[password release];
		password=nil;
		if(inStr){
			password=[inStr retain];
			[archiveContainer setPassword:password];
		}
	}
}

- (BOOL)checkPassword
{
	if (mode==4) return pdfDocument && ![pdfDocument isLocked] && pdfRep != nil;
	if (rightPassward || !(mode==2) || ![self crypted]) return YES;
	if (password==nil) return NO;
	
	NSData *tempData = [[[archiveContainer contents] objectAtIndex:0] data];
	//tempData = nil;
	if (!tempData || [tempData length]<=0 || [[[archiveContainer contents] objectAtIndex:0] path]==nil) {
		if (mode == 2) {
			if (![[archiveContainer errorDescription] length]) {
				rightPassward = YES;
				return YES;
			}
		}
	} else {
		rightPassward = YES;
		return YES;
	}
	return NO;
}

- (BOOL)checkAndSetPassword:(NSString *)newPassword
{
	[self setPassword:newPassword];
	return [self checkPassword];
}

- (BOOL)isInTempDir
{
	if (inTempDir) return YES;
	return NO;
}

- (void)setInTempDir:(BOOL)b
{
	inTempDir = b;
}
@end

@implementation COImageLoader(private)
- (void)content
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) return;
	
	NSMutableArray *pathArray = [NSMutableArray array];
	if ([[filePath pathExtension] compare:@"pdf" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		mode=4;
		NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:nil];
		pdfDocument = [[PDFDocument alloc] initWithData:data];
		if ([pdfDocument isLocked] && controller) [controller askForPassword:self];
		int pages = (int)[pdfDocument pageCount];
		if (!pdfDocument || pages < 1) {
			mode = -1;
			return;
		}
		if (![pdfDocument isLocked] && !pdfRep) {
			pdfRep = [[COPDFImageRep imageRepWithData:data] retain];
			if (!pdfRep || [pdfRep size].width <= 0 || [pdfRep size].height <= 0) {
				mode = -1;
				return;
			}
		}
		int i;
		for (i=0;pages>i;i++) {
			[contentPathArray addObject:[NSString stringWithFormat:@"%@/%i.pdf",filePath,i+1]];
		}
		return;
		
	} else if([[COImageLoader archiveTypes] containsObject:[[filePath pathExtension] lowercaseString]]) {
		mode=2;
        archiveContainer=[[COArchiveReader alloc] initWithPath:filePath];
		[self checkArchiveContainer:0];
		return;
		
	} else if([[filePath pathExtension] compare:@"savedSearch" options:NSCaseInsensitiveSearch] == NSOrderedSame){
		mode=-1;
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1040
		if([NSObject respondsToSelector:@selector(finalize)]){
			mode=3;
			NSDictionary *doc = [NSDictionary dictionaryWithContentsOfFile:filePath];
			NSString *raw = [doc objectForKey:@"RawQuery"];
			NSArray *scope = [[doc objectForKey:@"SearchCriteria"] objectForKey:@"FXScopeArrayOfPaths"];
			
			MDQueryRef query = MDQueryCreate(kCFAllocatorDefault, (CFStringRef)raw, NULL, NULL);
			MDQuerySetSearchScope (query,(CFArrayRef)scope,0);
			
			MDQueryExecute(query, kMDQuerySynchronous);
			
			CFIndex count = MDQueryGetResultCount(query);
			int i;
			NSMutableArray *temp = [NSMutableArray array];
			for (i = 0; i < count; i++) {
				MDItemRef item = (MDItemRef)MDQueryGetResultAtIndex(query,i);
				CFStringRef itemPath = MDItemCopyAttribute(item,kMDItemPath);
				
				BOOL isDir;
				[[NSFileManager defaultManager] fileExistsAtPath:((NSString *) itemPath) isDirectory:&isDir];
				if (isDir && readSubFolder) {
					NSArray *ar = [[NSFileManager defaultManager] subpathsAtPath:((NSString *) itemPath)];
					int ii;
					for (ii=0; ii<[ar count]; ii++) {
						[temp addObject:[((NSString *) itemPath) stringByAppendingPathComponent:[ar objectAtIndex:ii]]];
					}
				} else {
					[temp addObject:((NSString *) itemPath)];
				} 
				CFRelease(itemPath);
			}
			CFRelease(query);
			NSArray *completeArray;
			completeArray = [temp pathsMatchingExtensions:filterArray];
			
			NSEnumerator *enu=[completeArray objectEnumerator];
			id path;
			while (path = [enu nextObject]) {
				if([[COImageLoader fileTypes] containsObject:[[path pathExtension] lowercaseString]]){
					COImageLoader *inLoader = [[[COImageLoader alloc] initWithPath:path readSubFolder:NO controller:controller] autorelease];
					[pathArray addObjectsFromArray:[inLoader pathArray]];
					[inArchiveArray addObject:inLoader];
				} else if (path) {
					[pathArray addObject:path];
				}
			}
			[contentPathArray addObjectsFromArray:pathArray];
		}
#endif
	} else {
		mode=0;
		BOOL isDir;
		[[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir];
		if (isDir) {
			NSArray *completeArray;
			if (readSubFolder) {
				completeArray = [NSArray arrayWithArray:[[NSFileManager defaultManager] subpathsAtPath:filePath]];
			} else {
                completeArray = [NSArray arrayWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:filePath error:nil]];
			}
			completeArray = [completeArray pathsMatchingExtensions:filterArray];
			
			NSEnumerator *enu=[completeArray objectEnumerator];
			id path;
			while (path = [enu nextObject]) {
				path = [filePath stringByAppendingPathComponent:path];
				if([[COImageLoader fileTypes] containsObject:[[path pathExtension] lowercaseString]]){
					COImageLoader *inLoader = [[[COImageLoader alloc] initWithPath:path readSubFolder:NO controller:controller] autorelease];
					[pathArray addObjectsFromArray:[inLoader pathArray]];
					[inArchiveArray addObject:inLoader];
				} else if (path) {
					[pathArray addObject:path];
				}
			}
			[contentPathArray addObjectsFromArray:pathArray];
		} else {
			mode=-1;
		}
	}
	[contentPathArray sortUsingSelector:@selector(finderCompareS:)];
}

- (BOOL)checkArchiveContainer:(int)index
{
	if ([[archiveContainer contents] count] == 0) {
        return NO;
	}
	if ([[[archiveContainer contents] objectAtIndex:index] path] == nil) {
		if (password) [archiveContainer setPassword:password];
	}
	
	if (![self checkPassword]) [controller askForPassword:self];	//pass聞きに行く
	if (![self checkPassword]) return NO;	//諦めた
	
	if ([self crypted] && !rightPassward) {
		NSData* tempData = [[[archiveContainer contents] objectAtIndex:index] data];
		//tempData = nil;
		if (!tempData || [tempData length]<=0 || [[[archiveContainer contents] objectAtIndex:0] path]==nil) {
			if (mode == 2) {
				if (![[archiveContainer errorDescription] length]) {
					rightPassward = YES;
				}
			}
			if (!rightPassward || [[[archiveContainer contents] objectAtIndex:index] path]==nil) {
				//NSLog(@"noPassArchive_no");
				mode = -1;
				return NO;
			}
		}
	}
	
	[rawContentPathArray removeAllObjects];
	[contentPathArray removeAllObjects];
	[contentPathDic removeAllObjects];

	NSMutableArray *pathArray = [NSMutableArray array];
	NSArray *items=[archiveContainer contents];
	NSEnumerator *enu = [items objectEnumerator];
	id object;
	while (object = [enu nextObject]) {
		NSString *path = [object path];
		if (path) {
			[rawContentPathArray addObject:path];
			if([[COImageLoader fileTypes] containsObject:[[path pathExtension] lowercaseString]]){
				if ([self checkPassword]) {
					if (![self uncompressToTempDir:path]) {
						return NO;
					}
					COImageLoader *inLoader = [[[COImageLoader alloc] initWithPath:[tempDir stringByAppendingPathComponent:path]
																	   displayPath:[displayPath stringByAppendingPathComponent:path]
																	 readSubFolder:NO
																		controller:controller] autorelease];
					[inLoader setInTempDir:YES];
					[pathArray addObjectsFromArray:[inLoader pathArray]];
					[inArchiveArray addObject:inLoader];
				}
			} else {
				NSString *inPath = [NSString stringWithFormat:@"%@/%@",displayPath,path];
				[pathArray addObject:inPath];
				[contentPathDic setObject:path forKey:inPath];
			}
		} else {
		}
	}
	
	
	
	[contentPathArray addObjectsFromArray:[pathArray pathsMatchingExtensions:filterArray]];
	[contentPathArray sortUsingSelector:@selector(finderCompareS:)];
	//NSLog(@"%@",contentPathDic);
	return YES;
}

- (BOOL)uncompressToTempDir:(NSString*)fileName
{
	if (!tempDir) {
		NSFileManager *manager = [NSFileManager defaultManager];
		NSString *basePath = [NSTemporaryDirectory() stringByStandardizingPath];
		for (NSUInteger attempt = 0; attempt < 8 && !tempDir; attempt++) {
			NSString *candidate = [basePath stringByAppendingPathComponent:
				[NSString stringWithFormat:@"cooViewer-%@", [[NSProcessInfo processInfo] globallyUniqueString]]];
			if ([manager createDirectoryAtPath:candidate
					withIntermediateDirectories:NO
					attributes:nil
					error:nil]) {
				tempDir = [candidate retain];
			}
		}
	}
	if (!tempDir || mode != 2) return NO;

	NSUInteger rawIndex = [rawContentPathArray indexOfObject:fileName];
	if (rawIndex == NSNotFound) return NO;
	return [archiveContainer uncompress:(int)rawIndex toTempDir:tempDir];
}
@end
