#import "COArchivedSettings.h"
#import "COFileBookmarks.h"
#import "Controller.h"
#import "COImageLoader.h"
#import "PreferenceController.h"
#import "NSString_Compare.h"
#import <Quartz/Quartz.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "CustomWindow.h"
#import "BookmarkController.h"
#import "CustomImageView.h"
#import "ThumbnailController.h"
#import "FullImagePanel.h"

@implementation Controller
static const int DIALOG_OK		= 128;
static const int DIALOG_CANCEL	= 129;

static BOOL COConfirmAction(NSString *title, NSString *message)
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:title];
	[alert setInformativeText:message];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
	return [alert runModal] == NSAlertFirstButtonReturn;
}

- (void)endSlideshowActivity
{
	if (slideshowActivity) {
		[[NSProcessInfo processInfo] endActivity:slideshowActivity];
		[slideshowActivity release];
		slideshowActivity = nil;
	}
}

/*
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[lock lock];
	
	[lock unlock];
	[pool release];
	[NSThread exit];
 
 
 [NSThread detachNewThreadSelector:@selector(lookaheadThread) toTarget:self withObject:nil];
	*/

/*
 NSTimeInterval start,stop,elapsed;
 start=[NSDate timeIntervalSinceReferenceDate];
 //処理
 stop=[NSDate timeIntervalSinceReferenceDate];
 elapsed=stop-start;
 NSLog(@"%f",elapsed);
 */

-(void)awakeFromNib
{	
	threadCount = 0;
	imageLoader = nil;
	wheelUpTimer = nil;
	wheelDownTimer = nil;
	
	lock = [[NSLock allocWithZone:NULL] init];
	//lock = [[NSConditionLock allocWithZone:NULL] initWithCondition:0];
	//composeLock = [[NSLock allocWithZone:NULL] init];
	
	[imageView setTarget:self];
	
	
	
	defaults = [NSUserDefaults standardUserDefaults];	
	
#pragma mark default
	BOOL openLastFolder;
	BOOL fullscreen;
	
	NSMutableDictionary *appDefault = [NSMutableDictionary dictionary];
	
	if([NSObject respondsToSelector:@selector(finalize)]){
		bufferingMode = 1;
		[appDefault setObject:[NSNumber numberWithInt:bufferingMode] forKey:@"BufferingMode"];
	}
	openLastFolder = YES;
	fullscreen = YES;
	wheelSensitivity = 1.0;
	
	[appDefault setObject:[NSNumber numberWithBool:openLastFolder] forKey:@"OpenLastFolder"];
	[appDefault setObject:[NSNumber numberWithBool:fullscreen] forKey:@"Fullscreen"];

	[appDefault setObject:[NSNumber numberWithFloat:wheelSensitivity] forKey:@"WheelSensitivity"];
	
	[appDefault setObject:[NSNumber numberWithInt:0] forKey:@"PrevPageMode"];
	[appDefault setObject:[NSNumber numberWithInt:0] forKey:@"CanScrollMode"];
	[appDefault setObject:[NSNumber numberWithInt:2] forKey:@"PrevPagePageBarPositionMode"];
		
	[appDefault setObject:[NSNumber numberWithBool:YES] forKey:@"ShowPageBar"];
	[appDefault setObject:[NSNumber numberWithBool:YES] forKey:@"ShowNumber"];
	
	[appDefault setObject:[NSNumber numberWithInt:10] forKey:@"OpenRecentLimit"];
	
	[defaults registerDefaults:appDefault];
	[defaults removeObjectForKey:@"ChangeCreator"];
	[defaults removeObjectForKey:@"ChangeOpenWith"];
	[defaults removeObjectForKey:@"DontHideMenuBar"];
	restoreFullscreenOnNextKey = [defaults boolForKey:@"Fullscreen"];
	
	fitScreenMode = 0;
	rotateMode=0;
	
	if (![defaults arrayForKey:@"KeyArray"]) [PreferenceController setDefaultKeyArray];
	if (![defaults arrayForKey:@"KeyArrayMode2"]) [PreferenceController setDefaultKeyArrayMode2];
	if (![defaults arrayForKey:@"KeyArrayMode3"]) [PreferenceController setDefaultKeyArrayMode3];
	[PreferenceController removeLegacyRemoteBindings];
	keyArray = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"KeyArray"]];
	keyArrayMode2 = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"KeyArrayMode2"]];
	keyArrayMode3 = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"KeyArrayMode3"]];
	
	if (![defaults arrayForKey:@"MouseArray"]) [PreferenceController setDefaultMouseArray];
	if (![defaults arrayForKey:@"MouseArrayMode2"]) [PreferenceController setDefaultMouseArrayMode2];
	if (![defaults arrayForKey:@"MouseArrayMode3"]) [PreferenceController setDefaultMouseArrayMode3];
	mouseArray = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"MouseArray"]];
	mouseArrayMode2 = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"MouseArrayMode2"]];
	mouseArrayMode3 = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"MouseArrayMode3"]];
	
	
	int skipPage = (int)[defaults integerForKey:@"SkipPage"];
	if (skipPage == 0) {
		skipPage = 10;
	}
	
	NSEnumerator *enu = [keyArray objectEnumerator];
	id dic;
	id newDic;
	while (dic = [enu nextObject]) {
		if (![dic valueForKey:@"value"]) {
			switch ([[dic objectForKey:@"action"] intValue]) {
				case 13: case 14:
					newDic = [NSMutableDictionary dictionaryWithDictionary:dic];
					[newDic setObject:[NSNumber numberWithInt:skipPage] forKey:@"value"];
					[keyArray replaceObjectAtIndex:[keyArray indexOfObject:dic] withObject:newDic];
					break;
				default:
					break;
			}
		}
	}
	[defaults setObject:keyArray forKey:@"KeyArray"];
	enu = [mouseArray objectEnumerator];
	while (dic = [enu nextObject]) {
		if (![dic valueForKey:@"value"]) {
			switch ([[dic objectForKey:@"action"] intValue]) {
				case 5: case 19: case 20:
					newDic = [NSMutableDictionary dictionaryWithDictionary:dic];
					[newDic setObject:[NSNumber numberWithInt:skipPage] forKey:@"value"];
					[mouseArray replaceObjectAtIndex:[mouseArray indexOfObject:dic] withObject:newDic];
					break;
				default:
					break;
			}
		}
	}
	[defaults setObject:mouseArray forKey:@"MouseArray"];
	
#pragma mark normal
	 if (![defaults dictionaryForKey:@"BookSettings"]) {
		 [defaults setObject:[NSMutableDictionary dictionary] forKey:@"BookSettings"];
	 }
	 //bookSettings = [[NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"BookSettings"]] retain];
	 if (![defaults arrayForKey:@"RecentItems"]) {
		 [defaults setObject:[NSMutableArray array] forKey:@"RecentItems"];
	 }
	 //recentItems = [[NSMutableArray arrayWithArray:[defaults arrayForKey:@"BookSettings"]] retain];
		 
	 
	interpolation = (int)[defaults integerForKey:@"Interpolation"];
	[imageView setInterpolation:interpolation];
	[defaults setInteger:interpolation forKey:@"Interpolation"];
    BOOL useCalayer = [defaults boolForKey:@"UseCALayer"];
    [imageView setUseCalayer:useCalayer];
    [defaults setBool:useCalayer forKey:@"UseCALayer"];
	
	
	cacheSize = (int)[defaults integerForKey:@"ImageCache"];
	[defaults setInteger:cacheSize forKey:@"ImageCache"];
	screenCache = (int)[defaults integerForKey:@"ScreenCache"];
	[defaults setInteger:screenCache forKey:@"ScreenCache"];
	int thumbnailCache = (int)[defaults integerForKey:@"ThumbnailCache"];
	[defaults setInteger:thumbnailCache forKey:@"ThumbnailCache"];
	
	/*history*/
	alwaysRememberLastPage = [defaults boolForKey:@"AlwaysRememberLastPage"];
	[defaults setBool:alwaysRememberLastPage forKey:@"AlwaysRememberLastPage"];
	
	goToLastPageMode = (int)[defaults integerForKey:@"GoToLastPage"];
	[defaults setInteger:goToLastPageMode forKey:@"GoToLastPage"];
	openRecentLimit = (int)[defaults integerForKey:@"OpenRecentLimit"];
	
	/*loupe*/
	int loupeSize = (int)[defaults integerForKey:@"LoupeSize"];
	if (!loupeSize) loupeSize = 150;
	[defaults setInteger:loupeSize forKey:@"LoupeSize"];
	float loupeRate = [defaults floatForKey:@"LoupeRate"];
	if (!loupeRate) loupeRate = 1.0;
	[defaults setFloat:loupeRate forKey:@"LoupeRate"];
	/*view*/
	NSColor *viewBackGround;
	if ([defaults objectForKey:@"ViewBackGroundColor"]) {
		viewBackGround = COReadArchivedSetting(defaults, @"ViewBackGroundColor", [NSColor class]);
	} else {
		viewBackGround = [NSColor blackColor];
	}
	if (!viewBackGround) viewBackGround = [NSColor blackColor];
	[window setBackgroundColor:viewBackGround];
    viewBackGround = [viewBackGround colorWithAlphaComponent:1];

	fullscreen = [defaults boolForKey:@"Fullscreen"];
	
	
	
	
	bufferingMode = (int)[defaults integerForKey:@"BufferingMode"];
	[defaults setInteger:bufferingMode forKey:@"BufferingMode"];
	
	BOOL fitOriginal = [defaults boolForKey:@"FitOriginal"];
	[fullImagePanel setFitMode:fitOriginal];
	[defaults setBool:fitOriginal forKey:@"FitOriginal"];
	
	
	readMode = (int)[defaults integerForKey:@"ReadMode"];
	[defaults setInteger:readMode forKey:@"ReadMode"];
	

	
	
	rememberBookSettings = [defaults boolForKey:@"RememberBookSettings"];
	[defaults setBool:rememberBookSettings forKey:@"RememberBookSettings"];
	
	
	NSDictionary *thumbnail = [defaults dictionaryForKey:@"Thumbnail"];
	if (!thumbnail) thumbnail = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:2],@"row",[NSNumber numberWithInt:3],@"column",nil];
	
	[thumController setCellRow:[[thumbnail objectForKey:@"row"] intValue] 
						column:[[thumbnail objectForKey:@"column"] intValue]];
	[defaults setObject:thumbnail forKey:@"Thumbnail"];

	
	
	
	sliderValue = [defaults floatForKey:@"SlideshowDelay"];
	loopCheck = (int)[defaults integerForKey:@"LoopCheck"];
	
	
	pageBar = [defaults boolForKey:@"ShowPageBar"];
	if (![defaults dictionaryForKey:@"PageBarSize"]) {
		[defaults setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:200],@"width",[NSNumber numberWithInt:15],@"height",nil]
					 forKey:@"PageBarSize"];
	}
	
	numberSwitch = [defaults boolForKey:@"ShowNumber"];
	maxEnlargement = (int)[defaults integerForKey:@"MaxEnlargement"];
	
	
	singleSetting = (int)[defaults integerForKey:@"SingleSetting"];
	if (!singleSetting) {
		singleSetting = 740;
	}
	[defaults setInteger:singleSetting forKey:@"SingleSetting"];
	
	
	readSubFolder = [defaults boolForKey:@"ReadSubFolder"];
	
	wheelSensitivity = [defaults floatForKey:@"WheelSensitivity"];
		[imageView wheelSetting:wheelSensitivity];
		[thumController wheelSetting:wheelSensitivity];
	
	prevPageMode = (int)[defaults integerForKey:@"PrevPageMode"];
	canScrollMode = (int)[defaults integerForKey:@"CanScrollMode"];

	
	[defaults setFloat:sliderValue forKey:@"SlideshowDelay"];
	[defaults setFloat:wheelSensitivity forKey:@"WheelSensitivity"];
	
	[defaults setInteger:loopCheck forKey:@"LoopCheck"];
	[defaults setBool:numberSwitch forKey:@"ShowNumber"];
	[defaults setInteger:maxEnlargement forKey:@"MaxEnlargement"];
	[defaults setBool:fullscreen forKey:@"Fullscreen"];
	[defaults setBool:readSubFolder forKey:@"ReadSubFolder"];

	
	
	screenCacheArray = [[NSCache allocWithZone:NULL] init];
	[screenCacheArray setName:@"cooViewer.screenCache"];
	if (screenCache > 0) [screenCacheArray setCountLimit:(NSUInteger)(screenCache + 2)];
	cacheArray = [[NSCache allocWithZone:NULL] init];
	[cacheArray setName:@"cooViewer.imageCache"];
	if (cacheSize > 0) [cacheArray setCountLimit:(NSUInteger)(cacheSize + 4)];
	imageMutableArray = [[NSMutableArray allocWithZone:NULL] init];
	bookmarkArray = [[NSMutableArray allocWithZone:NULL] init];
	currentBookSetting = [[NSMutableDictionary allocWithZone:NULL] init];
	marksArray = [[NSMutableArray allocWithZone:NULL] init];
	openLastFolder = [defaults boolForKey:@"OpenLastFolder"];
	[defaults setBool:openLastFolder forKey:@"OpenLastFolder"];
	[self setOpenRecentMenu];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(viewDidEndLiveResize:) 
												 name:@"ViewDidEndLiveResize"
											   object:imageView];
    

    openLinkMode = (int)[defaults integerForKey:@"OpenLinkMode"];
	[defaults setInteger:openLinkMode forKey:@"OpenLinkMode"];

	changeCurrentFolderMode = (int)[defaults integerForKey:@"ChangeCurrentFolder"];
	[defaults setInteger:changeCurrentFolderMode forKey:@"ChangeCurrentFolder"];
	
	
	NSString *oldVersion = [defaults stringForKey:@"Version"];
	NSString *nowVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
