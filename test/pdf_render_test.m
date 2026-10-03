#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import "COPDFImage.h"
#import "COImageLoader.h"

static void Require(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static BOOL DrawsExpectedPage(COPDFImage *image, BOOL shouldBeRed)
{
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:200 pixelsHigh:300 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
        isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [image drawInRect:NSMakeRect(0, 0, 200, 300)
            fromRect:NSMakeRect(0, 0, 200, 300)
           operation:NSCompositingOperationSourceOver fraction:1.0];
    [context flushGraphics];
    [NSGraphicsContext restoreGraphicsState];

    NSColor *center = [[bitmap colorAtX:100 y:150] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
    return center && (shouldBeRed ? [center redComponent] > 0.9 : [center redComponent] < 0.1);
}

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Require(argc == 3, @"PDF fixture paths");
    NSString *path = [NSString stringWithUTF8String:argv[1]];
    COImageLoader *loader = [[COImageLoader alloc] initWithPath:path readSubFolder:NO controller:nil];
    Require([loader mode] == 4 && [loader itemCount] == 2, @"two PDF pages load");

    COPDFImage *first = [[loader itemAtIndex:0] retain];
    COPDFImage *second = [[loader itemAtIndex:1] retain];
    Require(first && second, @"both page images load");
    Require([[first representations] objectAtIndex:0] != [[second representations] objectAtIndex:0],
            @"pages have independent PDF representations");
    Require(DrawsExpectedPage(first, NO), @"first page renders black");
    Require(DrawsExpectedPage(second, YES), @"second page renders red");

    __block int wrongPages = 0;
    dispatch_apply(200, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        NSAutoreleasePool *threadPool = [[NSAutoreleasePool alloc] init];
        BOOL red = index % 2 != 0;
        if (!DrawsExpectedPage(red ? second : first, red)) {
            __sync_fetch_and_add(&wrongPages, 1);
        }
        [threadPool drain];
    });
    Require(wrongPages == 0, @"parallel rendering keeps each page's content");

    COImageLoader *invalid = [[COImageLoader alloc] initWithPath:[NSString stringWithUTF8String:argv[2]]
        readSubFolder:NO controller:nil];
    Require([invalid mode] < 0, @"invalid PDF is rejected before page rendering");

    NSString *protectedPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"protected.pdf"];
    PDFDocument *source = [[[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]] autorelease];
    Require([source writeToURL:[NSURL fileURLWithPath:protectedPath] withOptions:
        [NSDictionary dictionaryWithObjectsAndKeys:@"owner", PDFDocumentOwnerPasswordOption,
            @"1234", PDFDocumentUserPasswordOption, nil]], @"password-protected PDF fixture is created");
    COImageLoader *protectedLoader = [[COImageLoader alloc] initWithPath:protectedPath
        readSubFolder:NO controller:nil];
    Require([protectedLoader mode] == 4 && [protectedLoader itemCount] == 2 && [protectedLoader crypted],
            @"protected PDF pages are detected");
    Require(![protectedLoader checkPassword], @"protected PDF starts locked");
    Require(![protectedLoader checkAndSetPassword:@"wrong"], @"wrong password is rejected");
    Require([protectedLoader checkAndSetPassword:@"1234"], @"correct password unlocks the PDF");
    Require(DrawsExpectedPage([protectedLoader itemAtIndex:0], NO), @"unlocked first page renders black");
    Require(DrawsExpectedPage([protectedLoader itemAtIndex:1], YES), @"unlocked second page renders red");
    PDFDocument *stillProtected = [[[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:protectedPath]] autorelease];
    Require([stillProtected isLocked], @"source PDF remains protected on disk");

    [protectedLoader release];
    [invalid release];
    [first release];
    [second release];
    [loader release];
    [pool drain];
    NSLog(@"PDF page rendering tests passed.");
    return 0;
}
