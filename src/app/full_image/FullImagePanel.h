
#import <Cocoa/Cocoa.h>

@class Controller;


@interface FullImagePanel : NSPanel {
	id keyArray;
	Controller *target;
	BOOL fitMode;
}
- (void)setFitMode:(BOOL)yes;
-(void)setSelfMaxSize;
- (void)setPageKey:(NSArray *)array;
@end
