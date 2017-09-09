//
//  BRAudioSyncConstants.m
//  BRAudioSync
//
//  Created by Bektur Ryskeldiev on 4/3/14.
//  Copyright (c) 2014 Bektur Ryskeldiev. All rights reserved.
//

#import "BRAudioSyncConstants.h"

NSString * const kSessionType = @"bras-session";
NSString * const kServiceType = @"bras-service";

NSString * const kMessageNetworkTimeKey = @"MessageNetworkTimeKey";
NSString * const kMessageDeviceTimeKey  = @"MessageDeviceTimeKey";
NSString * const kMessageCommandKey     = @"MessageCommandKey";

NSString * const kMessageCommandStart   = @"MessageCommandStart";
NSString * const kMessageCommandStop    = @"MessageCommandStop";
NSString * const kMessageCommandTime    = @"MessageCommandTime";

NSString * const kNotificationMessageReceived = @"NotificationMessageReceived";
NSString * const kNotificationMessageDictKey  = @"NotificationMessageDictKey";
NSString * const kNotificationMessageTimeKey  = @"NotificationMessageTimeKey"; // time when the message was received
NSString * const kNotificationMessageNTPTimeKey = @"NotificationMessageNTPTimeKey"; // NTP time when the message was received

@implementation BRAudioSyncConstants

@end
