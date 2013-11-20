
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
	
    GPLog(@"Reachability Flag Status: %c%c %c%c%c%c%c%c%c %s\n",
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


@interface NRUReachabilityHelper ()
@property (nonatomic, readwrite, assign) BOOL localWiFiRef, alreadyStarted;
@property (nonatomic, readwrite, assign) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, readwrite, assign) NRUReachabilityStatusNetworkStatus lastReachabilityStatus;
@property (nonatomic, assign) CFRunLoopRef runLoop;
@end


@implementation NRUReachabilityHelper

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
	#pragma unused (target, flags)
	NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
	NSCAssert([(__bridge NSObject*) info isKindOfClass: [NRUReachabilityHelper class]], @"info was wrong class in ReachabilityCallback");

	//We're on the main RunLoop, so an NSAutoreleasePool is not necessary, but is added defensively
	// in case someon uses the Reachablity object in a different thread.
	@autoreleasepool {
		NRUReachabilityHelper* noteObject = (__bridge NRUReachabilityHelper*) info;
		// Post a notification to notify the client that the network reachability changed.
		[[NSNotificationCenter defaultCenter] postNotificationName: NRUNetworkReachabilityChangedNotification object: noteObject];
	}
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
	if ( _alreadyStarted )
		return retVal;
	
	SCNetworkReachabilityContext context;
	context.version = 0;
	context.info = (__bridge void *)(self);
	context.retain = NULL;
	context.release = NULL;
	context.copyDescription = NULL;
	_runLoop = CFRunLoopGetCurrent();
	if(SCNetworkReachabilitySetCallback(self.reachabilityRef, ReachabilityCallback, &context))
		if(SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityRef, _runLoop, kCFRunLoopDefaultMode))
			retVal = YES, _alreadyStarted = YES;
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

	NRUReachabilityStatusNetworkStatus retVal = ReachabilityStatusNotReachable;
	if((flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsDirect))
		retVal = ReachabilityStatusReachableViaWiFi;	

	return retVal;
}

- (NRUReachabilityStatusNetworkStatus) networkStatusForFlags: (SCNetworkReachabilityFlags) flags {
	PrintReachabilityFlags(flags, "networkStatusForFlags");
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
		// if target host is not reachable
		return ReachabilityStatusNotReachable;

	NRUReachabilityStatusNetworkStatus retVal = ReachabilityStatusNotReachable;
	
	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
		// if target host is reachable and no connection is required
		//  then we'll assume (for now) that your on Wi-Fi
		retVal = ReachabilityStatusReachableViaWiFi;
	
	
	if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
		(flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
			// ... and the connection is on-demand (or on-traffic) if the
			//     calling application is using the CFSocketStream or higher APIs

			if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
				// ... and no [user] intervention is needed
				retVal = ReachabilityStatusReachableViaWiFi;
		}
	
	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
		// ... but WWAN connections are OK if the calling application
		//     is using the CFNetwork (CFSocketStream?) APIs.
		retVal = ReachabilityStatusReachableViaWWAN;
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
	NRUReachabilityStatusNetworkStatus retVal = ReachabilityStatusNotReachable;
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
@end
