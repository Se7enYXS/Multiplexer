#import "RAHostedAppView.h"
#import "BioLockdown.h"
#import "RAHostManager.h"
#import "RAMessagingServer.h"

@interface RAHostedAppView () {
    NSTimer *verifyTimer;
    BOOL isPreloading;
    FBWindowContextHostManager *contextHostManager;
    UIActivityIndicatorView *activityView;

    UILabel *biolockdownDidFailLabel;
    UITapGestureRecognizer *biolockdownFailedRetryTapGesture;
}
@end

@implementation RAHostedAppView
-(id) initWithBundleIdentifier:(NSString*)bundleIdentifier
{
	if (self = [super init])
	{
		self.bundleIdentifier = bundleIdentifier;
        self.autosizesApp = NO;
        self.allowHidingStatusBar = YES;
	}
	return self;
}

-(void) _preloadOrAttemptToUpdateReachabilityCounterpart
{
    if (app)
    {
        if ([app mainScene])
        {
            isPreloading = NO;
            if (((SBReachabilityManager*)[%c(SBReachabilityManager) sharedInstance]).reachabilityModeActive && [[%c(SBWorkspace) sharedInstance] respondsToSelector:@selector(RA_updateViewSizes)])
                [[%c(SBWorkspace) sharedInstance] performSelector:@selector(RA_updateViewSizes) withObject:nil afterDelay:0.5]; // App is launched using ReachApp - animations commence. We have to wait for those animations to finish or this won't work.
        }
        else if (![app mainScene])
            [self preloadApp];
    }
}

-(void) setBundleIdentifier:(NSString*)value
{
    _orientation = UIInterfaceOrientationPortrait;
    _bundleIdentifier = value;
    app = [[%c(SBApplicationController) sharedInstance] RA_applicationWithBundleIdentifier:value];
}

-(void) setShouldUseExternalKeyboard:(BOOL)value
{
    _shouldUseExternalKeyboard = value;
    [RAMessagingServer.sharedInstance setShouldUseExternalKeyboard:value forApp:self.bundleIdentifier completion:nil];
}

-(void) preloadApp
{
    if (app == nil)
        return;
    isPreloading = YES;
	FBScene *scene = [app mainScene];
    if (![app pid] || scene == nil)
    {
        [UIApplication.sharedApplication launchApplicationWithIdentifier:self.bundleIdentifier suspended:YES];
        [[%c(FBProcessManager) sharedInstance] createApplicationProcessForBundleID:self.bundleIdentifier];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [self _preloadOrAttemptToUpdateReachabilityCounterpart]; }); 
    // this ^ runs either way. when _preloadOrAttemptToUpdateReachabilityCounterpart runs, if the app is "loaded" it will not call preloadApp again, otherwise
    // it will call it again.
}

-(void) _actualLoadApp
{
    view = (FBWindowContextHostWrapperView*)[RAHostManager enabledHostViewForApplication:app];
    contextHostManager = (FBWindowContextHostManager*)[RAHostManager hostManagerForApp:app];
    view.backgroundColorWhileNotHosting = [UIColor clearColor];
    view.backgroundColorWhileHosting = [UIColor clearColor];

    view.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    //view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self addSubview:view];

    if (verifyTimer)
        [verifyTimer invalidate];

    verifyTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(verifyHostingAndRehostIfNecessary) userInfo:nil repeats:YES];
    [NSRunLoop.currentRunLoop addTimer:verifyTimer forMode:NSRunLoopCommonModes];
}

