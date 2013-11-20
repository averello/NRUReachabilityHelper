/*!
 *  @file NRUReachabilityHelper.h
 *  @brief Network Reachability Utility
 *	@details A utility class for testing network statuses.
 *
 *  Created by @author George Boumis
 *  @date 20/11/13.
 *	@version 1.0
 *  @copyright Copyright (c) 2013 George Boumis <developer.george.boumis@gmail.com>. All rights reserved.
 
 *	@defgroup nru Network Reachability Utility
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

/*!
 *	@public
 *	@enum NRUReachabilityStatusNetworkStatus
 *	@related nru
 *	@brief The enumeration indicating the different netowrk statuses.
 */
typedef NS_ENUM(NSInteger, NRUReachabilityStatusNetworkStatus) {
	ReachabilityStatusNotReachable = 0, /*!< This status indicates that the network is not reachable. */
	ReachabilityStatusReachableViaWiFi, /*!< This status indicates that the network is reachable through WiFi. */
	ReachabilityStatusReachableViaWWAN	/*!< This status indicates that the network is reachable through WWAN interfaces like 3G. */
};

/*!
 *	@brief The notification for network changes.
 *	@details The notifications object is the @ref NRUReachabilityHelper object that posted the notification.
 */
FOUNDATION_EXTERN NSString *const NRUNetworkReachabilityChangedNotification;

/*!
 *	@public
 *	@class NRUReachabilityHelper
 *	@related nru
 *	@brief The network's reachability helper.
 *
 *	@details Instanciate a helper object with the class constructors. Use it either arbitrary with @ref currentReachabilityStatus or with a Notification by registering with @ref startNotifier.
 */
NS_CLASS_AVAILABLE(10_7, 5_0) @interface NRUReachabilityHelper: NSObject
/*!
 *	@property currentReachabilityStatus
 *	@brief Used to consult the current network reachability status.
 *	@returns the current network reachability status.
 */
@property (nonatomic, readonly) NRUReachabilityStatusNetworkStatus currentReachabilityStatus;

/*!
 *	@property lastReachabilityStatus
 *	@brief Used to consult the last network reachability status.
 *	@returns the last network reachability status.
 */
@property (nonatomic, readonly) NRUReachabilityStatusNetworkStatus lastReachabilityStatus;


/*!
 *	@public
 *	@brief Use to check the reachability of a particular host name.
 *	@returns a network reachability helper that checks the availability of a particular host name.
 */
+ (NRUReachabilityHelper*)reachabilityWithHostName:(NSString *)hostName;

/*!
 *	@public
 *	@brief Use to check the reachability of a particular IP address.
 *	@returns a network reachability helper that checks the availability of a particular IP address.
 */
+ (NRUReachabilityHelper*)reachabilityWithAddress:(const struct sockaddr_in *)hostAddress;

/*!
 *	@public
 *	@brief Checks whether the default route is available.
	@details Should be used by applications that do not connect to a particular host
 *	@returns a network reachability helper that checks if the default route is available.
 */
+ (NRUReachabilityHelper*) reachabilityForInternetConnection;

/*!
 *	@public
 *	@brief Checks whether a local wifi connection is available.
 *	@returns a network reachability helper that checks if the device is connected to a WiFi.
 */
+ (NRUReachabilityHelper*) reachabilityForLocalWiFi;

/*!
 *	@public
 *	@brief Start listening for reachability notifications on the current run loop
	@details Registers the network reachability helper to the current loop. If more subsequent calls are made to this method without calling @ref stopNotifier in between then all but the first one will return `NO`.
 *	@returns `YES` if the registration completed successfully, `NO` otherwise.
 */
- (BOOL) startNotifier;

/*!
 *	@public
 *	@brief Stop listening for reachability notifications.
 */
- (void) stopNotifier;

/*!
 *	@public
 *	@brief Indicates whether or not a connection is required.
	@details WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
	@returns `YES` if a connection is required and `NO` otherwise.
 */
- (BOOL) connectionRequired;

@end


