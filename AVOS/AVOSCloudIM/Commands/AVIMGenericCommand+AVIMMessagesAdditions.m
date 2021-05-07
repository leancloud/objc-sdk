//
//  AVIMGenericCommand+AVIMMessagesAdditions.m
//  LeanCloud
//
//  Created by 陈宜龙 on 15/11/18.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import <objc/runtime.h>
#import "AVIMGenericCommand+AVIMMessagesAdditions.h"
#import "LCIMCommon.h"
#import "LCIMErrorUtil.h"
#import "LCIMConversationOutCommand.h"
#import "LCIMMessage.h"
#import "LCErrorUtils.h"

NSString *const kAVIMConversationOperationQuery = @"query";

@implementation AVIMGenericCommand (AVIMMessagesAdditions)

- (LCIMCommandResultBlock)callback {
    return objc_getAssociatedObject(self, @selector(callback));
}

- (void)setCallback:(LCIMCommandResultBlock)callback {
    objc_setAssociatedObject(self, @selector(callback), callback, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (LCIMConversationOutCommand *)avim_conversationForCache {
    LCIMConversationOutCommand *command = [[LCIMConversationOutCommand alloc] init];
    [command setObject:self.peerId forKey:@"peerId"];
    [command setObject:kAVIMConversationOperationQuery forKey:@"op"];

    NSData *data = [self.convMessage.where.data_p dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];
    [command setObject:[NSMutableDictionary dictionaryWithDictionary:json] forKey:@"where"];
    [command setObject:self.convMessage.sort forKey:@"sort"];
    [command setObject:@(self.convMessage.flag) forKey:@"option"];
    
    if (self.convMessage.hasSkip) {
        [command setObject:@(self.convMessage.skip) forKey:@"skip"];
    }
    [command setObject:@(self.convMessage.limit) forKey:@"limit"];

    //there is no need to add signature for LCIMConversationOutCommand because we won't cache it ,  please go to `- (AVIMGenericCommand *)queryCommand` for more detail
    return command;
}

@end