-(void) loadApp
{
	[self preloadApp];
    if (!app)
        return;

    IF_BIOLOCKDOWN {

        id failedBlock = ^{
            if (!biolockdownDidFailLabel)
            {
                biolockdownDidFailLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, (self.frame.size.height - 40) / 2, self.frame.size.width, 40)];
                biolockdownDidFailLabel.textColor = [UIColor whiteColor];
                biolockdownDidFailLabel.textAlignment = NSTextAlignmentCenter;
                biolockdownDidFailLabel.font = [UIFont systemFontOfSize:36];
                biolockdownDidFailLabel.text = [NSString stringWithFormat:LOCALIZE(@"BIOLOCKDOWN_AUTH_FAILED"),self.app.displayName];
                [self addSubview:biolockdownDidFailLabel];

                biolockdownFailedRetryTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(loadApp)];
                [self addGestureRecognizer:biolockdownFailedRetryTapGesture];
                self.userInteractionEnabled = YES;
            }
        };

        BIOLOCKDOWN_AUTHENTICATE_APP(app.bundleIdentifier, ^{
            [self _actualLoadApp];
        }, failedBlock /* stupid commas */);
    }
    else
        [self _actualLoadApp];

    if (!activityView)
    {
        activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [self addSubview:activityView];
    }

    CGFloat size = 50;
    activityView.frame = CGRectMake((self.frame.size.width - size) / 2, (self.frame.size.height - size) / 2, size, size);

    [activityView startAnimating];
}

-(void) verifyHostingAndRehostIfNecessary
{
    if (!isPreloading && (app.isRunning == NO || view.contextHosted == NO)) // && (app.pid == 0 || view == nil || view.manager == nil)) // || view._isReallyHosting == NO))
    {
        [activityView startAnimating];
        [self unloadApp];
        [self loadApp];
    }
    else
        [activityView stopAnimating];
}

-(void) setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [view setFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];

    if (self.autosizesApp)
    {
        RAMessageAppData data = [RAMessagingServer.sharedInstance getDataForIdentifier:self.bundleIdentifier];
        data.canHideStatusBarIfWanted = self.allowHidingStatusBar;
        [RAMessagingServer.sharedInstance setData:data forIdentifier:self.bundleIdentifier];
        [RAMessagingServer.sharedInstance resizeApp:self.bundleIdentifier toSize:CGSizeMake(frame.size.width, frame.size.height) completion:nil];

    }
    else if (self.bundleIdentifier)
    {
        [RAMessagingServer.sharedInstance endResizingApp:self.bundleIdentifier completion:nil];
    }
}

-(void) setHideStatusBar:(BOOL)value
{
    _hideStatusBar = value;

    if (!self.bundleIdentifier)
        return;

    if (value)
        [RAMessagingServer.sharedInstance forceStatusBarVisibility:value forApp:self.bundleIdentifier completion:nil];
    else
        [RAMessagingServer.sharedInstance unforceStatusBarVisibilityForApp:self.bundleIdentifier completion:nil];
}

-(void) unloadApp
{
    if (activityView)
        [activityView stopAnimating];
    [verifyTimer invalidate];
	FBScene *scene = [app mainScene];

    if (biolockdownDidFailLabel)
    {
        [biolockdownDidFailLabel removeFromSuperview];
        biolockdownDidFailLabel = nil;

        [self removeGestureRecognizer:biolockdownFailedRetryTapGesture];
        self.userInteractionEnabled = NO;
    }

    if (!scene)
        return;

    [RAMessagingServer.sharedInstance endResizingApp:self.bundleIdentifier completion:^(BOOL success) {
        FBSMutableSceneSettings *settings = [[scene mutableSettings] mutableCopy];
        SET_BACKGROUNDED(settings, YES);
        [scene _applyMutableSettings:settings withTransitionContext:nil completion:nil];
        //FBWindowContextHostManager *contextHostManager = [scene contextHostManager];
        [contextHostManager disableHostingForRequester:@"reachapp"];
        contextHostManager = nil;
    }];
}

-(void) rotateToOrientation:(UIInterfaceOrientation)o
{
    _orientation = o;

    [RAMessagingServer.sharedInstance rotateApp:self.bundleIdentifier toOrientation:o completion:nil];
}

// This allows for any subviews with gestures (e.g. the SwipeOver bar with a negative y origin) to recieve touch events.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event 
{
    BOOL isContained = NO;
    for (UIView *subview in self.subviews)
    {
        if (CGRectContainsPoint(subview.frame, point)) // [self convertPoint:point toView:view]))
            isContained = YES;
    }
    return isContained;
}

-(SBApplication*) app { return app; }
-(NSString*) displayName { return app.displayName; }
@end