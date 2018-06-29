//
//  AVIMCommon.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#if __has_include(<AVOSCloud/AVConstants.h>)
#import <AVOSCloud/AVConstants.h>
#else
#import "AVConstants.h"
#endif

@class AVIMConversation;
@class AVIMChatRoom;
@class AVIMTemporaryConversation;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AVIMErrorCode) {
    // 90XX
    AVIMErrorCodeCommandTimeout = 9000,
    AVIMErrorCodeConnectionLost = 9001,
    AVIMErrorCodeClientNotOpen = 9002,
    AVIMErrorCodeInvalidCommand = 9003,
    AVIMErrorCodeCommandDataLengthTooLong = 9008,
    // 91XX
    AVIMErrorCodeUpdatingMessageNotAllowed = 9120,
    AVIMErrorCodeUpdatingMessageNotSent = 9121,
    AVIMErrorCodeOwnerPromotionNotAllowed = 9130,
};

/* AVOSCloud IM code key */
FOUNDATION_EXPORT NSString *const kAVIMCodeKey;
/* AVOSCloud IM app code key */
FOUNDATION_EXPORT NSString *const kAVIMAppCodeKey;
/* AVOSCloud IM reason key */
FOUNDATION_EXPORT NSString *const kAVIMReasonKey;
/* AVOSCloud IM detail key */
FOUNDATION_EXPORT NSString *const kAVIMDetailKey;

typedef void(^AVIMBooleanResultBlock)(BOOL, NSError * _Nullable);

typedef void(^AVIMIntegerResultBlock)(NSInteger, NSError * _Nullable);

typedef void(^AVIMArrayResultBlock)(NSArray * _Nullable, NSError * _Nullable);

typedef void(^AVIMConversationResultBlock)(AVIMConversation * _Nullable, NSError * _Nullable);

typedef void(^AVIMChatRoomResultBlock)(AVIMChatRoom * _Nullable, NSError * _Nullable);

typedef void(^AVIMTemporaryConversationResultBlock)(AVIMTemporaryConversation * _Nullable, NSError * _Nullable);

typedef void(^AVIMProgressBlock)(NSInteger);

NS_ASSUME_NONNULL_END

/* Cache policy */
typedef NS_ENUM(int, AVIMCachePolicy) {
    /* Query from server and do not save result to local cache. */
    kAVIMCachePolicyIgnoreCache = 0,

    /* Only query from local cache. */
    kAVIMCachePolicyCacheOnly,

    /* Only query from server, and save result to local cache. */
    kAVIMCachePolicyNetworkOnly,

    /* Firstly query from local cache, if fails, query from server. */
    kAVIMCachePolicyCacheElseNetwork,

    /* Firstly query from server, if fails, query local cache. */
    kAVIMCachePolicyNetworkElseCache,

    /* Firstly query from local cache, then query from server. The callback will be called twice. */
    kAVIMCachePolicyCacheThenNetwork,
};
