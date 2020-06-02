//
//  AVIMGeneralObject.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/15/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMDynamicObject.h"

@interface AVIMGeneralObject : AVIMDynamicObject

@property (nonatomic) double width;
@property (nonatomic) double height;
@property (nonatomic) double size;
@property (nonatomic) double duration;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *format;
@property (nonatomic) NSString *url;
@property (nonatomic) NSString *objId;
@property (nonatomic) double longitude;
@property (nonatomic) double latitude;
@property (nonatomic) AVIMGeneralObject *metaData;
@property (nonatomic) AVIMGeneralObject *location;

@end