#pragma mark only under 1.2b10
	if (![defaults stringForKey:@"Version"]) {
		if ([defaults dictionaryForKey:@"BookSettings"]) {
			NSMutableDictionary *newBookSettings = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"BookSettings"]];
			NSEnumerator *settingKeyEnu = [[defaults dictionaryForKey:@"BookSettings"] keyEnumerator];
			
			id settingKey;
			id setting;
			while (settingKey = [settingKeyEnu nextObject]) {
				setting = [newBookSettings objectForKey:settingKey];
				NSMutableDictionary *newSetting = [NSMutableDictionary dictionaryWithDictionary:setting];
				NSString *path = [self pathFromAliasData:[setting objectForKey:@"alias"]];
				if (path) [newSetting setObject:path forKey:@"temppath"];
				[newBookSettings setObject:newSetting forKey:settingKey];
			}
			[defaults setObject:newBookSettings forKey:@"BookSettings"];
		}
		
		if ([defaults arrayForKey:@"LastPages"]) {
			NSMutableArray *newLastPages = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"LastPages"]];
			
			NSEnumerator *enu = [[defaults arrayForKey:@"LastPages"] objectEnumerator];
			id object;
			while (object = [enu nextObject]) {
				int index = (int)[newLastPages indexOfObject:object];
				if ([[object objectForKey:@"page"] intValue] == 0) {
					[newLastPages removeObjectAtIndex:index];
				} else {
					NSMutableDictionary *newInnerDic = [NSMutableDictionary dictionaryWithDictionary:object];
					[newLastPages removeObjectAtIndex:index];
					NSString *path = [self pathFromAliasData:[object objectForKey:@"alias"]];
					if (path) [newInnerDic setObject:path forKey:@"temppath"];
					[newLastPages addObject:newInnerDic];
				}
			}
			[defaults setObject:newLastPages forKey:@"LastPages"];
		}
		
		if ([defaults arrayForKey:@"RecentItems"]) {
			NSMutableArray *newRecentItems = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentItems"]];
			
			NSEnumerator *enu = [[defaults arrayForKey:@"RecentItems"] objectEnumerator];
			id object;
			while (object = [enu nextObject]) {
				NSMutableDictionary *newInnerDic = [NSMutableDictionary dictionaryWithDictionary:object];
				int index = (int)[[defaults arrayForKey:@"RecentItems"] indexOfObject:object];
				[newRecentItems removeObjectAtIndex:index];
				NSString *path = [self pathFromAliasData:[object objectForKey:@"alias"]];
				if (path) [newInnerDic setObject:path forKey:@"temppath"];
				[newRecentItems insertObject:newInnerDic atIndex:index];
			}
			[defaults setObject:newRecentItems forKey:@"RecentItems"];
		}
		
	}
#pragma mark only under 1.2b14
	if ([@"1.2b14" versionCompare:oldVersion] == NSOrderedDescending && [defaults stringForKey:@"Version"]) {
		 NSArray *numericKeyArray = [[NSMutableArray alloc] initWithObjects:
			 [NSDictionary dictionaryWithObjectsAndKeys:
				 [NSNumber numberWithInt:39],@"action",@"0",@"keyname", [NSString stringWithFormat:@"0"],@"key",
				 [NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:0],@"value",
				 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"1",@"keyname", [NSString stringWithFormat:@"1"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:10],@"value",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"2",@"keyname", [NSString stringWithFormat:@"2"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:20],@"value",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"3",@"keyname", [NSString stringWithFormat:@"3"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:30],@"value",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"4",@"keyname", [NSString stringWithFormat:@"4"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:40],@"value",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"5",@"keyname", [NSString stringWithFormat:@"5"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:50],@"value",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"6",@"keyname", [NSString stringWithFormat:@"6"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:60],@"value",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"7",@"keyname", [NSString stringWithFormat:@"7"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:70],@"value",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"8",@"keyname", [NSString stringWithFormat:@"8"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:80],@"value",
				nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:39],@"action",@"9",@"keyname", [NSString stringWithFormat:@"9"],@"key",
				[NSNumber numberWithInt:0],@"modifier",[NSNumber numberWithInt:90],@"value",
				nil],
			 
				nil];
		 [keyArray addObjectsFromArray:numericKeyArray];
		 [defaults setObject:keyArray forKey:@"KeyArray"];
		 [numericKeyArray release];
		 
		 if ([defaults objectForKey:@"PageBarBGColor"]) {
			 NSColor *color = COReadArchivedSetting(defaults, @"PageBarBGColor", [NSColor class]);
			 if (color) COWriteArchivedSetting(defaults, @"PageBarBGColor", [color colorWithAlphaComponent:0.8]);
		 }
	}
	if ([@"1.2b17" versionCompare:oldVersion] == NSOrderedDescending && [defaults stringForKey:@"Version"]) {
		[mouseArray addObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:59],@"action",
				[NSNumber numberWithInt:1],@"button",
				[NSNumber numberWithInt:0],@"modifier",
				nil]];
		[mouseArray addObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:59],@"action",
				[NSNumber numberWithInt:0],@"button",
				[NSNumber numberWithInt:4],@"modifier",
				nil]];
		[defaults setObject:mouseArray forKey:@"MouseArray"];
	}
	if ([@"1.2b23" versionCompare:oldVersion] == NSOrderedDescending && [defaults stringForKey:@"Version"]) {
		NSArray *multiTouchMouseArray = [[NSMutableArray alloc] initWithObjects:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithInt:6],@"action",
		  [NSNumber numberWithInt:2000],@"button",
		  [NSNumber numberWithInt:0],@"modifier",
		  [NSNumber numberWithBool:YES],@"switchAction",
		  nil],
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithInt:7],@"action",
		  [NSNumber numberWithInt:1000],@"button",
		  [NSNumber numberWithInt:0],@"modifier",
		  [NSNumber numberWithBool:YES],@"switchAction",
		  nil],
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithInt:14],@"action",
		  [NSNumber numberWithInt:4000],@"button",
		  [NSNumber numberWithInt:0],@"modifier",
		  nil],
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithInt:15],@"action",
		  [NSNumber numberWithInt:3000],@"button",
		  [NSNumber numberWithInt:0],@"modifier",
		  nil],
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithInt:49],@"action",
		  [NSNumber numberWithInt:7000],@"button",
		  [NSNumber numberWithInt:0],@"modifier",
		  nil],
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithInt:50],@"action",
		  [NSNumber numberWithInt:8000],@"button",
		  [NSNumber numberWithInt:0],@"modifier",
		  nil],
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithInt:63],@"action",
		  [NSNumber numberWithInt:6000],@"button",
		  [NSNumber numberWithInt:0],@"modifier",
		  nil],
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithInt:64],@"action",
		  [NSNumber numberWithInt:5000],@"button",
		  [NSNumber numberWithInt:0],@"modifier",
		  nil],
		nil];
		[mouseArray addObjectsFromArray:multiTouchMouseArray];
		[defaults setObject:mouseArray forKey:@"MouseArray"];
	}
#pragma mark versionCompareTest
	//versionCompare_test
	//1.2b10〜
	/*
	NSString *plist = oldVersion;
	NSString *nowVer = nowVersion;
	plist = @"";
	nowVer = @"1.2b14";
	NSComparisonResult result = [nowVer versionCompare:plist];
	
	if (result == NSOrderedAscending) {
		NSLog(@"%@ %@ left is small",nowVer,plist);
	} else if (result == NSOrderedSame) {
		NSLog(@"%@ %@ equal",nowVer,plist);
	} else if (result == NSOrderedDescending) {
		NSLog(@"%@ %@ left is big",nowVer,plist);
	} else {
		NSLog(@"%@ %@ err",nowVer,plist);
	}*/
#pragma mark set Version
	if ([nowVersion versionCompare:oldVersion] == NSOrderedDescending) {
		//NSLog(@"%@ %@ left is big",nowVer,plist);
		[defaults setObject:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] forKey:@"Version"];
	}
	[self migrateStoredFileBookmarks];
	[imageView setPreferences];
}


 - (void)applicationDidFinishLaunching:(NSNotification *)notification
{		
	NSEnumerator *enu = [keyArray objectEnumerator];
	id object;
	NSMutableArray *array = [NSMutableArray arrayWithArray:keyArray];
	[fullImagePanel setPageKey:array];
	[thumController setPageKey:array];
	
	NSMutableArray *array2 = [NSMutableArray array];
	enu = [mouseArrayMode2 objectEnumerator];
	while (object = [enu nextObject]) {
		if ([[object objectForKey:@"action"] intValue] == 41) {
			[array2 addObject:object];
		}
	}
	[imageView setDragScroll:array2 mode:1];
	
	NSMutableArray *array3 = [NSMutableArray array];
	enu = [mouseArrayMode3 objectEnumerator];
	while (object = [enu nextObject]) {
		if ([[object objectForKey:@"action"] intValue] == 41) {
			[array3 addObject:object];
		}
	}
	[imageView setDragScroll:array3 mode:2];
	[imageView setDragScroll:array3 mode:3];
	
	if ([defaults boolForKey:@"OpenLastFolder"] == YES) {
		if (![window isVisible]) {
			[self openTheLastPage:self];
		}
	}
 }
 
#pragma mark openFromAny
- (IBAction)openTheLastPage:(id)sender
{
	if ([imageView image]) {
		int page;
		if ([defaults arrayForKey:@"RecentItems"]) {
			id object = [self searchFromRecentItems:currentBookPath index:nil];
			if (object) {
				if ([object objectForKey:@"page"]) {
					page = [[object objectForKey:@"page"] intValue];
					[self goTo:page array:nil];
					return;
				}
			}
		}
		if ([defaults arrayForKey:@"LastPages"]) {
			NSEnumerator *enu = [[defaults arrayForKey:@"LastPages"] objectEnumerator];
			id object;
			while (object = [enu nextObject]) {
				if ([COPathFromStoredEntry(object) isEqualToString:currentBookPath]) {
					page = [[object objectForKey:@"page"] intValue];
					[self goTo:page array:nil];
					return;
				}
			}
		}
	} else {
		for (NSDictionary *recent in [defaults arrayForKey:@"RecentItems"]) {
			NSString *path = COPathFromStoredEntry(recent);
			if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
				[self setCurrentBookPath:path];
				[self openPage:[[recent objectForKey:@"page"] intValue] last:NO];
				break;
			}
		}
	}
}


- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if (timerSwitch) {
		[timer invalidate];
		timerSwitch=NO;
		[self endSlideshowActivity];
	}
	
	[self setCurrentBookPathAndOldBookPath:filename];	
	
	[self openPage:0 last:NO];
	return YES;
}


-(IBAction)open:(id)sender
{
	if (timerSwitch) {
		[timer invalidate];
		timerSwitch=NO;
		[self endSlideshowActivity];
	}
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	int openPanelResult;
	
	[openPanel setCanChooseDirectories:YES];
	NSMutableArray *tempArray = [NSMutableArray arrayWithArray:[COImageLoader fileTypes]];
	[tempArray addObjectsFromArray:[COImageLoader imageFileTypes]];
	NSMutableArray *contentTypes = [NSMutableArray array];
	for (NSString *extension in tempArray) {
		UTType *type = [UTType typeWithFilenameExtension:[extension lowercaseString]];
		if (type && ![contentTypes containsObject:type]) [contentTypes addObject:type];
	}
	[openPanel setAllowedContentTypes:contentTypes];
	openPanelResult = (int)[openPanel runModal];
	
	if (openPanelResult == NSModalResponseCancel) {
		return;
	}
	if (openPanelResult == NSModalResponseOK) {
		if (timerSwitch) {
			[timer invalidate];
			timerSwitch=NO;
			[self endSlideshowActivity];
		}
		[self setCurrentBookPathAndOldBookPath:[[openPanel URL] path]];
		
		[self openPage:0 last:NO];
	}
}


-(void)openFromSameDir:(id)sender
{
	[self openFromSameDir:sender last:NO];
}

-(void)openFromSameDir:(id)sender last:(BOOL)isLast
{
	[self setCurrentBookPathAndOldBookPath:[sender representedObject]];
	
	[self openPage:0 last:isLast];
}


-(void)openFromOpenRecent:(id)sender
{	
	[self setCurrentBookPathAndOldBookPath:COPathFromStoredEntry([sender representedObject])];
	
	[self openPage:[[[sender representedObject] objectForKey:@"page"] intValue] last:NO];
}



