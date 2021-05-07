//
//  LCIMMessageOption.h
//  LeanCloud
//
//  Created by Tang Tianyong on 9/13/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LCIMMessagePriority) {
    LCIMMessagePriorityHigh    = 1,
    LCIMMessagePriorityNormal  = 2,
    LCIMMessagePriorityLow     = 3,
};

NS_ASSUME_NONNULL_BEGIN

@interface LCIMMessageOption : NSObject

@property (nonatomic, assign)           BOOL                 receipt;
@property (nonatomic, assign)           BOOL                 transient;
@property (nonatomic, assign)           BOOL                 will;
@property (nonatomic, assign)           LCIMMessagePriority  priority;
@property (nonatomic, strong, nullable) NSDictionary        *pushData;

@end

NS_ASSUME_NONNULL_END
