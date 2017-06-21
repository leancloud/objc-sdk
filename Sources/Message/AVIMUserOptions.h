//
//  AVIMUserOptions.h
//  AVOS
//
//  Created by Tang Tianyong on 8/18/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVIMAvailability.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * 开启未读通知，关闭离线消息推送。
 */
FOUNDATION_EXPORT NSString *const AVIMUserOptionUseUnread AVIM_DEPRECATED("Deprecated in v5.1.0. Use `+[AVIMClient setUnreadNotificationEnabled:]` instead.");

/*
 * 自定义消息传输协议。如果没有特殊目的，不应该使用这个选项。
 */
FOUNDATION_EXPORT NSString *const AVIMUserOptionCustomProtocols AVIM_DEPRECATED("Deprecated in v5.1.0. Do not use it any more.");

NS_ASSUME_NONNULL_END