#pragma mark openning
- (void)openPage:(int)page last:(BOOL)last;
{ 	
	[window makeKeyAndOrderFront:self];
	
	[progressIndicator startAnimation:self];
	[progressIndicator displayIfNeeded];
	
    /*
	[imageView lockFocus];
	NSRect rect = [[window contentView] convertRect:[progressIndicator frame] toView:imageView];
	rect = NSMakeRect(rect.origin.x-2,rect.origin.y-2,rect.size.width+4,rect.size.height+4);
	NSBezierPath *bezier = [NSBezierPath bezierPath];
	float rad = 10.0;
	[bezier appendBezierPathWithArcWithCenter:NSMakePoint(rect.origin.x+rad,rect.origin.y+rect.size.height-rad)
									   radius:rad startAngle:90 endAngle:180];
	[bezier appendBezierPathWithArcWithCenter:NSMakePoint(rect.origin.x+rad,rect.origin.y+rad)
									   radius:rad startAngle:180 endAngle:270];
	[bezier appendBezierPathWithArcWithCenter:NSMakePoint(rect.origin.x+rect.size.width-rad,rect.origin.y+rad)
									   radius:rad startAngle:270  endAngle:0];
	[bezier appendBezierPathWithArcWithCenter:NSMakePoint(rect.origin.x+rect.size.width-rad,rect.origin.y+rect.size.height-rad)
									   radius:rad startAngle:0 endAngle:90];
	[bezier closePath];
	[[[NSColor grayColor] colorWithAlphaComponent:0.8] set];
	[bezier fill];
	[imageView unlockFocus];
	[imageView displayIfNeeded];
    */
	

	NSString *fromFileName = nil;
	if ([[COImageLoader imageFileTypes] containsObject:[[currentBookPath pathExtension] lowercaseString]]) {
		if ([[currentBookPath pathExtension] compare:@"pdf" options:NSCaseInsensitiveSearch] != NSOrderedSame) {
			fromFileName = currentBookPath;
			[currentBookName release];
			[currentBookAlias release];
			[self setCurrentBookPath:[currentBookPath stringByDeletingLastPathComponent]];
		}
	}
	
	COImageLoader *newImageLoader = [[COImageLoader alloc] initWithPath:currentBookPath readSubFolder:readSubFolder controller:self];

	//NSLog(@"controller mode=%i count=%i",[newImageLoader mode],[newImageLoader itemCount]);
	if (!newImageLoader || ![newImageLoader checkPassword] || [newImageLoader mode] < 0 || [newImageLoader itemCount] < 1) {
		/*表示出来ない時は元に戻す*/
		[newImageLoader release];
		if ([imageView image]) {
			/*ウィンドウを開いているとき*/
			[currentBookPath release];
			[currentBookName release];
			[currentBookAlias release];
			currentBookPath = oldBookPath;
			currentBookName = oldBookName;
			currentBookAlias = oldBookAlias;
			[self setSameFolderMenu];
		} else {
			[currentBookPath release];
			[currentBookName release];
			[currentBookAlias release];
			currentBookPath = nil;
			currentBookName = nil;
			currentBookAlias = nil;
			[window performClose:self];
		}
		[progressIndicator stopAnimation:self];
		//[imageView displayRect:rect];
		return;
	} else if ([imageView image]) {
		/*ウィンドウを開いてたら準備する*/
		//currentBookPathではなくoldBookPath
		//currentBookNameではなくoldBookName
		//なことに注意する事！
		
		/*clear cache*/
		[cacheArray removeAllObjects];
		[screenCacheArray removeAllObjects];
		if (oldBookPath != nil) {
			NSData *aliasData = oldBookAlias;	
			
			/*bookmark&booksettings保存*/			
			NSMutableDictionary *dic;
			if (![defaults dictionaryForKey:@"BookSettings"]) {
				dic = [NSMutableDictionary dictionary];
			} else {
				dic = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"BookSettings"]];
			}
			id key;
			[self searchFromBookSettings:oldBookPath key:&key];
			
			[currentBookSetting setObject:aliasData forKey:@"alias"];
			[currentBookSetting setObject:oldBookPath forKey:@"temppath"];
			if ([bookmarkArray count]>0) {
				[currentBookSetting setObject:bookmarkArray forKey:@"bookmarks"];
			} else if ([bookmarkArray count]==0) {
				[currentBookSetting removeObjectForKey:@"bookmarks"];
			}
			if ([currentBookSetting count]>2) {
				if (!key) {
					key = oldBookName;
					int i = 2;
					while ([dic objectForKey:key]) {
						key = [NSString stringWithFormat:@"%@#%i",oldBookName,i];
						i++;
					}
					[dic setObject:currentBookSetting forKey:key];
				} else {
					[dic setObject:currentBookSetting forKey:key];
				}
				[defaults setObject:dic forKey:@"BookSettings"];
			}
	
			
			/*historyの処理*/			
			if (secondImage) {
				nowPage -= 2;
			} else {
				nowPage--;
			}
			NSNumber *pageNumber = [NSNumber numberWithInt:nowPage];
			if (openRecentLimit>0) {
				NSMutableArray *newRecentItems;
				if (![defaults arrayForKey:@"RecentItems"]) {
					newRecentItems = [NSMutableArray array];
				} else {
					newRecentItems = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentItems"]];
				}
				int index = 0;
				id object = [self searchFromRecentItems:oldBookPath index:&index];
				if (object) {
					[newRecentItems removeObjectAtIndex:index];
				}
				while ([newRecentItems count] >= openRecentLimit) {
					[newRecentItems removeLastObject];
				}
				[newRecentItems insertObject:[NSDictionary dictionaryWithObjectsAndKeys:aliasData,@"alias",pageNumber,@"page",oldBookPath,@"temppath",nil] atIndex:0];
				[defaults setObject:newRecentItems forKey:@"RecentItems"];
			} else {
				[defaults removeObjectForKey:@"RecentItems"];
			}
			if (alwaysRememberLastPage && nowPage > 0) {				
				NSMutableArray *lastPages;
				if (![defaults arrayForKey:@"LastPages"]) {
					lastPages = [NSMutableArray array];
				} else {
					lastPages = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"LastPages"]];
				}
				int index;
				id object = [self searchFromLastPages:oldBookPath index:&index];
				if (object) {
					[lastPages removeObjectAtIndex:index];
				}
				[lastPages addObject:[NSDictionary dictionaryWithObjectsAndKeys:aliasData,@"alias",pageNumber,@"page",oldBookPath,@"temppath",nil]];
				[defaults setObject:lastPages forKey:@"LastPages"];
			} else if (!alwaysRememberLastPage || nowPage == 0) {
				NSMutableArray *lastPages;
				if (![defaults arrayForKey:@"LastPages"]) {
					lastPages = [NSMutableArray array];
				} else {
					lastPages = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"LastPages"]];
				}
				int index;
				id object = [self searchFromLastPages:oldBookPath index:&index];
				if (object) {
					[lastPages removeObjectAtIndex:index];
				}
				[defaults setObject:lastPages forKey:@"LastPages"];
			}
		}
		
		[completeMutableArray release];
		completeMutableArray = nil;
		[imageMutableArray removeAllObjects];
		[bookmarkArray removeAllObjects];
		[currentBookSetting removeAllObjects];
		[imageLoader release];
	}
	[self setSameFolderMenu];
	if (oldBookPath != nil) {
		[oldBookPath release];
		[oldBookName release];
		[oldBookAlias release];
		oldBookPath = nil;
		oldBookName = nil;
		oldBookAlias = nil;
	}
	
	
	id tempCurrentBookSetting = [self searchFromBookSettings:currentBookPath key:nil more:YES];
	if (tempCurrentBookSetting) {
		[currentBookSetting setDictionary:tempCurrentBookSetting];
	}
	
	NSMutableArray *newRecentItems;
	if (![defaults arrayForKey:@"RecentItems"]) {
		newRecentItems = [NSMutableArray array];
	} else {
		newRecentItems = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentItems"]];
	}
	NSMutableArray *lastPages;
	if (![defaults arrayForKey:@"LastPages"]) {
		lastPages = [NSMutableArray array];
	} else {
		lastPages = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"LastPages"]];
	}
	NSData *aliasData = currentBookAlias;
	
	/*goto lastpage?*/
	if (goToLastPageMode<2 && !last && page == 0) {
		id object = [self searchFromRecentItems:currentBookPath index:nil];
		if (object) {
			page = [[object objectForKey:@"page"] intValue];
		}
		if (!page) {
			object = [self searchFromLastPages:currentBookPath index:nil];
			if (object) {
				page = [[object objectForKey:@"page"] intValue];
			}
		}
		if (goToLastPageMode==0 && page) {
			if (!COConfirmAction(NSLocalizedString(@"Go to the last page", @""),
				[NSString stringWithFormat:NSLocalizedString(@"Do you want to go to %i page?", @""), page + 1])) {
				page = 0;
			}
		}
	}
	/*add RecentItem*/
	if (openRecentLimit>0) {
		NSDictionary *newDic = [NSDictionary dictionaryWithObjectsAndKeys:aliasData,@"alias",currentBookPath,@"temppath",nil];
		if (alwaysRememberLastPage) {
			id object = [self searchFromLastPages:currentBookPath index:nil];
			if (object) {
				newDic = object;
			}
		}
		int index = 0;
		id objectS = [self searchFromRecentItems:currentBookPath index:&index];
		if (objectS) {
			[newRecentItems removeObjectAtIndex:index];
			newDic = objectS;
		}
		[newRecentItems insertObject:newDic atIndex:0];
		
		[defaults setObject:newRecentItems forKey:@"RecentItems"];
	} else {
		[defaults removeObjectForKey:@"RecentItems"];
	}
	[self setOpenRecentMenu];
	NSMenu *menu=[openRecentMenuItem submenu];
	[[menu itemAtIndex:0] setState:NSControlStateValueOn];
	[[menu itemAtIndex:0] setEnabled:NO];
	
	[defaults synchronize];
	
	
	
	imageLoader = newImageLoader;
	completeMutableArray = [[imageLoader pathArray] retain];
	
	sortMode = 0;
	if ([currentBookSetting objectForKey:@"sortMode"]) {
		sortMode = [[currentBookSetting objectForKey:@"sortMode"] intValue];
	} else {
		sortMode = (int)[defaults integerForKey:@"SortMode"];
	}
	if (sortMode!=0) {
		[self setSortMode:sortMode page:-1];
	}
	

	
	if (fromFileName) {
		page = (int)[completeMutableArray indexOfObject:fromFileName];
		[fromFileName release];
	}
	if (last) {
		int temp = (int)[completeMutableArray count];
		temp--;
		if ([completeMutableArray count] > 1) {
			temp--;
			[imageMutableArray addObject:[self loadImage:temp]];
			temp++;
			[imageMutableArray addObject:[self loadImage:temp]];
			if ([self isSmallImage:[imageMutableArray objectAtIndex:0] page:temp] == NO){
				[imageMutableArray removeObjectAtIndex:0];
				temp++;
			}
			temp--;
		} else {
			[imageMutableArray addObject:[self loadImage:temp]];
		}
		nowPage = temp;
	} else {
		if (page >= [completeMutableArray count]) {
			page = 0;
		}
		nowPage = page;
		if ([completeMutableArray count] > page) {
			[imageMutableArray addObject:[self loadImage:page]];
			page++;
			if ([completeMutableArray count] > page) {
				[imageMutableArray addObject:[self loadImage:page]];
			}
		}
	}
	readMode = (int)[defaults integerForKey:@"ReadMode"];
	[marksArray removeAllObjects];
	
	if (currentBookSetting) {
		if ([currentBookSetting objectForKey:@"readMode"]) {
			readMode = [[currentBookSetting objectForKey:@"readMode"] intValue];
		}
		if ([currentBookSetting objectForKey:@"marks"]) {
			[marksArray addObjectsFromArray:[currentBookSetting objectForKey:@"marks"]];
		}
	}
	

	[imageView setPageString:nil];
	[window setTitle:currentBookName];
	
	[composedImage release];
	composedImage = nil;
	
	
	[bookmarkArray removeAllObjects];
	if (currentBookSetting) {
		if ([currentBookSetting objectForKey:@"bookmarks"]) {
			[bookmarkArray addObjectsFromArray:[currentBookSetting objectForKey:@"bookmarks"]];
		}
	}
	[self setBookmarkMenu];
	
	[thumController setImageLoader:imageLoader];
	[thumController setmaxCacheCount:(int)[defaults integerForKey:@"ThumbnailCache"]];
	
	
	[progressIndicator stopAnimation:self];
	//[imageView displayRect:rect];
	[self viewSet];
	[self imageDisplay];
	
	if ([thumController isVisible]||[defaults boolForKey:@"ShowThumbnailWhenOpen"]) {
		if (secondImage) {
			int temp = nowPage;
			temp--;
			[thumController showThumbnail:temp];
		} else {
			[thumController showThumbnail:nowPage];
		}
	}

	
}
- (void)askForPassword:(COImageLoader*)loader
{
	[passPanel setTitle:[[loader displayPath] lastPathComponent]];
	[passTextField setStringValue:@""];
	while (YES) {
		int passPanelResult = (int)[NSApp runModalForWindow:passPanel];
		[passPanel orderOut:self];
		if (passPanelResult != DIALOG_OK || [loader checkAndSetPassword:[passTextField stringValue]]) break;
		[passTextField setStringValue:@""];
	}
	[passTextField setStringValue:@""];
	[passPanel setTitle:@"Password"];
}
- (IBAction)sheetOk:(id)sender{[NSApp stopModalWithCode:DIALOG_OK];}
- (IBAction)sheetCancel:(id)sender{[NSApp stopModalWithCode:DIALOG_CANCEL];}


#pragma mark dock
- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	NSMenu *menu=[[[NSMenu alloc] init] autorelease];
	
	if (![imageView image]) {
		NSMenuItem *menuItem;
		menuItem=[[NSMenuItem alloc] init];
		[menuItem setTitle:NSLocalizedString(@"Open the last page", @"")];
		[menuItem setAction:@selector(openTheLastPage:)];
		[menu addItem:menuItem];
		[menuItem release];
	}
	return menu;
}


#pragma mark -
#pragma mark load
- (NSString*)pathAtIndex:(int)index
{
	return [completeMutableArray objectAtIndex:index];
}

- (NSImage*)loadThumbnailImage:(int)index
{
	return [thumController loadImage:index];
}

- (NSImage*)loadImage:(int)index
{
	if (index < 0 || index >= [completeMutableArray count]) return nil;
	NSString *cacheKey = [completeMutableArray objectAtIndex:index];
	if (cacheSize != 0) {
		NSImage *cachedImage = [cacheArray objectForKey:cacheKey];
		if (cachedImage) return cachedImage;
	}
	if ([imageView image]) {
		if (secondImage) {
			int temp = nowPage;
			temp--;
			if (index == temp) {
				if (cacheSize != 0) {
					[cacheArray setObject:secondImage forKey:cacheKey];
				}
				//NSLog(@"return2 %@",[completeMutableArray objectAtIndex:index]);
				return secondImage;
			}
			temp--;
			if (index == temp) {
				if (cacheSize != 0) {
					[cacheArray setObject:firstImage forKey:cacheKey];
				}
				//NSLog(@"return2 %@",[completeMutableArray objectAtIndex:index]);
				return firstImage;
			}
		} else {
			int temp = nowPage;
			temp--;
			if (index == temp) {
				if (cacheSize != 0) {
					[cacheArray setObject:firstImage forKey:cacheKey];
				}
				//NSLog(@"return2 %@",[completeMutableArray objectAtIndex:index]);
				return firstImage;
			}
		}
	}
	
	NSImage *image = [imageLoader itemAtIndex:index];
    int heightValue = 0,widthValue = 0,repi = 0;
    /*
	NSImageRep*	rep;
	NSArray *repArray=[image representations];
	for(repi=0;repi<[repArray count];repi++){
		rep =[repArray objectAtIndex:repi];
		if(rep){
			heightValue=(int)[rep pixelsHigh];
			widthValue=(int)[rep pixelsWide];
			break;
		}
	}
	if( (widthValue>0 && heightValue>0) && ([image size].width != widthValue || [image size].height != heightValue) ){
		//[image setScalesWhenResized:YES];
		[image setSize:NSMakeSize(widthValue,heightValue)];
	}
     */
	if (cacheSize != 0) {
		[cacheArray setObject:image forKey:cacheKey];
		//NSLog(@"load %@",[completeMutableArray objectAtIndex:index]);
	}
	return image;
}

