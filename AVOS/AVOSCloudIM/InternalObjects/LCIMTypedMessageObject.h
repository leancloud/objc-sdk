//
//  LCIMTypedMessageObject.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/8/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCIMDynamicObject.h"

@interface LCIMTypedMessageObject : LCIMDynamicObject

@property (nonatomic) int32_t _lctype;
@property (nonatomic) NSString *_lctext;
@property (nonatomic) NSDictionary *_lcfile;
@property (nonatomic) NSDictionary *_lcloc;
@property (nonatomic) NSDictionary *_lcattrs;

- (BOOL)isValidTypedMessageObject;

@end
