#import <Cocoa/Cocoa.h>

@class CustomImageView;

@interface CustomWindow : NSWindow
{
    IBOutlet id controller;
    IBOutlet id target;
    IBOutlet CustomImageView *view;
}
- (BOOL)isFullScreen;
@end
