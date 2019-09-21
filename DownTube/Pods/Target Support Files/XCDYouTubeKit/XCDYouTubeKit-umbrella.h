#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "XCDYouTubeClient.h"
#import "XCDYouTubeError.h"
#import "XCDYouTubeKit.h"
#import "XCDYouTubeLogger.h"
#import "XCDYouTubeOperation.h"
#import "XCDYouTubeVideo.h"
#import "XCDYouTubeVideoOperation.h"
#import "XCDYouTubeVideoPlayerViewController.h"

FOUNDATION_EXPORT double XCDYouTubeKitVersionNumber;
FOUNDATION_EXPORT const unsigned char XCDYouTubeKitVersionString[];