-(void)lookahead
{
	[lock lock];
	threadCount++;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	int i = nowPage;
	i += [imageMutableArray count];
	
	if (i < [completeMutableArray count]) {
		while([imageMutableArray count] < 2) {
			if (threadStop) {
				threadStop = NO;
				threadCount--;
				[lock unlock];
				[pool release];
				return;
			}
			[imageMutableArray addObject:[self loadImage:i]];
			i = nowPage;
			i += [imageMutableArray count];
			if (i == [completeMutableArray count]) {
				break;
			}
		}
	} else if (nowPage == [completeMutableArray count]) {
	} else if (nowPage > [completeMutableArray count]) {
		nowPage = (int)[completeMutableArray count];
	}
	threadStop = NO;
	threadCount--;
	[lock unlock];
	[pool release];
}

-(void)lookaheadAndCompose
{
	[lock lock];
	threadCount++;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	int i = nowPage;
	i += [imageMutableArray count];
	
	
	if (i < [completeMutableArray count]) {
		 while([imageMutableArray count] < 2) {
			 if (threadStop) {
				 threadCount--;
				 threadStop = NO;
				 [lock unlock];
				 [pool release];
				 return;
			 }
			 [imageMutableArray addObject:[self loadImage:i]];
			 i = nowPage;
			 i += [imageMutableArray count];
			 if (i == [completeMutableArray count]) {
				 break;
			 }
		 }
	} else if (nowPage == [completeMutableArray count]) {
	} else if (nowPage > [completeMutableArray count]) {
		nowPage = (int)[completeMutableArray count];
	}
	
	[composedImage autorelease];
	composedImage = nil;
	if (threadStop) {
		threadCount--;
		threadStop = NO;
		[lock unlock];
		[pool release];
		return;
	}
	
	if ([imageMutableArray count]>1 && readMode<2 && bufferingMode == 0) {
		int tempPage = nowPage+2;
		NSString *screenCacheKey = nil;
		if (screenCache>0) {
			NSString *pageKey;
			if (readMode == 0 || readMode == 2) {
				pageKey = [NSString stringWithFormat:@"%i-%i",tempPage,tempPage-1];
			} else {
				pageKey = [NSString stringWithFormat:@"%i-%i",tempPage-1,tempPage];
			}
			screenCacheKey = [NSString stringWithFormat:@"%@:%i",pageKey,fitScreenMode];
			NSImage *cachedComposedImage = [screenCacheArray objectForKey:screenCacheKey];
			if (cachedComposedImage) {
				composedImage = [cachedComposedImage retain];
				threadCount--;
				threadStop = NO;
				[lock unlock];
				[pool release];
				return;
			}
		}
		
		if ([self isSmallImage:[imageMutableArray objectAtIndex:1] page:nowPage+1] 
			&& [self isSmallImage:[imageMutableArray objectAtIndex:0] page:nowPage+2]) {
			NSImage *image1 = [[imageMutableArray objectAtIndex:1] retain];
			NSImage *image2 = [[imageMutableArray objectAtIndex:0] retain];
			composedImage = [[self returnComposeImage:image1 and:image2] retain];
			[image1 release];
			[image2 release];
		}
		if (composedImage) {
			if (screenCacheKey) [screenCacheArray setObject:composedImage forKey:screenCacheKey];
			//NSLog(@"add %i-%i",tempPage,tempPage-1);
		}
	}
	threadStop = NO;
	threadCount--;
	[lock unlock];
	[pool release];
}

#pragma mark image

-(BOOL)isSmallImage:(NSImage *)image page:(int)page
{
	int widthValue,heightValue;
	widthValue = [image size].width;
	heightValue = [image size].height;	
	if ([marksArray count] > 0 && page >= 0) {
		if ([marksArray containsObject:[NSString stringWithFormat:@"%i",page]]) {
			return NO;
		}
		if ([marksArray containsObject:[NSString stringWithFormat:@"%i-%i",page,page+1]]) {
			return YES;
		}
		if ([marksArray containsObject:[NSString stringWithFormat:@"%i-%i",page-1,page]]) {
			return YES;
		}
	}
	float setTemp;
	int s = 1000;
	setTemp = (float)singleSetting/s;
	float realTemp;
	realTemp = (float)widthValue/heightValue;
	if (setTemp < realTemp) {
		//big
		return NO;
	} else {
		//small
		return YES;
	}
}

-(NSImage *)returnComposeImage:(NSImage *)image1 and:(NSImage *)image2
{
	//if ([self isSmallImage:image1 page:nowPage+1]==NO || [self isSmallImage:image2 page:nowPage+2]==NO) return nil;
	if (bufferingMode == 1) return nil;
	if ([image1 isKindOfClass:[COAnimatedImage class]] || [image2 isKindOfClass:[COAnimatedImage class]]) return nil;
	
	
	NSRect fullscreenRect;
	fullscreenRect = [[NSScreen mainScreen] frame];
	
	int widthValue01 = (int)[image1 size].width;
	int heightValue01 = (int)[image1 size].height;
	int widthValue02 = (int)[image2 size].width;
	int heightValue02 = (int)[image2 size].height;
	
	int widthValue1 = widthValue01;
	int heightValue1 = heightValue01;
	int widthValue2 = widthValue02;
	int heightValue2 = heightValue02;
	
	float screenWidthValue = fullscreenRect.size.width/2;
	float screenHeightValue = fullscreenRect.size.height;
	if (fitScreenMode != 2) {
		float rate1 = screenWidthValue/widthValue1;
		float sRate1 = screenHeightValue/heightValue1;
		
		float rate2 = screenWidthValue/widthValue2;
		float sRate2 = screenHeightValue/heightValue2;
		
		if (rate1 > sRate1) {
			rate1 = sRate1;
		}
		if (rate2 > sRate2) {
			rate2 = sRate2;
		}
		
		if (maxEnlargement != 0 && rate1 > maxEnlargement) {
			rate1 = maxEnlargement;
		}
		if (maxEnlargement != 0 && rate2 > maxEnlargement){
			rate2 = maxEnlargement;
		}
		
		widthValue1 = widthValue1*rate1;
		heightValue1 = heightValue1*rate1;
		
		widthValue2 = widthValue2*rate2;
		heightValue2 = heightValue2*rate2;
		
		
		if (widthValue1+widthValue2 < fullscreenRect.size.width){
			if (fitScreenMode == 1) {
				float rates = fullscreenRect.size.width/(widthValue1+widthValue2);
				
				widthValue1 = widthValue1*rates;
				heightValue1 = heightValue1*rates;
				widthValue2 = widthValue2*rates;
				heightValue2 = heightValue2*rates;
				
				if (maxEnlargement != 0) {
					if (widthValue1 > (widthValue01*maxEnlargement)) {
						widthValue1 = widthValue01;
						heightValue1 = heightValue01;
					}
					if (heightValue1 > (heightValue01*maxEnlargement)) {
						widthValue1 = widthValue01;
						heightValue1 = heightValue01;
					}
					if (widthValue2 > (widthValue02*maxEnlargement)) {
						widthValue2 = widthValue02;
						heightValue2 = heightValue02;
					}
					if (heightValue2 > (heightValue02*maxEnlargement)) {
						widthValue2 = widthValue02;
						heightValue2 = heightValue02;
					}
				}
			}
		}
	}
	
	int height;
	if (heightValue1 > heightValue2) {
		height = heightValue1;
	} else {
		height = heightValue2;
	}
	int center1 = (height-heightValue1)/2;
	int center2 = (height-heightValue2)/2;
	
	NSImage *newImage = [[[NSImage alloc] initWithSize:NSMakeSize(widthValue1+widthValue2,height)] autorelease];
	[ newImage lockFocus ];
	NSGraphicsContext *gc = [NSGraphicsContext currentContext];
	[gc saveGraphicsState];
	//[gc setShouldAntialias:NO];
	switch (interpolation) {
		case 1:
			[gc setImageInterpolation:NSImageInterpolationNone];
			break;
		case 2:
			[gc setImageInterpolation:NSImageInterpolationLow];
			break;
		case 3:
			[gc setImageInterpolation:NSImageInterpolationHigh];
			break;
		default:
			[gc setImageInterpolation:NSImageInterpolationDefault];
			break;
	}
	switch (readMode) {
		//2,3=only from singleModeKeyCode
		case 0: case 2:
            [image1 drawInRect:NSMakeRect(0,center1,widthValue1,heightValue1)
                      fromRect:NSMakeRect(0, 0, [image1 size].width, [image1 size].height)
                     operation:NSCompositingOperationSourceOver fraction:1.0];
            [image2 drawInRect:NSMakeRect(widthValue1,center2,widthValue2,heightValue2)
                      fromRect:NSMakeRect(0, 0, [image2 size].width, [image2 size].height)
                     operation:NSCompositingOperationSourceOver fraction:1.0];
			break;
		case 1: case 3:
            [image2 drawInRect:NSMakeRect(0,center2,widthValue2,heightValue2)
                      fromRect:NSMakeRect(0, 0, [image2 size].width, [image2 size].height)
                     operation:NSCompositingOperationSourceOver fraction:1.0];
            [image1 drawInRect:NSMakeRect(widthValue2,center1,widthValue1,heightValue1)
                      fromRect:NSMakeRect(0, 0, [image1 size].width, [image1 size].height)
                     operation:NSCompositingOperationSourceOver fraction:1.0];
			break;
		default:
			break;
	}
	[gc restoreGraphicsState];
	[newImage unlockFocus];
	//NSLog(@"load %@ \n %@",[completeMutableArray objectAtIndex:index],image);
	
	return newImage;
}

-(void)composeImage
{
	if (bufferingMode == 1) {
		if (firstImage && secondImage) {
			[imageView setImages:secondImage];
		} else {
			[imageView setImage:(secondImage ? secondImage : firstImage)];
		}
	} else if ([firstImage isKindOfClass:[COAnimatedImage class]] || [secondImage isKindOfClass:[COAnimatedImage class]]) {
		if (firstImage && secondImage) {
			[imageView setImages:firstImage];
		} else {
			[imageView setImage:(firstImage ? firstImage : secondImage)];
		}
	} else {
		if (screenCache>0) {
			NSString *pageKey;
			if (readMode == 0 || readMode == 2) {
				pageKey = [NSString stringWithFormat:@"%i-%i",nowPage,nowPage-1];
			} else {
				pageKey = [NSString stringWithFormat:@"%i-%i",nowPage-1,nowPage];
			}
			NSString *screenCacheKey = [NSString stringWithFormat:@"%@:%i",pageKey,fitScreenMode];
			NSImage *cachedComposedImage = [screenCacheArray objectForKey:screenCacheKey];
			if (cachedComposedImage) {
				[imageView setImage:cachedComposedImage];
				return;
			}
		}
		//NSLog(@"kone- %i-%i",nowPage,nowPage-1);
		id image = [self returnComposeImage:secondImage and:firstImage];
		[imageView setImage:image];
		if (image) {
			if (screenCache>0) {
				NSString *pageKey;
				if (readMode == 0 || readMode == 2) {
					pageKey = [NSString stringWithFormat:@"%i-%i",nowPage,nowPage-1];
				} else {
					pageKey = [NSString stringWithFormat:@"%i-%i",nowPage-1,nowPage];
				}
				NSString *screenCacheKey = [NSString stringWithFormat:@"%@:%i",pageKey,fitScreenMode];
				[screenCacheArray setObject:image forKey:screenCacheKey];
			}
			//NSLog(@"set %i-%i",nowPage,nowPage-1);
		}
	}
	//[imageView setImages:secondImage];
}

#pragma mark display

-(BOOL)imageDisplayIfHasScreenCache
{
	int tempPage = nowPage;
	nowPage += 2;
	if (screenCache > 0) {
		NSString *pageKey;
		if (readMode == 0 || readMode == 2) {
			pageKey = [NSString stringWithFormat:@"%i-%i",nowPage,nowPage-1];
		} else {
			pageKey = [NSString stringWithFormat:@"%i-%i",nowPage-1,nowPage];
		}
		NSString *screenCacheKey = [NSString stringWithFormat:@"%@:%i",pageKey,fitScreenMode];
		NSImage *cachedComposedImage = [screenCacheArray objectForKey:screenCacheKey];
		if (cachedComposedImage) {
			[imageView setImage:cachedComposedImage];
			[self setPageTextField];
			[imageView setPageString:[NSString stringWithFormat:@"%@ LoadingOriginals...",[imageView pageString]]];
			nowPage = tempPage;
			return YES;
		}
	}
	nowPage = tempPage;
	return NO;
}

-(void)imageDisplay
{
	/*
	NSTimeInterval start,stop,elapsed;
	start=[NSDate timeIntervalSinceReferenceDate];
	*/
	//[lock lock];
	//[lock unlock];
	
    [self lockedImageDisplay];
	
	
	/*
	stop=[NSDate timeIntervalSinceReferenceDate];
	elapsed=stop-start;
	NSLog(@"%f",elapsed);
	 */
}

