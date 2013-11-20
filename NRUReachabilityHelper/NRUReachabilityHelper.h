/*!
 *  @file NRUReachabilityHelper.h
 *  @brief Network Reachability Utility
 *	@details A utility class for network
 *
 *  Created by @author George Boumis
 *  @date 20/11/13.
 *	@version 1.0
 *  @copyright Copyright (c) 2013 George Boumis <developer.george.boumis@gmail.com>. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

typedef NS_ENUM(NSInteger, ReachabilityStatusNetworkStatus) {
	ReachabilityStatusNotReachable = 0,
	ReachabilityStatusReachableViaWiFi,
	ReachabilityStatusReachableViaWWAN
};

FOUNDATION_EXTERN NSString *const NRUNetworkReachabilityChangedNotification;

NS_CLASS_AVAILABLE(10_7, 5_0) @interface NRUReachabilityHelper: NSObject

@property (nonatomic, readonly) ReachabilityStatusNetworkStatus currentReachabilityStatus;
@property (nonatomic, readonly) ReachabilityStatusNetworkStatus lastReachabilityStatus;

//reachabilityWithHostName- Use to check the reachability of a particular host name. 
+ (NRUReachabilityHelper*) reachabilityWithHostName: (NSString*) hostName;

//reachabilityWithAddress- Use to check the reachability of a particular IP address. 
+ (NRUReachabilityHelper*) reachabilityWithAddress: (const struct sockaddr_in*) hostAddress;

//reachabilityForInternetConnection- checks whether the default route is available.  
//  Should be used by applications that do not connect to a particular host
+ (NRUReachabilityHelper*) reachabilityForInternetConnection;

//reachabilityForLocalWiFi- checks whether a local wifi connection is available.
+ (NRUReachabilityHelper*) reachabilityForLocalWiFi;

//Start listening for reachability notifications on the current run loop
- (BOOL) startNotifier;
- (void) stopNotifier;

- (ReachabilityStatusNetworkStatus) currentReachabilityStatus;
//WWAN may be available, but not active until a connection has been established.
//WiFi may require a connection for VPN on Demand.
- (BOOL) connectionRequired;
@end


