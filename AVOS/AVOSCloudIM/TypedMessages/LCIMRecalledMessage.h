//
//  LCIMRecalledMessage.h
//  AVOS
//
//  Created by Tang Tianyong on 26/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "LCIMTypedMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 This class is a type of messages that have been recalled by its sender.
 */
@interface LCIMRecalledMessage : LCIMTypedMessage <LCIMTypedMessageSubclassing>

@end

NS_ASSUME_NONNULL_END