-(void)lockedImageDisplay
{
	if (readMode > 1) {
		if (nowPage == [completeMutableArray count]) {
			if (loopCheck == 0) {
				nowPage = 0;
				[self lookahead];
				[self lockedImageDisplay];
			} else if (loopCheck == 1) {
				[self nextFolder];
			} else if (loopCheck == 2) {
				[self nextFolder];
			} else {
				if (timerSwitch) {
					[timer invalidate];
					timerSwitch=NO;
					[self endSlideshowActivity];
				}
			}
		} else if (nowPage < [completeMutableArray count]) {
			while ([imageMutableArray count] == 0) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
			//[self isSmallImage:[imageMutableArray objectAtIndex:0] page:nowPage+1];
			[imageView setImage:nil];
			[firstImage release];
			firstImage = nil;
			[secondImage release];
			secondImage = nil;
			
			
			nowPage++;
			[self setPageTextField];
			firstImage = [[imageMutableArray objectAtIndex:0] retain];
			[imageView setImage:firstImage];
			//[imageView setImage:[imageMutableArray objectAtIndex:0]];
			[imageMutableArray removeObjectAtIndex:0];
			[NSThread detachNewThreadSelector:@selector(lookahead) toTarget:self withObject:nil];
		}
	} else {
		if (nowPage < [completeMutableArray count]) {			
			[imageView setImage:nil];
			[firstImage release];
			firstImage = nil;
			[secondImage release];
			secondImage = nil;
			while ([imageMutableArray count] == 0) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.0001]];
			
			if ([self isSmallImage:[imageMutableArray objectAtIndex:0] page:nowPage+1] == YES) {
				if (nowPage+1 != [completeMutableArray count] && threadCount > 0) {
					while ([imageMutableArray count] == 1) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
				}
				if ([imageMutableArray count] > 1) {
					if ([self isSmallImage:[imageMutableArray objectAtIndex:1] page:nowPage+2] == YES) {
						firstImage = [[imageMutableArray objectAtIndex:0] retain];
						secondImage = [[imageMutableArray objectAtIndex:1] retain];
						
						nowPage += 2;
						[self setPageTextField];
						if (useComposedImage == NO) {
							[self composeImage];
							//NSLog(@"NO");
						} else if (composedImage && useComposedImage == YES) {
							[imageView setImage:composedImage];
							[composedImage autorelease];
							composedImage = nil;
							//NSLog(@"YES");
						} else {
							[self composeImage];
							//NSLog(@"else");
						}
						[imageMutableArray removeObjectsInRange:NSMakeRange(0,2)];
					} else {
						nowPage++;
						[self setPageTextField];
						firstImage = [[imageMutableArray objectAtIndex:0] retain];
						[imageView setImage:firstImage];
						//[imageView setImage:[imageMutableArray objectAtIndex:0]];
						[imageMutableArray removeObjectAtIndex:0];
					}
				} else {
					nowPage++;
					[self setPageTextField];
					firstImage = [[imageMutableArray objectAtIndex:0] retain];
					[imageView setImage:firstImage];
					//[imageView setImage:[imageMutableArray objectAtIndex:0]];
					[imageMutableArray removeObjectAtIndex:0];
					
				}
			} else {
				nowPage++;
				[self setPageTextField];
				firstImage = [[imageMutableArray objectAtIndex:0] retain];
				[imageView setImage:firstImage];
				//[imageView setImage:[imageMutableArray objectAtIndex:0]];
				[imageMutableArray removeObjectAtIndex:0];
			}
			[NSThread detachNewThreadSelector:@selector(lookaheadAndCompose) toTarget:self withObject:nil];
		} else if (nowPage == [completeMutableArray count]) {
			if (loopCheck == 0) {
				nowPage = 0;
				[self lookaheadAndCompose];
				[self lockedImageDisplay];
			} else if (loopCheck == 1) {
				[self nextFolder];
				return;
			} else if (loopCheck == 2) {
				[self nextFolder];
				return;
			} else {
				if (timerSwitch) {
					[timer invalidate];
					timerSwitch=NO;
					[self endSlideshowActivity];
				}
			}
		}
	}
}


#pragma mark -
#pragma mark preferences
- (IBAction)preferences:(id)sender
{
	[prefController preferences];
}

- (void)setPreferences
{
	[keyArray release];
	[keyArrayMode2 release];
	[keyArrayMode3 release];
	[mouseArray release];
	[mouseArrayMode2 release];
	[mouseArrayMode3 release];
	keyArray = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"KeyArray"]];
	keyArrayMode2 = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"KeyArrayMode2"]];
	keyArrayMode3 = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"KeyArrayMode3"]];
	mouseArray = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"MouseArray"]];
	mouseArrayMode2 = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"MouseArrayMode2"]];
	mouseArrayMode3 = [[NSMutableArray alloc] initWithArray:[defaults arrayForKey:@"MouseArrayMode3"]];
	
	rememberBookSettings = [defaults boolForKey:@"RememberBookSettings"];
	readSubFolder = [defaults boolForKey:@"ReadSubFolder"];
	loopCheck = (int)[defaults integerForKey:@"LoopCheck"];
	sliderValue = [defaults floatForKey:@"SlideshowDelay"];
	
	prevPageMode = (int)[defaults integerForKey:@"PrevPageMode"];
	canScrollMode = (int)[defaults integerForKey:@"CanScrollMode"];
	
	
	alwaysRememberLastPage = [defaults boolForKey:@"AlwaysRememberLastPage"];
	goToLastPageMode = (int)[defaults integerForKey:@"GoToLastPage"];
	
	openLinkMode = (int)[defaults integerForKey:@"OpenLinkMode"];
	
	changeCurrentFolderMode = (int)[defaults integerForKey:@"ChangeCurrentFolder"];
	
	int oldOpenRecentLimit = openRecentLimit;
	openRecentLimit = (int)[defaults integerForKey:@"OpenRecentLimit"];
	if (oldOpenRecentLimit!=openRecentLimit) {
		if (openRecentLimit>0) {
			int tmpOpenRecentLimit = openRecentLimit;
			if ([imageView image]) {
				tmpOpenRecentLimit++;
			}
			NSMutableArray *array;
			if (![defaults arrayForKey:@"RecentItems"]) {
				array = [NSMutableArray array];
			} else {
				array = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentItems"]];
			}
			while ([array count] > tmpOpenRecentLimit) {
				[array removeLastObject];
			}
			[defaults setObject:array forKey:@"RecentItems"];
			[self setOpenRecentMenu];
			if ([imageView image]) {
				NSMenu *menu=[openRecentMenuItem submenu];
				[[menu itemAtIndex:0] setState:NSControlStateValueOn];
				[[menu itemAtIndex:0] setEnabled:NO];
			}
		} else {
			[defaults removeObjectForKey:@"RecentItems"];
			[self setOpenRecentMenu];
		}
	}
	
	/*cache*/
	cacheSize = (int)[defaults integerForKey:@"ImageCache"];
	if (cacheSize > 0) {
		[cacheArray setCountLimit:(NSUInteger)(cacheSize + 4)];
	} else {
		[cacheArray removeAllObjects];
	}
	screenCache = (int)[defaults integerForKey:@"ScreenCache"];
	if (screenCache > 0) {
		[screenCacheArray setCountLimit:(NSUInteger)(screenCache + 2)];
	} else {
		[screenCacheArray removeAllObjects];
	}
	[thumController setmaxCacheCount:(int)[defaults integerForKey:@"ThumbnailCache"]];
	
	[fullImagePanel setFitMode:[defaults boolForKey:@"FitOriginal"]];
	
	bufferingMode = (int)[defaults integerForKey:@"BufferingMode"];
	
	

	
	
    BOOL useCalayer = [defaults boolForKey:@"UseCALayer"];
    [imageView setUseCalayer:useCalayer];
	
    
    NSColor *viewBackGround = [COReadArchivedSetting(defaults, @"ViewBackGroundColor", [NSColor class]) colorWithAlphaComponent:1];
    [window setBackgroundColor:viewBackGround];
    if (fitScreenMode > 0) {
        [[imageView enclosingScrollView] setBackgroundColor:viewBackGround];
    }
	
	if (readMode != [defaults integerForKey:@"ReadMode"]) {
		if ([imageView image]) {
			BOOL readModeTemp = NO;
			if (currentBookSetting) {
				if ([currentBookSetting objectForKey:@"readMode"]) {
					readModeTemp = YES;
				}
			}
			if (!readModeTemp) {
				[self changeReadMode:(int)[defaults integerForKey:@"ReadMode"]];
			}
		}
	}
	if (sortMode != [defaults integerForKey:@"SortMode"]) {
		if ([imageView image]) {
			BOOL sortModeTemp = NO;
			if (currentBookSetting) {
				if ([currentBookSetting objectForKey:@"sortMode"]) {
					sortModeTemp = YES;
				}
			}
			if (!sortModeTemp) {
				[self setSortMode:(int)[defaults integerForKey:@"SortMode"] page:-1];
				[self goTo:0 array:nil];
			}
		}
	}
	if (singleSetting != [defaults integerForKey:@"SingleSetting"]) {
		singleSetting = (int)[defaults integerForKey:@"SingleSetting"];
		if ([imageView image]) {
			if (secondImage) {
				if (![self isSmallImage:firstImage page:nowPage-2] || ![self isSmallImage:secondImage page:nowPage-1]) {
					[imageMutableArray insertObject:secondImage atIndex:0];
					[imageMutableArray insertObject:firstImage atIndex:0];
					[secondImage release];
					secondImage = nil;
					[firstImage release];
					firstImage = nil;
					nowPage-=2;
					[self imageDisplay];
				}
			} else {
				if ([self isSmallImage:firstImage page:nowPage-1]) {
					[imageMutableArray insertObject:firstImage atIndex:0];
					nowPage--;
					[self imageDisplay];
				}
			}
		}
	}
	
	if (interpolation != [defaults integerForKey:@"Interpolation"]) {
		if (maxEnlargement != [defaults integerForKey:@"MaxEnlargement"] ){
			maxEnlargement = (int)[defaults integerForKey:@"MaxEnlargement"];
		}
		interpolation = (int)[defaults integerForKey:@"Interpolation"];
		[imageView setInterpolation:interpolation];
		if ([imageView image]) {
			if (secondImage) {
				[self composeImage];
			} else {
				[imageView setImage:firstImage];
			}
			[self lookaheadAndCompose];
		}
	} else if (maxEnlargement != [defaults integerForKey:@"MaxEnlargement"]) {
		maxEnlargement = (int)[defaults integerForKey:@"MaxEnlargement"];
		if ([imageView image]) {
			if (secondImage) {
				[self composeImage];
			} else {
				[imageView setImage:firstImage];
			}
			[self lookaheadAndCompose];
		}
	}
	
	pageBar = [defaults boolForKey:@"ShowPageBar"];
	if (numberSwitch != [defaults boolForKey:@"ShowNumber"]) {
		if (numberSwitch) {
			[imageView setPageString:nil];
			numberSwitch = NO;
		} else {
			if (!secondImage) {
				int i = nowPage - 1;
				[imageView setPageString:[NSString stringWithFormat:@"#%d/%d (%@)",nowPage,(int)[completeMutableArray count],[[completeMutableArray objectAtIndex:i] lastPathComponent]]];
				numberSwitch = YES;
			} else if (secondImage) {
				int i = nowPage - 1;
				int iS = i - 1;
				[imageView setPageString:[NSString stringWithFormat:@"#%d-%d/%d (%@ / %@)",i,nowPage,(int)[completeMutableArray count],[[completeMutableArray objectAtIndex:iS] lastPathComponent],[[completeMutableArray objectAtIndex:i] lastPathComponent]]];
				numberSwitch = YES;
			}
		}
	}
	
	[imageView setPreferences];
	
	
	
	wheelSensitivity = [defaults floatForKey:@"WheelSensitivity"];
		[imageView wheelSetting:wheelSensitivity];
		[thumController wheelSetting:wheelSensitivity];
	
	[thumController setCellRow:[[[defaults dictionaryForKey:@"Thumbnail"] objectForKey:@"row"] intValue]
						column:[[[defaults dictionaryForKey:@"Thumbnail"] objectForKey:@"column"] intValue]];
	

	
	NSEnumerator *enu = [keyArray objectEnumerator];
	id object;
	/*
	 NSMutableArray *array = [NSMutableArray array];
	while (object = [enu nextObject]) {
		if ([[object objectForKey:@"action"] intValue] < 2) {
			[array addObject:object];
		}
	}
	 */
	NSMutableArray *array = [NSMutableArray arrayWithArray:keyArray];

	[fullImagePanel setPageKey:array];
	[thumController setPageKey:array];
	if ([thumController isVisible]) {
		if (secondImage) {
			int temp = nowPage;
			temp--;
			[thumController showThumbnail:temp];
		} else {
			[thumController showThumbnail:nowPage];
		}
	}
	
	NSMutableArray *array2 = [NSMutableArray array];
	enu = [mouseArrayMode2 objectEnumerator];
	while (object = [enu nextObject]) {
		if ([[object objectForKey:@"action"] intValue] == 41) {
			[array2 addObject:object];
		}
	}
	[imageView setDragScroll:array2 mode:1];
	
	NSMutableArray *array3 = [NSMutableArray array];
	enu = [mouseArrayMode3 objectEnumerator];
	while (object = [enu nextObject]) {
		if ([[object objectForKey:@"action"] intValue] == 41) {
			[array3 addObject:object];
		}
	}
	[imageView setDragScroll:array3 mode:2];
	[imageView setDragScroll:array3 mode:3];
}

#pragma mark menu



- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
    if ([[anItem title] isEqualToString:NSLocalizedString(@"Start/Stop", @"")] == YES) {
		if ([window isVisible]) {
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Edit Bookmark...", @"")] == YES) {
		if ([window isVisible]) {
			return YES;
		} else {
			//	return NO;
			return YES;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Fullscreen", @"")] == YES) {
		[anItem setState:[window isFullScreen] ? NSControlStateValueOn : NSControlStateValueOff];
		return [window isVisible] && [window isKeyWindow];
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Open the last page", @"")] == YES) {
		if ([window isVisible] || [window isMiniaturized]) {
			if ([defaults arrayForKey:@"RecentItems"]) {
				NSEnumerator *enu = [[defaults arrayForKey:@"RecentItems"] objectEnumerator];
				id object;
				while (object = [enu nextObject]) {
					if ([COPathFromStoredEntry(object) isEqualToString:currentBookPath] && [object objectForKey:@"page"]) {
						return YES;
					}
				}
			}
			if ([defaults arrayForKey:@"LastPages"]) {
				NSEnumerator *enu = [[defaults arrayForKey:@"LastPages"] objectEnumerator];
				id object;
				while (object = [enu nextObject]) {
					if ([COPathFromStoredEntry(object) isEqualToString:currentBookPath] && [object objectForKey:@"page"]) {
						return YES;
					}
				}
			}
		} else {
			if ([[defaults arrayForKey:@"RecentItems"] count]>0) {
				return YES;
			}
		}
		return NO;
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Delete Settings", @"")] == YES) {
		if ([window isVisible]) {
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Right to Left", @"")] == YES) {
		if ([window isVisible]) {
			if (readMode == 0) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Left to Right", @"")] == YES) {
		if ([window isVisible]) {
			if (readMode == 1) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Right to Left (single)", @"")] == YES) {
		if ([window isVisible]) {
			if (readMode == 2) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Left to Right (single)", @"")] == YES) {
		if ([window isVisible]) {
			if (readMode == 3) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Fit to Screen", @"")] == YES) {
		if ([window isVisible]) {
			if (fitScreenMode == 0) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Fit to Screen Width", @"")] == YES) {
		if ([window isVisible]) {
			if (fitScreenMode == 1) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"No Scale", @"")] == YES) {
		if ([window isVisible]) {
			if (fitScreenMode == 2) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Fit to Screen Width(divide)", @"")] == YES) {
		if ([window isVisible]) {
			if (fitScreenMode == 3) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		}
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Switch Single/Bind", @"")] == YES) {
		if ([window isVisible]) {
			return YES;
		} else {
			return NO;
		}	
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Rotate Left", @"")] == YES) {
		if ([window isVisible]) {
			return YES;
		} else {
			return NO;
		}	
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Rotate Right", @"")] == YES) {
		if ([window isVisible]) {
			return YES;
		} else {
			return NO;
		}
		
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Name", @"")] == YES) {
		if ([window isVisible]) {
			if (sortMode == 0) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		} 
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Shuffle", @"")] == YES) {
		if ([window isVisible]) {
			if (sortMode == 1) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			return YES;
		} else {
			return NO;
		} 
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Creation Date", @"")] == YES) {
		if ([window isVisible]) {
			if (sortMode == 2) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			if ([imageLoader canSortByDate]) {
				return YES;
			} else {
				return NO;
			}
		} else {
			return NO;
		} 
	} else if ([[anItem title] isEqualToString:NSLocalizedString(@"Modification Date", @"")] == YES) {
		if ([window isVisible]) {
			if (sortMode == 3) {
				[anItem setState:NSControlStateValueOn];
			} else {
				[anItem setState:NSControlStateValueOff];
			}
			if ([imageLoader canSortByDate]) {
				return YES;
			} else {
				return NO;
			}
		} else {
			return NO;
		} 
	} else {
		/*contextMenu*/
		NSRect left,right;
		if (![self readFromLeft]) {
			NSDivideRect ([[window contentView] frame], &left, &right, [[window contentView] frame].size.width/2, NSMinXEdge);
		} else {
			NSDivideRect ([[window contentView] frame], &right, &left, [[window contentView] frame].size.width/2, NSMinXEdge);
		}
		if ([[anItem title]  isEqualToString:NSLocalizedString(@"Add Bookmark", @"")] 
			|| [[anItem title]  isEqualToString:NSLocalizedString(@"Remove Bookmark", @"")]) {
			BOOL bookmarked = NO;
			if (!secondImage) {
				bookmarked = [self isBookmarkedPage:nowPage];
			} else {
				bookmarked = [self isBookmarkedPage:nowPage];
				if (!bookmarked) bookmarked = [self isBookmarkedPage:nowPage-1];
			}
			if (bookmarked && [[anItem title]  isEqualToString:NSLocalizedString(@"Add Bookmark", @"")]) {
				[anItem setTitle:NSLocalizedString(@"Remove Bookmark", @"")];
			} else if (!bookmarked && [[anItem title]  isEqualToString:NSLocalizedString(@"Remove Bookmark", @"")]) {
				[anItem setTitle:NSLocalizedString(@"Add Bookmark", @"")];
			}
		}
		

		if (NSPointInRect([[NSApp currentEvent] locationInWindow], left)) {
			if ([[anItem title]  isEqualToString:NSLocalizedString(@"Previous Bookmark", @"")] ){
				[anItem setTitle:NSLocalizedString(@"Next Bookmark", @"")];
			} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"Go to FirstPage", @"")]) {
				[anItem setTitle:NSLocalizedString(@"Go to LastPage", @"")];
			} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"Previous Folder", @"")]) {
				[anItem setTitle:NSLocalizedString(@"Next Folder", @"")];
			} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"View at Original Size", @"")]) {
				[anItem setTag:1];
			} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"Show in Finder", @"")]) {
				[anItem setTag:1];
			}
		} else {
			if ([[anItem title]  isEqualToString:NSLocalizedString(@"Next Bookmark", @"")] ){
				[anItem setTitle:NSLocalizedString(@"Previous Bookmark", @"")];
			} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"Go to LastPage", @"")]) {
				[anItem setTitle:NSLocalizedString(@"Go to FirstPage", @"")];
			} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"Next Folder", @"")]) {
				[anItem setTitle:NSLocalizedString(@"Previous Folder", @"")];
			} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"View at Original Size", @"")]) {
				[anItem setTag:0];
			} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"Show in Finder", @"")]) {
				[anItem setTag:0];
			}
		}
		if ([[anItem title]  isEqualToString:NSLocalizedString(@"Start Slideshow", @"")]) {
			if (timerSwitch) [anItem setTitle:NSLocalizedString(@"Stop Slideshow", @"")];
		} else if ([[anItem title]  isEqualToString:NSLocalizedString(@"Stop Slideshow", @"")]) {
			if (!timerSwitch) [anItem setTitle:NSLocalizedString(@"Start Slideshow", @"")];
		}
		return YES;
	}
}



- (void)strongSetBookmark
{
	//allBookmarkEditで本を開いた後ブックマーク編集してから戻って来たとき用
	[currentBookSetting removeAllObjects];
	id tempCurrentBookSetting = [self searchFromBookSettings:currentBookPath key:nil more:YES];
	if (tempCurrentBookSetting) {
		[currentBookSetting setDictionary:tempCurrentBookSetting];
	}
	
	[bookmarkArray removeAllObjects];
	if (currentBookSetting) {
		if ([currentBookSetting objectForKey:@"bookmarks"]) {
			[bookmarkArray addObjectsFromArray:[currentBookSetting objectForKey:@"bookmarks"]];
		}
	}
	[self setBookmarkMenu];
}

- (void)setBookmarkMenu
{
	if (![window isVisible]) {
		return;
	}
	
	if ([bookmarkMenuItem numberOfItems] > 2) {
		while ([bookmarkMenuItem numberOfItems] > 2) {
			[bookmarkMenuItem removeItemAtIndex:2];
		}
	}
	
	int i;
	for (i=0; i<[bookmarkArray count]; i++)	{
		NSMenuItem*	menuItem;
		menuItem = [[NSMenuItem alloc] 
                initWithTitle:[[bookmarkArray objectAtIndex:i] objectForKey:@"name"] 
					   action:@selector(goBookmark:) 
                keyEquivalent:@""];
		[menuItem autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[[bookmarkArray objectAtIndex:i] objectForKey:@"page"]];
		[bookmarkMenuItem addItem:menuItem];
	}
}


-(void)setSameFolderMenu
{
	[self setSameFolderMenu:NO];
}
-(void)setSameFolderMenu:(BOOL)force
{
	if (currentBookPath == nil) {
		NSMenu *menu = [[[NSMenu alloc] init] autorelease];
		[openSameFolderMenuItem setSubmenu: menu];
		return;
	}
	NSString *tmpCurrentPath = [self pathFromAliasData:currentBookAlias];
	NSString *tmpCurrentBookName = [tmpCurrentPath lastPathComponent];
	NSString *superPath = [tmpCurrentPath stringByDeletingLastPathComponent];
	
	BOOL updateMenu = NO;
	if ([[openSameFolderMenuItem submenu] numberOfItems] == 0) {	
		updateMenu = YES;
	} else if (![[[[[openSameFolderMenuItem submenu] itemAtIndex:0] representedObject] stringByDeletingLastPathComponent]  isEqualToString:superPath]) {
		updateMenu = YES;
	} else if (force) {
		updateMenu = YES;
	}
	if (updateMenu) {
        NSMutableArray *superDirectoryArray = [NSMutableArray arrayWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:superPath error:nil]];
		[superDirectoryArray sortUsingSelector:@selector(finderCompareS:)];
		
		NSMenu *menu = [[[NSMenu alloc] init] autorelease];
		[menu setAutoenablesItems:NO];
		NSEnumerator *enumerator = [superDirectoryArray objectEnumerator];
		id object;
		while (object = [enumerator nextObject]) {
			BOOL isDir;
			if ([object compare:@"." options:NSCaseInsensitiveSearch range:NSMakeRange(0,1)] != NSOrderedSame) {
				[[NSFileManager defaultManager] fileExistsAtPath:[superPath stringByAppendingPathComponent:object] isDirectory:&isDir];
				if (isDir) {
					NSMenuItem *item = [menu addItemWithTitle:object
													   action:@selector(openFromSameDir:)
												keyEquivalent:@""];
					[item setTarget:self];
					[item setRepresentedObject:[superPath stringByAppendingPathComponent:object]];
					
					if ([object isEqualToString:tmpCurrentBookName]) {
						[item setState:NSControlStateValueOn];
					}
				} else {
					if([[COImageLoader fileTypes] containsObject:[[object pathExtension] lowercaseString]]){
						NSMenuItem *item = [menu addItemWithTitle:object
														   action:@selector(openFromSameDir:)
													keyEquivalent:@""];
						[item setTarget:self];
						[item setRepresentedObject:[superPath stringByAppendingPathComponent:object] ];
						
						if ([object isEqualToString:tmpCurrentBookName]) {
							[item setState:NSControlStateValueOn];
						}
					}
				}
			}
		}
		[openSameFolderMenuItem setSubmenu: menu];
		[lastSameFolderMenuUpdate release];
		lastSameFolderMenuUpdate = [[NSDate date] retain];
	} else {
		if (oldBookPath==nil) {
			return;
		}		
		//NSMenu *menu = [[[NSMenu alloc] init] autorelease];
		NSEnumerator *enumerator = [[[openSameFolderMenuItem submenu] itemArray] objectEnumerator];
		id object;
		int setStateCount = 0;
		while (object = [enumerator nextObject]) {
			if ([[[object representedObject] lastPathComponent] isEqualToString:tmpCurrentBookName]){
				[object setState:NSControlStateValueOn];
				setStateCount++;
			} else if ([object state] == NSControlStateValueOn) {
				[object setState:NSControlStateValueOff];
				setStateCount++;
			}
			if (setStateCount==2) {
				break;
			}
		}
	}
}


-(void)setOpenRecentMenu
{
	NSMutableArray *array;
	if (![defaults arrayForKey:@"RecentItems"]) {
		array = [NSMutableArray array];
	} else {
		array = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentItems"]];
	}
	NSMenu *menu=[openRecentMenuItem submenu];
	while ([menu numberOfItems] > 2) {
		[menu removeItemAtIndex:0];
	}
	NSEnumerator *enumerator = [array reverseObjectEnumerator];
	id object;
	while (object = [enumerator nextObject]) {
		NSString *path = COPathFromStoredEntry(object);
		if (path) {
			if ([path isEqualToString:@"file not found"]) {
				NSMenuItem *menuItem = [[NSMenuItem alloc] 
                initWithTitle:[NSString stringWithFormat:@"file not found"]
					   action:nil 
                keyEquivalent:@""];
				[menuItem setEnabled:NO];
				[menuItem autorelease];
				[menu insertItem:menuItem atIndex:0];
			} else if ([object objectForKey:@"page"]) {
				int page = [[object objectForKey:@"page"] intValue];
				NSMenuItem *menuItem;
				SEL selector = @selector(openFromOpenRecent:);
				if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
					menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (P%i)",[path lastPathComponent],page+1]
														  action:selector
												   keyEquivalent:@""];
				} else {
					menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (P%i)",path,page+1]
														  action:selector
												   keyEquivalent:@""];
					[menuItem setEnabled:NO];
				}
				[menuItem setRepresentedObject:object];
				[menuItem autorelease];
				[menuItem setTarget:self];
				[menu insertItem:menuItem atIndex:0];
			} else {
				NSMenuItem *menuItem = [[NSMenuItem alloc] 
                initWithTitle:[NSString stringWithFormat:@"%@ (-)",[path lastPathComponent]]
					   action:nil 
                keyEquivalent:@""];
				[menuItem autorelease];
				[menu insertItem:menuItem atIndex:0];
			}
		} else {
			NSMenuItem *menuItem = [[[NSMenuItem alloc]
				initWithTitle:NSLocalizedString(@"file not found", @"")
				     action:nil keyEquivalent:@""] autorelease];
			[menuItem setEnabled:NO];
			[menu insertItem:menuItem atIndex:0];
		}
	}
}
- (IBAction)clearRecent:(id)sender
{
	[defaults removeObjectForKey:@"RecentItems"];
	[defaults synchronize];
	[self setOpenRecentMenu];
}


#pragma mark -


- (void)setPageTextField
{
	/*
	if (timerSwitch) {
		[imageView setSlideshow:YES];
	} else {
		[imageView setSlideshow:NO];
	}*/
	[imageView setPageString:[self pageTextFieldString]];
}

- (NSString*)pageTextFieldString
{
	if (numberSwitch && nowPage >= 0) {
		if (!secondImage) {
			int i = nowPage - 1;
			return [NSString stringWithFormat:@"#%d/%d (%@)",nowPage,(int)[completeMutableArray count],[[completeMutableArray objectAtIndex:i] lastPathComponent]];
		} else if (secondImage) {
			int i = nowPage - 1;
			int iS = i - 1;
			if (readMode == 1 || readMode == 3) {
				return [NSString stringWithFormat:@"#%d-%d/%d (%@ | %@)",i,nowPage,(int)[completeMutableArray count],[[completeMutableArray objectAtIndex:iS] lastPathComponent],[[completeMutableArray objectAtIndex:i] lastPathComponent]];
			} else {
				return [NSString stringWithFormat:@"#%d-%d/%d (%@ | %@)",i,nowPage,(int)[completeMutableArray count],[[completeMutableArray objectAtIndex:i] lastPathComponent],[[completeMutableArray objectAtIndex:iS] lastPathComponent]];
			}
		}
	}
	return nil;
}


