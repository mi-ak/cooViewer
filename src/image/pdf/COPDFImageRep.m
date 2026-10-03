

#import "COPDFImageRep.h"


@implementation COPDFImageRep

-(id)init
{
	self = [super init];
    if (self) {
		linkList = nil;
	}
	return self;
}

- (void)dealloc
{
	if (linkList) {
		[linkList release];
	}
	[super dealloc];
}

- (BOOL)drawInRect:(NSRect)rect
{
	[[NSColor whiteColor] set];
	NSRectFill(rect);
	return [super drawInRect:rect];
}

- (BOOL)drawInRect:(NSRect)dstSpacePortionRect fromRect:(NSRect)srcSpacePortionRect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(nullable NSDictionary *)hints
{
    [[NSColor whiteColor] set];
    NSRectFill(dstSpacePortionRect);
    return [super drawInRect:dstSpacePortionRect fromRect:srcSpacePortionRect operation:NSCompositingOperationSourceOver fraction:requestedAlpha respectFlipped:respectContextIsFlipped hints:hints];
}

-(NSInteger)pixelsWide {return [self size].width;}
-(NSInteger)pixelsHigh{return [self size].height;}

+ (instancetype)imageRepWithContentsOfFile:(NSString *)filename
{
	NSData *data = [NSData dataWithContentsOfFile:filename options:NSDataReadingMappedIfSafe error:nil];
	return [self imageRepWithData:data];
}

+ (instancetype)imageRepWithData:(NSData *)data
{
	if (!data) return nil;
	COPDFImageRep *rep = [[[self alloc] initWithData:data] autorelease];
	if (!rep) return nil;
	PDFDocument *pdf = [[[PDFDocument alloc] initWithData:data] autorelease];
	if (pdf && ![pdf isLocked]) {
		PDFPage		*page;
		NSArray		*annotations;
		
		NSMutableArray *tmpArray = [[NSMutableArray alloc] init];
		int pageIndex;
		for (pageIndex = 0; pageIndex < [pdf pageCount]; pageIndex++) {
			NSMutableArray *tmpTmpArray = [[NSMutableArray alloc] init];
			page = [pdf pageAtIndex: pageIndex];
			
			// Get page annotations (if any).
			annotations = [page annotations];
			if ((annotations != NULL) && ([annotations count] > 0)) {
				unsigned int	count;
				unsigned int	i;
				
				// Walk annotations looking for links.
				count = (int)[annotations count];
				for (i = 0; i < count; i++)
				{
					PDFAnnotation	*oneAnnotation;
					
					// Link must have a URL associated with it.
					oneAnnotation = [annotations objectAtIndex: i];
					if (([[oneAnnotation type] isEqualToString: @"Link"]) && 
						([oneAnnotation URL] != NULL))
					{
						[tmpTmpArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												[NSValue valueWithRect:[oneAnnotation bounds]],@"rect",
												[oneAnnotation URL],@"url",
												nil]];
					}
				}
			}
			[tmpArray addObject:tmpTmpArray];
			[tmpTmpArray release];
		}
		[rep setLinkList:tmpArray];
		[tmpArray release];
	}
	
	return rep;
}

-(void)setLinkList:(NSArray*)array;
{
	[linkList release];
	linkList = [array retain];
}

-(NSArray*)linkListAtPage:(int) p
{
	if (p < 0 || p >= [linkList count]) return nil;
	return [linkList objectAtIndex:p];
}
@end
