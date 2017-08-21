//
//  AVIMGeneralObject.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/15/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMDynamicObject.h"

@interface AVIMGeneralObject : AVIMDynamicObject
@property(nonatomic, assign) uint width;
@property(nonatomic, assign) uint height;
@property(nonatomic, assign) uint64_t size;
@property(nonatomic, assign) float duration;
@property(nonatomic,   copy) NSString *name;
@property(nonatomic,   copy) NSString *format;
@property(nonatomic,   copy) NSString *url;
@property(nonatomic,   copy) NSString *objId;
@property(nonatomic, assign) float longitude;
@property(nonatomic, assign) float latitude;
@property(nonatomic, strong) AVIMGeneralObject *metaData;
@property(nonatomic, strong) AVIMGeneralObject *location;
@end
