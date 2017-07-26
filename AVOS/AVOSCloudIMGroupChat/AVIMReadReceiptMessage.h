//
//  AVIMReadReceiptMessage.h
//  AVOS
//
//  Created by Tang Tianyong on 20/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <AVOSCloudIM/AVOSCloudIM.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT const AVIMMessageMediaType kAVIMMessageMediaTypeReadReceipt;

@interface AVIMReadReceiptMessage : AVIMTypedMessage <AVIMTypedMessageSubclassing>

@property (nonatomic, assign) int64_t timestamp;

@end

NS_ASSUME_NONNULL_END
