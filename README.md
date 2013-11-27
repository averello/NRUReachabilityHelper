NRUReachabilityHelper
=====================

A utility class for testing network rechability statuses on iOS.

Documentation
-------------
This project uses [doxygen](http://www.stack.nl/~dimitri/doxygen/index.html) (http://www.stack.nl/~dimitri/doxygen/index.html) for the code documentation.
Just point doxygen to the doc/Doxyfile and the html documentation will be generated.

Command line exemple :
```bash
cd doc
doxygen Doxyfile
```
Now open the file doc/index.html


Usage
-----
The notification driven approach:
```m
NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
[notificationCenter addObserverForName:NRUNetworkReachabilityChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
	NRUReachabilityHelper *helper = note.object;
	NRUReachabilityStatusNetworkStatus status = helper.currentReachabilityStatus;
	switch (status) {
		case NRUReachabilityStatusNotReachable:
			// No internet connection
			break;
		case NRUReachabilityStatusReachableViaWiFi:
		case NRUReachabilityStatusReachableViaWWAN:
			// Internet
			break;
		default:
			break;
	}
}];
NRUReachabilityHelper *helper = [NRUReachabilityHelper reachabilityForInternetConnection];
[helper startNotifier];
//...
[helper stopNotifier];
[notificationCenter removeObserver:self name:NRUNetworkReachabilityChangedNotification object:nil];
```
and the block driven approach:
```m
NRUReachabilityHelper *helper = [NRUReachabilityHelper reachabilityForInternetConnection];
helper.notificationBlock = ^(NRUReachabilityHelper *reachabilityHelper) {
	NRUReachabilityStatusNetworkStatus status = reachabilityHelper.currentReachabilityStatus;
	switch (status) {
		case NRUReachabilityStatusNotReachable:
			// No internet connection
			break;
		case NRUReachabilityStatusReachableViaWiFi:
		case NRUReachabilityStatusReachableViaWWAN:
			// Internet
			break;
		default:
			break;
	}
};
[helper startNotifier];
//...
[helper stopNotifier];
```
