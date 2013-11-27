#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <CoreFoundation/CoreFoundation.h>
#import "NRUReachabilityHelper.h"

NSString *const NRUNetworkReachabilityChangedNotification = @"kNRUNetworkReachabilityChangedNotification";

#define kShouldPrintReachabilityFlags 0

inline static void PrintReachabilityFlags(SCNetworkReachabilityFlags    flags, const char* comment) {
#if kShouldPrintReachabilityFlags
	
    NSLog(@"Reachability Flag Status: %c%c %c%c%c%c%c%c%c %s\n",
			(flags & kSCNetworkReachabilityFlagsIsWWAN)				  ? 'W' : '-',
			(flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
			
			(flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
			(flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
			(flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
			(flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
			(flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
			(flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
			(flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-',
			comment
			);
#endif
}


@interface NRUReachabilityHelper () {
	struct {
		unsigned int _alreadyStarted:1;
		unsigned int _invokeNotificationBlockOnMainRunLoop:1;
	} _flags;
}
@property (nonatomic, readwrite, assign) BOOL localWiFiRef;
@property (nonatomic, readwrite, assign) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, readwrite, assign) NRUReachabilityStatusNetworkStatus lastReachabilityStatus;
@property (nonatomic, assign) CFRunLoopRef runLoop;
@end


@implementation NRUReachabilityHelper

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
	@autoreleasepool {
		#pragma unused (target, flags)
		NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
		NSCAssert([(__bridge NSObject*) info isKindOfClass: [NRUReachabilityHelper class]], @"info was wrong class in ReachabilityCallback");

		//We're on the main RunLoop, so an NSAutoreleasePool is not necessary, but is added defensively
		// in case someon uses the Reachablity object in a different thread.
	
		NRUReachabilityHelper* noteObject = (__bridge NRUReachabilityHelper*) info;
		[noteObject handleReachabilityCallback];
	}
}

- (void)handleReachabilityCallback {
	// Post a notification to notify the client that the network reachability changed.
	if (nil!=_notificationBlock) {
		if (_flags._invokeNotificationBlockOnMainRunLoop)
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				_notificationBlock(self);
			}];
		else
			_notificationBlock(self);
	}
	[[NSNotificationCenter defaultCenter] postNotificationName: NRUNetworkReachabilityChangedNotification object: self];
}

- (instancetype)initWithReachabilityRef:(SCNetworkReachabilityRef)reachability localWiFi:(BOOL)localwifi {
	self = [super init];
	if (nil!=self) {
		self.reachabilityRef = reachability;
		self.localWiFiRef = localwifi;
	}
	return self;
}

-(void)setReachabilityRef:(SCNetworkReachabilityRef)reachability {
	if (NULL!=_reachabilityRef)
		CFRelease(_reachabilityRef), _reachabilityRef = NULL;
	_reachabilityRef = CFRetain(reachability);
}

- (BOOL) startNotifier {
	BOOL retVal = NO;
	if ( _flags._alreadyStarted )
		return retVal;
	
	SCNetworkReachabilityContext context;
	memset(&context, 0, sizeof(SCNetworkConnectionContext));
	context.info = (__bridge void *)(self);
	_runLoop = CFRunLoopGetCurrent();
	if(SCNetworkReachabilitySetCallback(self.reachabilityRef, ReachabilityCallback, &context))
		if(SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityRef, _runLoop, kCFRunLoopDefaultMode))
			retVal = YES, _flags._alreadyStarted = YES;
	return retVal;
}

- (void) stopNotifier {
	if(_reachabilityRef!= NULL) {
		SCNetworkReachabilitySetCallback(_reachabilityRef, NULL, NULL);
		SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, _runLoop?_runLoop : CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}
}

- (void) dealloc {
	[self stopNotifier];
	if(_reachabilityRef!= NULL)
		CFRelease(_reachabilityRef);
}

+ (NRUReachabilityHelper*) reachabilityWithHostName: (NSString*) hostName {
	NRUReachabilityHelper* retVal = nil;
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, hostName.UTF8String);
	if(reachability!= NULL) {
		retVal= [[NRUReachabilityHelper alloc] initWithReachabilityRef:reachability localWiFi:NO];
		CFRelease(reachability);
	}
	return retVal;
}

+ (NRUReachabilityHelper*) reachabilityWithAddress: (const struct sockaddr_in*) hostAddress {
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr*)hostAddress);
	NRUReachabilityHelper* retVal = nil;
	if(reachability!= NULL) {
		retVal= [[NRUReachabilityHelper alloc] initWithReachabilityRef:reachability localWiFi:NO];
		CFRelease(reachability);
	}
	return retVal;
}

