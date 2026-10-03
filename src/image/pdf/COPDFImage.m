

#import "COPDFImage.h"


@implementation COPDFImage

-(id)initWithPDFRep:(COPDFImageRep*)rep page:(int)p
{
	self = [super init];
    if (self) {
		if (!rep || p < 0 || p >= [rep pageCount]) {
			[self release];
			return nil;
		}
		// NSPDFImageRep stores the selected page as mutable state. Each image
		// needs its own rep because thumbnails and page prefetch render in parallel.
		pdfRep = [[COPDFImageRep alloc] initWithData:[rep PDFRepresentation]];
		if (!pdfRep || p >= [pdfRep pageCount]) {
			[self release];
			return nil;
		}
		[pdfRep setCurrentPage:p];
		linkList = nil;
		
		image = [[NSImage alloc] initWithSize:[pdfRep size]];
		[image addRepresentation:pdfRep];
		[self setLinkList:[rep linkListAtPage:p]];
	}
	return self;
}

- (void)dealloc
{
	if (linkList) {
		[linkList release];
	}
	[image release];
	[pdfRep release];
	[super dealloc];
}

- (NSArray *)representations
{
	return [NSArray arrayWithObject:pdfRep];
}

- (void)setSize:(NSSize)aSize
{
	return;
}

- (NSSize)size
{
	return [pdfRep size];
}

- (void)drawInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(CGFloat)delta
{
	//[pdfRep drawInRect:dstRect];
	if (NSEqualSizes([pdfRep size],srcRect.size) || NSIsEmptyRect(srcRect)) {
		[pdfRep drawInRect:dstRect];
	} else {
		float rate = dstRect.size.width/srcRect.size.width;
		[image setSize:NSMakeSize((int)([pdfRep size].width*rate),(int)([pdfRep size].height*rate))];
		NSRect fromRect = NSMakeRect((int)(srcRect.origin.x*rate),(int)(srcRect.origin.y*rate),(int)srcRect.size.width*rate,(int)srcRect.size.height*rate);
		[image drawInRect:dstRect fromRect:fromRect operation:op fraction:delta];
	}
}

- (void)drawAtPoint:(NSPoint)point fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(CGFloat)delta
{
    [image setSize:[pdfRep size]];
	[image drawAtPoint:point fromRect:srcRect operation:op fraction:delta];
}


-(void)setLinkList:(NSArray*)array
{
	linkList = [array retain];
}

-(NSArray*)linkList
{
	return linkList;
}


@end
