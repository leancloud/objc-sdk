//
//  LCIMSignature.h
//  LeanCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCIMCommon.h"

NS_ASSUME_NONNULL_BEGIN

@interface LCIMSignature : NSObject

/**
 *  Signture result signed by server master key.
 */
@property (nonatomic, copy, nullable) NSString *signature;

/**
 *  Timestamp used to construct signature.
 */
@property (nonatomic, assign) int64_t timestamp;

/**
 *  Nonce string used to construct signature
 */
@property (nonatomic, copy, nullable) NSString *nonce;

/**
 *  Error in the course of getting signature from server. Commonly network error. Please set it if any error when getting signature.
 */
@property (nonatomic, strong, nullable) NSError *error;

@end

@class LCIMClient;
@class LCIMConversation;

@protocol LCIMSignatureDataSource <NSObject>

/// Delegate function of the signature action.
/// @param client The signature action belong to.
/// @param action See `LCIMSignatureAction`.
/// @param conversation The signature action belong to.
/// @param clientIds The targets.
/// @param handler The handler for the signature.
- (void)client:(LCIMClient *)client
        action:(LCIMSignatureAction)action
  conversation:(LCIMConversation * _Nullable)conversation
     clientIds:(NSArray<NSString *> * _Nullable)clientIds
signatureHandler:(void (^)(LCIMSignature * _Nullable))handler;

@end

NS_ASSUME_NONNULL_END
