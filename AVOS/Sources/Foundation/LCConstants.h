// LCConstants.h
// Copyright 2013 LeanCloud, Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "LCAvailability.h"

@class LCObject;
@class LCUser;
@class LCFile;

#if LC_IOS_ONLY
#import <UIKit/UIKit.h>
#elif LC_OSX_ONLY
#import <Cocoa/Cocoa.h>
@compatibility_alias UIImage NSImage;
@compatibility_alias UIColor NSColor;
@compatibility_alias UIView NSView;
#endif

/// Cache policies
typedef NS_ENUM(int, LCCachePolicy) {
    /// Query from server and do not save result to the local cache.
    kLCCachePolicyIgnoreCache = 0,
    
    /// Only query from the local cache.
    kLCCachePolicyCacheOnly,
    
    /// Only query from server, and save result to the local cache.
    kLCCachePolicyNetworkOnly,
    
    /// Firstly query from the local cache, if fails, query from server.
    kLCCachePolicyCacheElseNetwork,
    
    /// Firstly query from server, if fails, query the local cache.
    kLCCachePolicyNetworkElseCache,
    
    /// Firstly query from the local cache, return result. Then query from server, return result. The callback will be called twice.
    kLCCachePolicyCacheThenNetwork,
} ;

typedef void (^LCBooleanResultBlock)(BOOL succeeded,  NSError * _Nullable error);
typedef void (^LCIntegerResultBlock)(NSInteger number, NSError * _Nullable error);
typedef void (^LCArrayResultBlock)(NSArray * _Nullable objects, NSError * _Nullable error);
typedef void (^LCObjectResultBlock)(LCObject * _Nullable object, NSError * _Nullable error);
typedef void (^LCSetResultBlock)(NSSet * _Nullable set, NSError * _Nullable error);
typedef void (^LCUserResultBlock)(LCUser * _Nullable user, NSError * _Nullable error);
typedef void (^LCDataResultBlock)(NSData * _Nullable data, NSError * _Nullable error);
#if LC_TARGET_OS_OSX
typedef void (^LCImageResultBlock)(NSImage * _Nullable image, NSError * _Nullable error);
#else
typedef void (^LCImageResultBlock)(UIImage * _Nullable image, NSError * _Nullable error);
#endif
typedef void (^LCStringResultBlock)(NSString * _Nullable string, NSError * _Nullable error);
typedef void (^LCIdResultBlock)(id _Nullable object, NSError * _Nullable error);
typedef void (^LCProgressBlock)(NSInteger percent);
typedef void (^LCFileResultBlock)(LCFile * _Nullable file, NSError * _Nullable error);
typedef void (^LCDictionaryResultBlock)(NSDictionary * _Nullable dictionary, NSError * _Nullable error);

#define LC_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
