//
//  LCFile_Internal.h
//  LeanCloud
//
//  Created by Zhu Zeng on 3/20/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import "LCFile.h"

static NSString * const kLCFile_mime_type = @"mime_type";
static NSString * const kLCFile_key = @"key";
static NSString * const kLCFile_name = @"name";
static NSString * const kLCFile_url = @"url";
static NSString * const kLCFile_provider = @"provider";
static NSString * const kLCFile_metaData = @"metaData";
static NSString * const kLCFile_size = @"size";
static NSString * const kLCFile_bucket = @"bucket";
/// @note Totally, has three Keys to identify 'objectId' in history, @"objectId" is the latest Key and @"objId" used in IM messages.
static NSString * const kLCFile_objectId = @"objectId";
static NSString * const kLCFile_objId = @"objId";
static NSString * const kLCFile_id = @"id";

@interface LCFile ()

+ (NSString *)className;

- (instancetype)initWithRawJSONData:(NSMutableDictionary *)rawJSONData;

- (NSDictionary *)rawJSONDataCopy;

- (NSMutableDictionary *)rawJSONDataMutableCopy;

@end

@interface LCFileTokens : NSObject

@property (nonatomic, strong, readonly) NSDictionary *rawDic;

@property (nonatomic, strong, readonly) NSString *provider;
@property (nonatomic, strong, readonly) NSString *objectId;
@property (nonatomic, strong, readonly) NSString *token;
@property (nonatomic, strong, readonly) NSString *bucket;
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, strong, readonly) NSString *uploadUrl;

- (instancetype)initWithDic:(NSDictionary *)dic;

@end
