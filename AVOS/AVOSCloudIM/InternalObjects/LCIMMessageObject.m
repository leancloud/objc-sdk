//
//  LCIMMessageObject.m
//  AVOS
//
//  Created by Qihe Bian on 1/28/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMMessageObject.h"

@implementation LCIMMessageObject

LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (ioType,                setIoType,              LCIMMessageIOType)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (status,                setStatus,              LCIMMessageStatus)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (messageId,             setMessageId)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (clientId,              setClientId)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (conversationId,        setConversationId)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (content,               setContent)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (sendTimestamp,         setSendTimestamp,       int64_t)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (deliveredTimestamp,    setDeliveredTimestamp,  int64_t)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (readTimestamp,         setReadTimestamp,       int64_t)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (updatedAt,             setUpdatedAt)

@end
