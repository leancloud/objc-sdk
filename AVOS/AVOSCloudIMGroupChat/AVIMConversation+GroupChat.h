//
//  AVIMConversation+GroupChatExtension.h
//  AVOSCloudIMExtension
//
//  Created by Tang Tianyong on 19/07/2017.
//  Copyright © 2017 LeanCloud. All rights reserved.
//

#import <AVOSCloudIM/AVOSCloudIM.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVIMConversation (GroupChat)

@property (nonatomic, strong, readonly) NSMutableDictionary *lastReadTimestamps;

@end

@protocol AVIMConversationGroupChatDelegate

- (void)conversation:(AVIMConversation *)conversation lastReadTimestampsDidUpdateForClientIds:(NSArray *)clientIds;

@end

NS_ASSUME_NONNULL_END
