#import "ThumbnailPanel.h"

@implementation ThumbnailPanel
//-(BOOL)canBecomeKeyWindow{return YES;}
-(void)awakeFromNib
{
	[self setAcceptsMouseMovedEvents:YES];
	[self setCollectionBehavior:[self collectionBehavior] | NSWindowCollectionBehaviorFullScreenAuxiliary];
	[self makeFirstResponder:matrix];
}

- (void)setTarget:(ThumbnailController *)tar
{
	target = tar;
}

- (void)setAction:(SEL)sel
{
	selector = sel;
}
/*
- (void)mouseMoved:(NSEvent *)theEvent
{
	[super mouseMoved:theEvent];
	NSLog(@"kita0");
}
*/
-(void)resignKeyWindow
{
	//[self performClose:self];
	[super resignKeyWindow];
}


-(NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)aScreen
{
	NSScreen *screen = aScreen ?: [NSScreen mainScreen];
	return [super constrainFrameRect:[screen visibleFrame] toScreen:screen];
}



- (void)performClose:(id)sender
{
	[super performClose:sender];
	[target performSelector:@selector(clearCell)];
}

- (void)sendEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSEventTypeKeyDown) {
		[target performSelector:@selector(action:) withObject:theEvent];
	} else {
		[super sendEvent:theEvent];
	}
}
/*
- (void)keyDown:(NSEvent *)theEvent
{
	NSLog(@"kita");
	[target performSelector:@selector(action:) withObject:theEvent];
}*/



- (void)scrollWheel:(NSEvent *)theEvent
{
	if (setting == 0) {
		return;
	}
	[target performSelector:@selector(wheelAction:) withObject:theEvent];
}

-(void)wheelSetting:(float)set
{
	setting = set;
}

@end
