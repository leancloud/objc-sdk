//
//  AVIMCommandFormatter.h
//  AVOSCloudIM
//
//  Created by CHEN YI LONG on 15/11/17.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

@import Foundation;
#import "AVIMCommandCommon.h"
#import "AVIMSignature.h"

FOUNDATION_EXPORT const NSInteger LCIMErrorCodeSessionTokenExpired;

@interface AVIMCommandFormatter : NSObject

/*!
 获取消息类型的字符串表示
 @param commandType - 消息类型（枚举类型）
 @return 消息类型的字符串表示
 */
+ (NSString *)commandType:(AVIMCommandType)commandType;

/*!
 字典转 protobuf 对象
 @param dictionary - 字典
 @return protobuf 对象
 */
+ (AVIMJsonObjectMessage *)JSONObjectWithDictionary:(NSDictionary *)dictionary;

/*!
 protobuf 对象转字典
 @param JSONObject - protobuf 对象
 @return 字典对象
 */
+ (NSData *)dataWithJSONObject:(AVIMJsonObjectMessage *)JSONObject;

@end
