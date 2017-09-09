//
//  BRAudioSyncConstants.h
//  BRAudioSync
//
//  Created by Bektur Ryskeldiev on 4/3/14.
//  Copyright (c) 2014 Bektur Ryskeldiev. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kSessionType;
extern NSString * const kServiceType;

extern NSString * const kMessageNetworkTimeKey;
extern NSString * const kMessageDeviceTimeKey;
extern NSString * const kMessageCommandKey;

extern NSString * const kMessageCommandStart;
extern NSString * const kMessageCommandStop;
extern NSString * const kMessageCommandTime;

extern NSString * const kNotificationMessageReceived;
extern NSString * const kNotificationMessageDictKey;
extern NSString * const kNotificationMessageTimeKey;
extern NSString * const kNotificationMessageNTPTimeKey;

@interface BRAudioSyncConstants : NSObject

@end
