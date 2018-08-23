//
//  AVIMClientInternalConversationManager.h
//  AVOS
//
//  Created by zapcannon87 on 2018/7/18.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVIMClientInternalConversationManager : NSObject

/**
 Limit of client internal batch query for conversations.

 @param limit Default is 20.
 */
+ (void)setBatchQueryLimit:(NSUInteger)limit;

@end

NS_ASSUME_NONNULL_END
