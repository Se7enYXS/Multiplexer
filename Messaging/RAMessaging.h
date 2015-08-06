#import <UIKit/UIKit.h>

enum {
	RAMessageTypeUpdateAppData = 0,

	RAMessageTypeShowKeyboard,
	RAMessageTypeHideKeyboard,
	RAMessageTypeUpdateKeyboardContextId,
	RAMessageTypeRetrieveKeyboardContextId,
} RAMessageType;

struct RAMessageAppData {
//	NSString *bundleIdentifier;
	BOOL shouldForceSize;
	CGSize wantedClientSize;
	BOOL statusBarVisibility;
	BOOL shouldForceStatusBar;
	BOOL canHideStatusBarIfWanted;
	UIInterfaceOrientation forcedOrientation;
	BOOL shouldForceOrientation;

	BOOL shouldUseExternalKeyboard;
};

static NSString *RAMessagingUpdateAppInfoMessageName = @"updateAppInfo";
static NSString *RAMessagingShowKeyboardMessageName = @"showKeyboard";
static NSString *RAMessagingHideKeyboardMessageName = @"hideKeyboard";
static NSString *RAMessagingUpdateKeyboardContextIdMessageName = @"updateKBContextId";
static NSString *RAMessagingRetrieveKeyboardContextIdMessageName = @"getKBContextId";

typedef void (^RAMessageCompletionCallback)(BOOL success);