//
//  Prefix header
//
//  The contents of this file are implicitly included at the beginning of every source file.
//

#import <Availability.h>

#ifndef __IPHONE_5_0
#warning "This project uses features only available in iOS SDK 5.0 and later."
#endif

#ifdef __OBJC__
    #import <UIKit/UIKit.h>
    #import <Foundation/Foundation.h>
#endif

#if __DARWIN_BYTE_ORDER == __DARWIN_BIG_ENDIAN
#warning "DARWIN_BIG_ENDIAN"
#else
#warning "DARWIN_LITTLE_ENDIAN"
#endif

#define NTP_Logging(fmt, ...)
#define LogInProduction(fmt, ...) \
NSLog((@"%@|" fmt), [NSString stringWithFormat: @"%24s", \
[[[self class] description] UTF8String]], ##__VA_ARGS__)

#ifdef IOS_NTP_LOGGING
#warning "IOS_NTP_LOGGING enabled"
#undef NTP_Logging
#define NTP_Logging(fmt, ...) \
NSLog((@"%@|" fmt), [NSString stringWithFormat: @"%24s", \
[[[self class] description] UTF8String]], ##__VA_ARGS__)
#endif

#define DEFINE_SHARED_INSTANCE_USING_BLOCK(block) \
static dispatch_once_t pred = 0; \
__strong static id _sharedObject = nil; \
dispatch_once(&pred, ^{ \
_sharedObject = block(); \
}); \
return _sharedObject; \