//
//  LCUtils.h
//  paas
//
//  Created by Zhu Zeng on 2/27/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LCObject;
@class LCUser;
@class LCFile;
@class LCCloudQueryResult;

NS_ASSUME_NONNULL_BEGIN

typedef void (^LCBooleanResultBlock)(BOOL succeeded,  NSError * _Nullable error);
typedef void (^LCIntegerResultBlock)(NSInteger number, NSError * _Nullable error);
typedef void (^LCStringResultBlock)(NSString * _Nullable string, NSError * _Nullable error);
typedef void (^LCDataResultBlock)(NSData * _Nullable data, NSError * _Nullable error);
typedef void (^LCArrayResultBlock)(NSArray * _Nullable objects, NSError * _Nullable error);
typedef void (^LCSetResultBlock)(NSSet * _Nullable set, NSError * _Nullable error);
typedef void (^LCDictionaryResultBlock)(NSDictionary * _Nullable dictionary, NSError * _Nullable error);
typedef void (^LCIdResultBlock)(id _Nullable object, NSError * _Nullable error);
typedef void (^LCProgressBlock)(NSInteger percent);
typedef void (^LCObjectResultBlock)(LCObject * _Nullable object, NSError * _Nullable error);
typedef void (^LCUserResultBlock)(LCUser * _Nullable user, NSError * _Nullable error);
typedef void (^LCFileResultBlock)(LCFile * _Nullable file, NSError * _Nullable error);
typedef void (^LCCloudQueryCallback)(LCCloudQueryResult * _Nullable result, NSError * _Nullable error);

@interface LCUtils : NSObject

// MARK: JSON String

+ (NSString * _Nullable)jsonStringFromDictionary:(NSDictionary *)dictionary;
+ (NSString * _Nullable)jsonStringFromArray:(NSArray *)array;
+ (NSString * _Nullable)jsonStringFromJSONObject:(id)JSONObject;

// MARK: Call Block

+ (void)callBooleanResultBlock:(LCBooleanResultBlock)block error:(NSError * _Nullable)error;
+ (void)callIntegerResultBlock:(LCIntegerResultBlock)block number:(NSInteger)number error:(NSError * _Nullable)error;
+ (void)callStringResultBlock:(LCStringResultBlock)block string:(NSString * _Nullable)string error:(NSError * _Nullable)error;
+ (void)callDataResultBlock:(LCDataResultBlock)block data:(NSData * _Nullable)data error:(NSError * _Nullable)error;
+ (void)callArrayResultBlock:(LCArrayResultBlock)block array:(NSArray * _Nullable)array error:(NSError * _Nullable)error;
+ (void)callSetResultBlock:(LCSetResultBlock)block set:(NSSet * _Nullable)set error:(NSError * _Nullable)error;
+ (void)callDictionaryResultBlock:(LCDictionaryResultBlock)block dictionary:(NSDictionary * _Nullable)dictionary error:(NSError * _Nullable)error;
+ (void)callIdResultBlock:(LCIdResultBlock)block object:(id _Nullable)object error:(NSError * _Nullable)error;
+ (void)callProgressBlock:(LCProgressBlock)block percent:(NSInteger)percent;
+ (void)callObjectResultBlock:(LCObjectResultBlock)block object:(LCObject * _Nullable)object error:(NSError * _Nullable)error;
+ (void)callUserResultBlock:(LCUserResultBlock)block user:(LCUser * _Nullable)user error:(NSError * _Nullable)error;
+ (void)callFileResultBlock:(LCFileResultBlock)block file:(LCFile * _Nullable)file error:(NSError * _Nullable)error;
+ (void)callCloudQueryCallback:(LCCloudQueryCallback)block result:(LCCloudQueryResult * _Nullable)result error:(NSError * _Nullable)error;

@end

@interface NSObject (LeanCloudObjcSDK)

+ (BOOL)_lc_isTypeOf:(id)instance;
+ (instancetype _Nullable)_lc_decoding:(NSDictionary *)dictionary key:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
