//
//  AVIMCommon.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class AVIMConversation;

NS_ASSUME_NONNULL_BEGIN

extern NSString *AVOSCloudIMErrorDomain;

typedef NS_ENUM(NSInteger, AVIMErrorCode) {
    kAVIMErrorTimeout = 9000,
    kAVIMErrorConnectionLost,
    kAVIMErrorClientNotOpen,
    kAVIMErrorInvalidCommand,
    kAVIMErrorInvalidArguments,
    kAVIMErrorMessageNotFound,
    kAVIMErrorConversationNotFound,
    kAVIMErrorInvalidData,
    kAVIMErrorMessageTooLong,
};

/* AVOSCloud IM code key */
FOUNDATION_EXPORT NSString *const kAVIMCodeKey;
/* AVOSCloud IM app code key */
FOUNDATION_EXPORT NSString *const kAVIMAppCodeKey;
/* AVOSCloud IM reason key */
FOUNDATION_EXPORT NSString *const kAVIMReasonKey;
/* AVOSCloud IM detail key */
FOUNDATION_EXPORT NSString *const kAVIMDetailKey;

typedef void (^AVIMBooleanResultBlock)(BOOL succeeded, NSError * _Nullable error);
typedef void (^AVIMIntegerResultBlock)(NSInteger number, NSError * _Nullable error);
typedef void (^AVIMArrayResultBlock)(NSArray * _Nullable objects, NSError * _Nullable error);
typedef void (^AVIMConversationResultBlock)(AVIMConversation * _Nullable conversation, NSError * _Nullable error);
typedef void (^AVIMProgressBlock)(NSInteger percentDone);

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
