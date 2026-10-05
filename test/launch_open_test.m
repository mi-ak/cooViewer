#import "Controller.h"

static void Require(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface LaunchTestDefaults : NSObject
@property BOOL restoreLastBook;
@end

@implementation LaunchTestDefaults
- (BOOL)boolForKey:(NSString *)key
{
    return [key isEqualToString:@"OpenLastFolder"] && self.restoreLastBook;
}
@end

@interface LaunchTestWindow : NSObject
@property (getter=isVisible) BOOL visible;
@end

@implementation LaunchTestWindow
@end

@interface LaunchTestImageView : NSObject
- (void)setDragScroll:(NSArray *)bindings mode:(int)mode;
@end

@implementation LaunchTestImageView
- (void)setDragScroll:(NSArray *)bindings mode:(int)mode
{
}
@end

// Exercise the real launch callbacks without opening windows or changing preferences.
@interface LaunchTestController : Controller
@property (readonly) NSArray *openedBooks;
@property BOOL failOpen;
- (id)initWithRestoreLastBook:(BOOL)restore;
- (void)setWindowVisible:(BOOL)visible;
@end

@implementation LaunchTestController
{
    NSMutableArray *_openedBooks;
}

- (id)initWithRestoreLastBook:(BOOL)restore
{
    self = [super init];
    if (self) {
        LaunchTestDefaults *testDefaults = [[LaunchTestDefaults alloc] init];
        testDefaults.restoreLastBook = restore;
        defaults = (id)testDefaults;
        window = [[LaunchTestWindow alloc] init];
        imageView = (id)[[LaunchTestImageView alloc] init];
        keyArray = [[NSMutableArray alloc] init];
        _openedBooks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray *)openedBooks
{
    return _openedBooks;
}

- (void)setWindowVisible:(BOOL)visible
{
    [(LaunchTestWindow *)window setVisible:visible];
}

- (void)openTheLastPage:(id)sender
{
    [_openedBooks addObject:@"previous-book"];
    [self setWindowVisible:YES];
}

- (void)setCurrentBookPathAndOldBookPath:(NSString *)filename
{
    [currentBookPath release];
    currentBookPath = [filename copy];
}

- (void)openPage:(int)page last:(BOOL)last
{
    [_openedBooks addObject:currentBookPath];
    [self setWindowVisible:!self.failOpen];
}

- (void)dealloc
{
    [defaults release];
    [window release];
    [imageView release];
    [keyArray release];
    [currentBookPath release];
    [_openedBooks release];
    [super dealloc];
}
@end

int main(void)
{
    @autoreleasepool {
        LaunchTestController *lateFile = [[LaunchTestController alloc] initWithRestoreLastBook:YES];
        [lateFile applicationDidFinishLaunching:nil];
        Require([lateFile.openedBooks count] == 0,
                @"launch completion does not show history before a pending file request");
        [lateFile application:nil openFile:@"requested.cbz"];
        Require([lateFile.openedBooks isEqualToArray:@[@"requested.cbz"]],
                @"an archive requested after launch is the only book opened");
        Require(![lateFile applicationOpenUntitledFile:nil],
                @"an explicit request suppresses automatic history restoration");
        [lateFile release];

        LaunchTestController *earlyFile = [[LaunchTestController alloc] initWithRestoreLastBook:YES];
        [earlyFile application:nil openFile:@"requested.heic"];
        [earlyFile applicationDidFinishLaunching:nil];
        Require([earlyFile.openedBooks isEqualToArray:@[@"requested.heic"]],
                @"a file requested before launch completion is opened directly");
        [earlyFile release];

        LaunchTestController *plain = [[LaunchTestController alloc] initWithRestoreLastBook:YES];
        Require([plain applicationShouldOpenUntitledFile:nil],
                @"launch without a file permits restoring the last book");
        Require([plain applicationOpenUntitledFile:nil], @"plain launch restores a book");
        [plain applicationDidFinishLaunching:nil];
        Require([plain.openedBooks isEqualToArray:@[@"previous-book"]],
                @"plain launch restores history exactly once");
        Require(![plain applicationOpenUntitledFile:nil], @"a visible book is not replaced");
        [plain release];

        LaunchTestController *disabled = [[LaunchTestController alloc] initWithRestoreLastBook:NO];
        [disabled applicationDidFinishLaunching:nil];
        Require(![disabled applicationShouldOpenUntitledFile:nil] &&
                ![disabled applicationOpenUntitledFile:nil] && [disabled.openedBooks count] == 0,
                @"disabling last-book restoration leaves a plain launch empty");
        [disabled release];

        LaunchTestController *failed = [[LaunchTestController alloc] initWithRestoreLastBook:YES];
        failed.failOpen = YES;
        [failed application:nil openFile:@"unreadable.zip"];
        [failed applicationDidFinishLaunching:nil];
        Require(![failed applicationShouldOpenUntitledFile:nil] &&
                ![failed applicationOpenUntitledFile:nil],
                @"an unreadable explicit file does not restore unrelated history");
        Require([failed.openedBooks isEqualToArray:@[@"unreadable.zip"]],
                @"only the explicit file is attempted even when opening fails");
        [failed release];
    }
    NSLog(@"Launch file selection tests passed.");
    return 0;
}