- (IBAction)changeReadModeMenu:(id)sender
{
    if ([[sender title] isEqualToString:NSLocalizedString(@"Right to Left", @"")] == YES) {
		[self changeReadMode:0];
	} else if ([[sender title] isEqualToString:NSLocalizedString(@"Left to Right", @"")] == YES) {
		[self changeReadMode:1];
	} else if ([[sender title] isEqualToString:NSLocalizedString(@"Right to Left (single)", @"")] == YES) {
		[self changeReadMode:2];
	} else if ([[sender title] isEqualToString:NSLocalizedString(@"Left to Right (single)", @"")] == YES) {
		[self changeReadMode:3];
	}
}


- (IBAction)changeSortModeMenu:(id)sender
{
    if ([[sender title] isEqualToString:NSLocalizedString(@"Name", @"")] == YES) {
		[self setSortMode:0 page:0];
	} else if ([[sender title] isEqualToString:NSLocalizedString(@"Shuffle", @"")] == YES) {
		[self setSortMode:1 page:0];
	} else if ([[sender title] isEqualToString:NSLocalizedString(@"Creation Date", @"")] == YES) {
		[self setSortMode:2 page:0];
	} else if ([[sender title] isEqualToString:NSLocalizedString(@"Modification Date", @"")] == YES) {
		[self setSortMode:3 page:0];
		
	}
}


- (void)goBookmark:(id)sender
{
	//BookmarkMenuItem's action
	//NSLog(@"%d",[sender tag]);
	[imageView setPageString:[NSString stringWithFormat:@"%@",[sender title]]];
	nowPage = [[sender representedObject] intValue] - 1;
	[imageMutableArray removeAllObjects];
	[self lookahead];
	[self imageDisplay];

}


- (IBAction)editBookmark:(id)sender
{
	if (timerSwitch) {
		[timer invalidate];
		timerSwitch=NO;
		[self endSlideshowActivity];
	}
	if ([imageView image]) {
		NSDictionary *dic = [NSDictionary dictionaryWithObject:currentBookPath forKey:@"dirPath"];
		
		[bookmarkController setPathDic:dic];
		[bookmarkController editBookmark:bookmarkArray];
	} else {
		[bookmarkController editAllBookmark:bookmarkArray];
	}
}


- (IBAction)deleteSettings:(id)sender
{	
	NSData *alias = currentBookAlias;
	[currentBookSetting setObject:alias forKey:@"alias"];
	[currentBookSetting setObject:currentBookPath forKey:@"temppath"];
	[currentBookSetting removeObjectForKey:@"readMode"];
	[currentBookSetting removeObjectForKey:@"sortMode"];
	[currentBookSetting removeObjectForKey:@"marks"];
	
	[self changeReadMode:(int)[defaults integerForKey:@"ReadMode"]];
	[self setSortMode:(int)[defaults integerForKey:@"SortMode"] page:-1];
}


#pragma mark -
- (IBAction)fitToScreen:(id)sender
{
	if (fitScreenMode == 0) {
		return;
	}
	[[window contentView] replaceSubview:[imageView enclosingScrollView] with:imageView];
	[imageView setFrame:[[window contentView] frame]];
	
	fitScreenMode = 0;
	[imageView setScreenFitMode:fitScreenMode];
	if (bufferingMode == 0) {
		if (secondImage) {
			[self composeImage];
			[self lookaheadAndCompose];
		} else {
			[imageView setImage:firstImage];
			[self lookaheadAndCompose];
		}
	} else if (bufferingMode == 1 && secondImage) {
		[imageView setImages:firstImage];
	} else {
		[imageView setImage:firstImage];
	}
	[imageView setInfoString:[NSString stringWithFormat:@"Fit to Screen"]];
}

- (IBAction)fitToScreenWidth:(id)sender
{
	if (fitScreenMode == 1) {
		return;
	} else if (fitScreenMode == 0) {
		id scroll = [[NSScrollView alloc] init];
		[scroll setFrame:[[window contentView] frame]];
		[(NSScrollView *)scroll setAutoresizingMask:[(CustomImageView *)imageView autoresizingMask]];
		[scroll setBackgroundColor:[window backgroundColor]];
		[imageView retain];
		[[window contentView] replaceSubview:imageView with:scroll];
		[scroll setDocumentView:imageView];
		[imageView release];
		//[scroll setDocumentCursor:[NSCursor openHandCursor]];
	}
	fitScreenMode = 1;
	[imageView setScreenFitMode:fitScreenMode];
	if (bufferingMode == 0) {
		if (secondImage) {
			[self composeImage];
			[self lookaheadAndCompose];
		} else {
			[imageView setImage:firstImage];
			[self lookaheadAndCompose];
		}
	} else if (bufferingMode == 1 && secondImage) {
		[imageView setImages:firstImage];
	} else {
		[imageView setImage:firstImage];
	}	
	[imageView setInfoString:[NSString stringWithFormat:@"Fit to Screen Width"]];
}

- (IBAction)fitToScreenWidthDivide:(id)sender
{
	if (fitScreenMode == 3) {
		return;
	} else if (fitScreenMode == 0) {
		id scroll = [[NSScrollView alloc] init];
		[scroll setFrame:[[window contentView] frame]];
        [(NSScrollView *)scroll setAutoresizingMask:[(CustomImageView *)imageView autoresizingMask]];
		[scroll setBackgroundColor:[window backgroundColor]];
		[imageView retain];
		[[window contentView] replaceSubview:imageView with:scroll];
		[scroll setDocumentView:imageView];
		[imageView release];
		//[scroll setDocumentCursor:[NSCursor openHandCursor]];
	}
	fitScreenMode = 3;
	[imageView setScreenFitMode:fitScreenMode];
	if (bufferingMode == 0) {
		if (secondImage) {
			[self composeImage];
			[self lookaheadAndCompose];
		} else {
			[imageView setImage:firstImage];
			[self lookaheadAndCompose];
		}
	} else if (bufferingMode == 1 && secondImage) {
		[imageView setImages:firstImage];
	} else {
		[imageView setImage:firstImage];
	}	
	[imageView setInfoString:[NSString stringWithFormat:@"Fit to Screen Width(Divide)"]];
}

- (IBAction)noScale:(id)sender
{
	if (fitScreenMode == 2) {
		return;
	} else if (fitScreenMode == 0) {
		id scroll = [[NSScrollView alloc] init];		
		[scroll setFrame:[[window contentView] frame]];
        [(NSScrollView *)scroll setAutoresizingMask:[(CustomImageView *)imageView autoresizingMask]];
		[scroll setBackgroundColor:[window backgroundColor]];
		[imageView retain];
		[[window contentView] replaceSubview:imageView with:scroll];
		[scroll setDocumentView:imageView];
		[imageView release];
		//[scroll setDocumentCursor:[NSCursor openHandCursor]];
	}
	fitScreenMode = 2;
	[imageView setScreenFitMode:fitScreenMode];
	if (bufferingMode == 0) {
		if (secondImage) {
			[self composeImage];
			[self lookaheadAndCompose];
		} else {
			[imageView setImage:firstImage];
			[self lookaheadAndCompose];
		}
	} else if (bufferingMode == 1 && secondImage) {
		[imageView setImages:firstImage];
	} else {
		[imageView setImage:firstImage];
	}
	[imageView setInfoString:[NSString stringWithFormat:@"No Scale"]];
}

- (IBAction)rotateRight:(id)sender
{
	rotateMode--;
	if (rotateMode < 0) {
		rotateMode = 3;
	}
	[imageView rotateRight];
}
- (IBAction)rotateLeft:(id)sender
{
	rotateMode++;
	if (rotateMode > 3) {
		rotateMode = 0;
	}
	[imageView rotateLeft];
}

- (IBAction)showFilterPanel:(id)sender
{
    IKImageEditPanel *editor = [IKImageEditPanel sharedImageEditPanel];
    [editor makeKeyAndOrderFront:nil];
}

#pragma mark -


- (IBAction)fullscreen:(id)sender
{
	[window toggleFullScreen:sender];
}

- (void)updateImageAfterFullScreenChange
{
	if (!firstImage && !secondImage) return;
	if (bufferingMode == 0) {
		if (secondImage) {
			[self composeImage];
			[self lookaheadAndCompose];
		} else {
			[imageView setImage:firstImage];
			[self lookaheadAndCompose];
		}
    } else {
        if (secondImage) {
            [imageView setImages:secondImage];
        } else {
            [imageView setImage:firstImage];
        }
    }
}

- (void)enterRestoredFullScreen
{
	if ([window isVisible] && ![window isFullScreen]) [window toggleFullScreen:self];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if ([notification object] == window && restoreFullscreenOnNextKey) {
		restoreFullscreenOnNextKey = NO;
		[self performSelector:@selector(enterRestoredFullScreen) withObject:nil afterDelay:0];
	}
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
	[defaults setBool:YES forKey:@"Fullscreen"];
	[self updateImageAfterFullScreenChange];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
	[defaults setBool:NO forKey:@"Fullscreen"];
	[self updateImageAfterFullScreenChange];
}


-(void)viewSet
{
	[imageView wheelSetting:wheelSensitivity];
	[thumController wheelSetting:wheelSensitivity];
}



- (void)windowWillClose:(NSNotification *)aNotofication
{
	[lock lock];
	[lock unlock];
	if ([window isVisible]) {
		[thumController setImageLoader:nil];
		if (timerSwitch) {
			[timer invalidate];
			timerSwitch=NO;
			[self endSlideshowActivity];
		}
		if ([bookmarkMenuItem numberOfItems] > 2) {
			while ([bookmarkMenuItem numberOfItems] > 2) {
				[bookmarkMenuItem removeItemAtIndex:2];
			}
		}
		int iA;
		for (iA=0; iA<[[openSameFolderMenuItem submenu] numberOfItems]; iA++) {
			if ([[[openSameFolderMenuItem submenu] itemAtIndex:iA] state] == NSControlStateValueOn) {
				[[[openSameFolderMenuItem submenu] itemAtIndex:iA] setState:NSControlStateValueOff];
				break;
			}
		}
		if (currentBookPath != nil) {
			NSData *aliasData = currentBookAlias;
			
			/*bookmark&booksettings保存*/	
			NSMutableDictionary *dic;
			if (![defaults dictionaryForKey:@"BookSettings"]) {
				dic = [NSMutableDictionary dictionary];
			} else {
				dic = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"BookSettings"]];
			}
			id key;
			[self searchFromBookSettings:currentBookPath key:&key];
			
			if (!rememberBookSettings) {
				[currentBookSetting removeAllObjects];
			}
			
			[currentBookSetting setObject:aliasData forKey:@"alias"];
			[currentBookSetting setObject:currentBookPath forKey:@"temppath"];
			if ([bookmarkArray count]>0) {
				[currentBookSetting setObject:bookmarkArray forKey:@"bookmarks"];
			} else if ([bookmarkArray count]==0) {
				[currentBookSetting removeObjectForKey:@"bookmarks"];
			}
			if ([currentBookSetting count]>2) {
				if (!key) {
					key = currentBookName;
					int i = 2;
					while ([dic objectForKey:key]) {
						key = [NSString stringWithFormat:@"%@#%i",currentBookName,i];
						i++;
					}
					[dic setObject:currentBookSetting forKey:key];
				} else {
					[dic setObject:currentBookSetting forKey:key];
				}
				[defaults setObject:dic forKey:@"BookSettings"];
			}
			
			/*historyの処理*/	
			if (secondImage) {
				nowPage -= 2;
			} else {
				nowPage--;
			}
			NSNumber *pageNumber = [NSNumber numberWithInt:nowPage];
			if (openRecentLimit>0) {			
				NSMutableArray *array;
				if (![defaults arrayForKey:@"RecentItems"]) {
					array = [NSMutableArray array];
				} else {
					array = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentItems"]];
				}
				NSEnumerator *enu = [array objectEnumerator];
				id object;
				while (object = [enu nextObject]) {
					if ([COPathFromStoredEntry(object) isEqualToString:currentBookPath]) {
						[array removeObject:object];
						break;
					}
				}
				while ([array count] >= openRecentLimit) {
					[array removeLastObject];
				}
				[array insertObject:[NSDictionary dictionaryWithObjectsAndKeys:aliasData,@"alias",pageNumber,@"page",currentBookPath,@"temppath",nil] atIndex:0];
				[defaults setObject:array forKey:@"RecentItems"];
			} else {
				[defaults removeObjectForKey:@"RecentItems"];
			}
			if (alwaysRememberLastPage && nowPage > 0) {
				NSMutableArray *array;
				if (![defaults arrayForKey:@"LastPages"]) {
					array = [NSMutableArray array];
				} else {
					array = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"LastPages"]];
				}
				NSEnumerator *enu = [array objectEnumerator];
				id object;
				while (object = [enu nextObject]) {
					if ([COPathFromStoredEntry(object) isEqualToString:currentBookPath]) {
						[array removeObject:object];
						break;
					}
				}
				[array addObject:[NSDictionary dictionaryWithObjectsAndKeys:aliasData,@"alias",pageNumber,@"page",currentBookPath,@"temppath",nil]];
				[defaults setObject:array forKey:@"LastPages"];
			} else if (!alwaysRememberLastPage || nowPage == 0) {
				NSMutableArray *lastPages;
				if (![defaults arrayForKey:@"LastPages"]) {
					lastPages = [NSMutableArray array];
				} else {
					lastPages = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"LastPages"]];
				}
				int index;
				id object = [self searchFromLastPages:currentBookPath index:&index];
				if (object) {
					[lastPages removeObjectAtIndex:index];
				}
				[defaults setObject:lastPages forKey:@"LastPages"];
			}
			[defaults synchronize];
		}
		
		[imageView setPageString:nil];
		[NSCursor setHiddenUntilMouseMoves:NO];
		[imageView setImage:nil];
		[firstImage release];
		firstImage = nil;
		[secondImage release];
		secondImage = nil;
		[composedImage release];
		composedImage = nil;
		
		[completeMutableArray release];
		completeMutableArray = nil;
		oldBookPath = currentBookPath;
		oldBookName = currentBookName;
		oldBookAlias = currentBookAlias;
		currentBookPath = nil;
		currentBookName = nil;
		currentBookAlias = nil;
		[imageMutableArray removeAllObjects];
		[bookmarkArray removeAllObjects];
		[marksArray removeAllObjects];
		[self setOpenRecentMenu];
		
		[cacheArray removeAllObjects];
		[screenCacheArray removeAllObjects];
		if (imageLoader) {
			[imageLoader release];
			imageLoader = nil;
		}
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[self endSlideshowActivity];
	[defaults synchronize];
}
- (void)applicationDidBecomeActive:(NSNotification *)aNotification {
	[self checkCurrentFolderUpdated];
}




