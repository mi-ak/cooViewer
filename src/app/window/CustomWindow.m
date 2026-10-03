#import "CustomWindow.h"
#import "CustomImageView.h"
#import "Controller.h"

@implementation CustomWindow

- (void)awakeFromNib
{
    [self setLevel:NSNormalWindowLevel];
    [self setAcceptsMouseMovedEvents:YES];
    [self setHidesOnDeactivate:NO];
    [self setCollectionBehavior:[self collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
    [self setFrameAutosaveName:@"NormalWindow"];
}

- (void)setFrame:(NSRect)windowFrame display:(BOOL)displayViews
{
    [super setFrame:windowFrame display:displayViews];
    [view setAccessoryWindowFrame];
}

- (BOOL)isFullScreen
{
    return ([self styleMask] & NSWindowStyleMaskFullScreen) != 0;
}

- (void)keyDown:(NSEvent *)event
{
    if ([self isFullScreen]) [NSCursor setHiddenUntilMouseMoves:YES];
    [controller keyAction:event];
}

- (void)mouseMoved:(NSEvent *)event
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCursorAfterInactivity) object:nil];
    if ([self isFullScreen]) [self performSelector:@selector(hideCursorAfterInactivity) withObject:nil afterDelay:3];
    [view mouseMoved:event];
}

- (void)hideCursorAfterInactivity
{
    if ([self isFullScreen] && [self isKeyWindow]) [NSCursor setHiddenUntilMouseMoves:YES];
}

@end