+ (NRUReachabilityHelper*) reachabilityForInternetConnection {
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
	return [self reachabilityWithAddress: &zeroAddress];
}

+ (NRUReachabilityHelper*) reachabilityForLocalWiFi {
	struct sockaddr_in localWifiAddress;
	bzero(&localWifiAddress, sizeof(localWifiAddress));
	localWifiAddress.sin_len = sizeof(localWifiAddress);
	localWifiAddress.sin_family = AF_INET;
	// IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
	localWifiAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
	NRUReachabilityHelper* retVal = [self reachabilityWithAddress: &localWifiAddress];
	if(retVal!= nil)
		retVal.localWiFiRef = YES;
	return retVal;
}

#pragma mark Network Flag Handling

- (NRUReachabilityStatusNetworkStatus) localWiFiStatusForFlags: (SCNetworkReachabilityFlags) flags {
	PrintReachabilityFlags(flags, "localWiFiStatusForFlags");

	NRUReachabilityStatusNetworkStatus retVal = NRUReachabilityStatusNotReachable;
	if((flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsDirect))
		retVal = NRUReachabilityStatusReachableViaWiFi;

	return retVal;
}

- (NRUReachabilityStatusNetworkStatus) networkStatusForFlags: (SCNetworkReachabilityFlags) flags {
	PrintReachabilityFlags(flags, "networkStatusForFlags");
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
		// if target host is not reachable
		return NRUReachabilityStatusNotReachable;

	NRUReachabilityStatusNetworkStatus retVal = NRUReachabilityStatusNotReachable;
	
	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
		// if target host is reachable and no connection is required
		//  then we'll assume (for now) that your on Wi-Fi
		retVal = NRUReachabilityStatusReachableViaWiFi;
	
	
	if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
		(flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
			// ... and the connection is on-demand (or on-traffic) if the
			//     calling application is using the CFSocketStream or higher APIs

			if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
				// ... and no [user] intervention is needed
				retVal = NRUReachabilityStatusReachableViaWiFi;
		}
	
	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
		// ... but WWAN connections are OK if the calling application
		//     is using the CFNetwork (CFSocketStream?) APIs.
		retVal = NRUReachabilityStatusReachableViaWWAN;
	return retVal;
}

- (BOOL) connectionRequired;
{
	NSAssert(self.reachabilityRef != NULL, @"connectionRequired called with NULL reachabilityRef");
	SCNetworkReachabilityFlags flags;
	if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
		return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
	return NO;
}

- (NRUReachabilityStatusNetworkStatus) currentReachabilityStatus
{
	NSAssert(self.reachabilityRef != NULL, @"currentNetworkStatus called with NULL reachabilityRef");
	NRUReachabilityStatusNetworkStatus retVal = NRUReachabilityStatusNotReachable;
	SCNetworkReachabilityFlags flags;
	if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
		if(self.localWiFiRef)
			retVal = [self localWiFiStatusForFlags: flags];
		else
			retVal = [self networkStatusForFlags: flags];
	}
	_lastReachabilityStatus = retVal;
	return retVal;
}

- (BOOL)shouldInvokeNotificationOnMain {
	return _flags._invokeNotificationBlockOnMainRunLoop;
}

- (void)setInvokeNotificationBlockOnMain:(BOOL)invokeNotificationBlockOnMain {
	_flags._invokeNotificationBlockOnMainRunLoop = invokeNotificationBlockOnMain;
}

@end