- (void)viewDidEndLiveResize:(NSNotification *)aNotification
{
    if (bufferingMode == 0) {
        if (secondImage) {
            [self composeImage];
            [self lookaheadAndCompose];
        } else {
            [imageView setImage:firstImage];
            [self lookaheadAndCompose];
        }
    } else {
        if (secondImage) {
            [imageView setImages:secondImage];
        } else {
            [imageView setImage:firstImage];
        }
    }
}

- (void)openLink:(NSURL *)url
{
	if (openLinkMode==2) return;
	
	if (openLinkMode != 0 || COConfirmAction(NSLocalizedString(@"Open URL", @""),
		[NSString stringWithFormat:NSLocalizedString(@"Open '%@' in default browser?", @""), url])) {
		 [[NSWorkspace sharedWorkspace] openURL:url];
	}
}


#pragma mark -
#pragma mark return


-(int)maxEnlargement
{
	return maxEnlargement;
}
-(int)readMode
{
	return readMode;
}

-(BOOL)readFromLeft
{
	if (readMode == 1 || readMode == 3) {
		return YES;
	} else {
		return NO;
	}
}

-(BOOL)firstImage
{
	if (secondImage) {
		return YES;
	} else {
		return NO;
	}
}
-(id)image1
{
	return firstImage;
}
-(id)image2
{
	return secondImage;
}
-(BOOL)indicator
{
	return pageBar;
}

-(float)nowPar
{
	float count = [completeMutableArray count];
	float temp = nowPage;
	float par = temp/count;
	if (par > 1) {
		par = 0.0;
	}
	return par;
}

-(int)nowPage
{
	int temp;
	if (secondImage) {
		temp = nowPage;
		temp--;
	} else {
		temp = nowPage;
	}
	return temp;
}

-(int)pageCount
{
	return (int)[completeMutableArray count];
}

-(NSArray*)bookmarkArray
{
	return bookmarkArray;
}

- (id)openSameFolderMenuItem
{
	return [openSameFolderMenuItem submenu];
}

- (int)sortMode
{
	return sortMode;
}

- (int)openLinkMode
{
	return openLinkMode;
}


#pragma mark -


#pragma mark File bookmarks
- (NSString *)pathFromAliasData:(NSData *)data
{
    return COPathFromStoredBookmark(data);
}

- (NSData *)aliasDataFromPath:(NSString *)path
{
    return COBookmarkDataFromPath(path);
}

- (void)migrateStoredFileBookmarks
{
    for (NSString *key in [NSArray arrayWithObjects:@"BookSettings", @"RecentItems", @"LastPages", nil]) {
        id collection = [defaults objectForKey:key];
        BOOL changed = NO;
        id migrated = COMigrateStoredBookmarksInCollection(collection, &changed);
        if (changed) [defaults setObject:migrated forKey:key];
    }
}

#pragma mark searchFrom
- (id)searchFromBookSettings:(NSString*)path key:(NSString**)key
{
	if ([defaults dictionaryForKey:@"BookSettings"]) {
		NSEnumerator *enu = [[defaults dictionaryForKey:@"BookSettings"] objectEnumerator];
		id object;
		while (object = [enu nextObject]) {
			if ([[object objectForKey:@"temppath"] isEqualToString:path]) {
				NSString *resolved = [self pathFromAliasData:[object objectForKey:@"alias"]];
				if (!resolved || [resolved isEqualToString:path]) {
					if (key) {
						*key = [[[defaults dictionaryForKey:@"BookSettings"] allKeysForObject:object] objectAtIndex:0];
						//*key = [NSString stringWithString:[[settings allKeysForObject:object] objectAtIndex:0]];
					}
					return [NSDictionary dictionaryWithDictionary:object];
				}
			}
		}
		
		NSMutableDictionary *newDic = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"BookSettings"]];
		NSEnumerator *enuS = [newDic keyEnumerator];
		id tempKey;
		while (tempKey = [enuS nextObject]) {
			if ([[self pathFromAliasData:[[newDic objectForKey:tempKey] objectForKey:@"alias"]] isEqualToString:path]) {
				NSMutableDictionary *newInnerDic = [NSMutableDictionary dictionaryWithDictionary:[newDic objectForKey:tempKey]];
				[newInnerDic setObject:path forKey:@"temppath"];
				[newDic setObject:newInnerDic forKey:tempKey];
				
				if (key) {
					*key = tempKey;
				}
				[defaults setObject:newDic forKey:@"BookSettings"];
				return [NSDictionary dictionaryWithDictionary:newInnerDic];
			}
		}		
	}
	if (key) *key = nil;
	return nil;
}

- (id)searchFromRecentItems:(NSString*)path index:(int *)index
{
	if ([defaults arrayForKey:@"RecentItems"]) {
		NSEnumerator *enu = [[defaults arrayForKey:@"RecentItems"] objectEnumerator];
		id object;
		while (object = [enu nextObject]) {
			if ([[object objectForKey:@"temppath"] isEqualToString:path]) {
				NSString *resolved = [self pathFromAliasData:[object objectForKey:@"alias"]];
				if (!resolved || [resolved isEqualToString:path]) {
					if (index) {
						*index = (int)[[defaults arrayForKey:@"RecentItems"] indexOfObject:object];
					}
					return [NSDictionary dictionaryWithDictionary:object];
				}
			}
		}
		
		NSEnumerator *enuS = [[defaults arrayForKey:@"RecentItems"] objectEnumerator];
		while (object = [enuS nextObject]) {
			if ([[self pathFromAliasData:[object objectForKey:@"alias"]] isEqualToString:path]) {
				NSMutableArray *newArray = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentItems"]];
				NSMutableDictionary *newInnerDic = [NSMutableDictionary dictionaryWithDictionary:object];
				int tempIndex = (int)[[defaults arrayForKey:@"RecentItems"] indexOfObject:object];
				[newArray removeObjectAtIndex:tempIndex];
				[newInnerDic setObject:path forKey:@"temppath"];
				[newArray insertObject:newInnerDic atIndex:tempIndex];
				
				if (index) {
					*index = tempIndex;
					
				}
				[defaults setObject:newArray forKey:@"RecentItems"];
				return [NSDictionary dictionaryWithDictionary:newInnerDic];
			}
		}
		
	}
	if (index) *index = -1;
	return nil;
}

- (id)searchFromLastPages:(NSString*)path index:(int*)index
{
	if ([defaults arrayForKey:@"LastPages"]) {
		NSEnumerator *enu = [[defaults arrayForKey:@"LastPages"] objectEnumerator];
		id object;
		while (object = [enu nextObject]) {
			if ([[object objectForKey:@"temppath"] isEqualToString:path]) {
				NSString *resolved = [self pathFromAliasData:[object objectForKey:@"alias"]];
				if (!resolved || [resolved isEqualToString:path]) {
					if (index) {
						*index = (int)[[defaults arrayForKey:@"LastPages"] indexOfObject:object];
					}
					return [NSDictionary dictionaryWithDictionary:object];
				}
			}
		}
		
		NSEnumerator *enuS = [[defaults arrayForKey:@"LastPages"] objectEnumerator];
		while (object = [enuS nextObject]) {
			if ([[self pathFromAliasData:[object objectForKey:@"alias"]] isEqualToString:path]) {
				NSMutableArray *newArray = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"LastPages"]];
				NSMutableDictionary *newInnerDic = [NSMutableDictionary dictionaryWithDictionary:object];
				int tempIndex = (int)[[defaults arrayForKey:@"LastPages"] indexOfObject:object];
				[newArray removeObjectAtIndex:tempIndex];
				[newInnerDic setObject:path forKey:@"temppath"];
				[newArray insertObject:newInnerDic atIndex:tempIndex];
				
				if (index) {
					*index = (int)[[defaults arrayForKey:@"LastPages"] indexOfObject:object];
				}
				[defaults setObject:newArray forKey:@"LastPages"];
				return [NSDictionary dictionaryWithDictionary:newInnerDic];
			}
		}
		
	}
	if (index) *index = -1;
	return nil;
}

- (id)searchFromBookSettings:(NSString*)path key:(NSString**)key more:(BOOL)b
{
	id searched = [self searchFromBookSettings:path key:key];
	if (searched) {
		return searched;
	} else if (!searched && b && [defaults dictionaryForKey:@"BookSettings"]) {
		NSString *temp;
		
		NSMutableDictionary *newDic = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"BookSettings"]];
		NSEnumerator *enuS = [newDic keyEnumerator];
		id tempKey;
		
		while (tempKey = [enuS nextObject]) {
			temp = COPathFromStoredEntry([newDic objectForKey:tempKey]);
			if ([[temp lastPathComponent] isEqualToString:[path lastPathComponent]] && ![[NSFileManager defaultManager] fileExistsAtPath:temp]) {
				
				if (COConfirmAction(NSLocalizedString(@"Setting is not found", @""),
					[NSString stringWithFormat:NSLocalizedString(@"Setting of %@ is not found.\nDo you want to use a setting of %@ ?", @""), path, temp])) {
					/*LastPagesの修正*/
					int lastPagesIndex;
					id lastPage = [self searchFromLastPages:temp index:&lastPagesIndex];
					if (lastPage) { 
						NSMutableDictionary *newLastPage = [NSMutableDictionary dictionaryWithDictionary:lastPage];
						NSMutableArray *newLastPagesArray = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"LastPages"]];
						[newLastPage setObject:path forKey:@"temppath"];
						[newLastPage setObject:[self aliasDataFromPath:path] forKey:@"alias"];
						[newLastPagesArray removeObjectAtIndex:lastPagesIndex];
						[newLastPagesArray insertObject:newLastPage atIndex:lastPagesIndex];
						[defaults setObject:newLastPagesArray forKey:@"LastPages"];
					}
					/*RecentItemsの修正*/
					int recentItemsIndex;
					id recentItem = [self searchFromRecentItems:temp index:&recentItemsIndex];
					if (recentItem) { 
						NSMutableDictionary *newRecentItem = [NSMutableDictionary dictionaryWithDictionary:recentItem];
						NSMutableArray *newRecentItemsArray = [NSMutableArray arrayWithArray:[defaults arrayForKey:@"RecentItems"]];
						[newRecentItem setObject:path forKey:@"temppath"];
						[newRecentItem setObject:[self aliasDataFromPath:path] forKey:@"alias"];
						[newRecentItemsArray removeObjectAtIndex:recentItemsIndex];
						[newRecentItemsArray insertObject:newRecentItem atIndex:recentItemsIndex];
						[defaults setObject:newRecentItemsArray forKey:@"RecentItems"];
					}					
					/*BookSettingsの修正*/
					NSMutableDictionary *newInnerDic = [NSMutableDictionary dictionaryWithDictionary:[newDic objectForKey:tempKey]];
					[newInnerDic setObject:path forKey:@"temppath"];
					[newInnerDic setObject:[self aliasDataFromPath:path] forKey:@"alias"];
					[newDic setObject:newInnerDic forKey:tempKey];
					
					if (key) {
						*key = tempKey;
					}
					[defaults setObject:newDic forKey:@"BookSettings"];
					return [NSDictionary dictionaryWithDictionary:newInnerDic];
				}
			}
		}
	}
	return nil;
}
@end

@implementation Controller(private)
-(void)setCurrentBookPath:(NSString *)new
{	
	currentBookPath = [new retain];
	currentBookName = [[currentBookPath lastPathComponent] retain];
	currentBookAlias = [[self aliasDataFromPath:currentBookPath] retain];
}
-(void)setOldBookPath
{	
	oldBookPath = currentBookPath;
	oldBookName = currentBookName;
	oldBookAlias = currentBookAlias;
}
-(void)setCurrentBookPathAndOldBookPath:(NSString *)new 
{
	if (currentBookPath!=nil) {
		[self setOldBookPath];
	}
	[self setCurrentBookPath:new];
}
- (void)checkCurrentFolderUpdated
{
	if (changeCurrentFolderMode==2) return;
	
	if (currentBookPath!=nil) {
		NSString *oldSuperPath = [currentBookPath stringByDeletingLastPathComponent];
		
		NSString *tmpCurrentPath = [self pathFromAliasData:currentBookAlias];
		NSString *superPath = [tmpCurrentPath stringByDeletingLastPathComponent];
		
		BOOL updateMenu = NO;
		if (![oldSuperPath isEqualToString:superPath]) {
			
			if (changeCurrentFolderMode != 0 ||
				COConfirmAction(NSLocalizedString(@"Change current folder", @""),
					NSLocalizedString(@"The current opening book was moved. Are you sure you want to change current folder?", @""))) {
				updateMenu = YES;
			} else {
				NSEnumerator *enumerator = [[[openSameFolderMenuItem submenu] itemArray] objectEnumerator];
				id object;
				while (object = [enumerator nextObject]) {
					if ([object state] == NSControlStateValueOn){
						[object setEnabled:NO];
						break;
					}
				}
			}
		} else {
            NSDate *updateDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:[superPath stringByResolvingSymlinksInPath] error:nil] fileModificationDate];
			NSComparisonResult res = [lastSameFolderMenuUpdate compare:updateDate];
			if (res == NSOrderedAscending) {
				updateMenu = YES;
			}
		}
		if (updateMenu) {
			[self setSameFolderMenu:YES];
		}
	}
	
}

@end
