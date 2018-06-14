//
//  AVIMConversationQuery.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 2/3/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversationQuery.h"
#import "MessagesProtoOrig.pbobjc.h"
#import "AVIMCommandCommon.h"
#import "AVUtils.h"
#import "AVIMConversation.h"
#import "AVIMConversation_Internal.h"
#import "AVIMConversationQuery_Internal.h"
#import "AVIMClient_Internal.h"
#import "AVIMBlockHelper.h"
#import "AVIMErrorUtil.h"
#import "AVObjectUtils.h"
#import "LCIMConversationCache.h"
#import "AVIMMessage_Internal.h"
#import "AVErrorUtils.h"

@implementation AVIMConversationQuery

+(NSDictionary *)dictionaryFromGeoPoint:(AVGeoPoint *)point {
    return @{ @"__type": @"GeoPoint", @"latitude": @(point.latitude), @"longitude": @(point.longitude) };
}

+(AVGeoPoint *)geoPointFromDictionary:(NSDictionary *)dict {
    AVGeoPoint * point = [[AVGeoPoint alloc]init];
    point.latitude = [[dict objectForKey:@"latitude"] doubleValue];
    point.longitude = [[dict objectForKey:@"longitude"] doubleValue];
    return point;
}

+ (instancetype)orQueryWithSubqueries:(NSArray<AVIMConversationQuery *> *)queries {
    AVIMConversationQuery *result = nil;

    if (queries.count > 0) {
        AVIMClient *client = [[queries firstObject] client];
        NSMutableArray *wheres = [[NSMutableArray alloc] initWithCapacity:queries.count];

        for (AVIMConversationQuery *query in queries) {
            NSString *eachClientId = query.client.clientId;

            if (!eachClientId || ![eachClientId isEqualToString:client.clientId]) {
                AVLoggerError(AVLoggerDomainIM, @"Invalid conversation query client id: %@.", eachClientId);
                return nil;
            }

            [wheres addObject:[query where]];
        }

        result = [client conversationQuery];
        result.where[@"$or"] = wheres;
    }

    return result;
}

+ (instancetype)andQueryWithSubqueries:(NSArray<AVIMConversationQuery *> *)queries {
    AVIMConversationQuery *result = nil;

    if (queries.count > 0) {
        AVIMClient *client = [[queries firstObject] client];
        NSMutableArray *wheres = [[NSMutableArray alloc] initWithCapacity:queries.count];

        for (AVIMConversationQuery *query in queries) {
            NSString *eachClientId = query.client.clientId;

            if (!eachClientId || ![eachClientId isEqualToString:client.clientId]) {
                AVLoggerError(AVLoggerDomainIM, @"Invalid conversation query client id: %@.", eachClientId);
                return nil;
            }

            [wheres addObject:[query where]];
        }

        result = [client conversationQuery];

        if (wheres.count > 1) {
            result.where[@"$and"] = wheres;
        } else {
            [result.where addEntriesFromDictionary:[wheres firstObject]];
        }
    }

    return result;
}

- (instancetype)init {
    if ((self = [super init])) {
        _where = [[NSMutableDictionary alloc] init];
        _cachePolicy = kAVIMCachePolicyCacheElseNetwork;
        _cacheMaxAge = 1 * 60 * 60; // an hour
    }
    return self;
}

- (NSString *)whereString {
    NSDictionary *dic = [AVObjectUtils dictionaryFromDictionary:self.where];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:NULL];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void)addWhereItem:(NSDictionary *)dict forKey:(NSString *)key {
    if ([dict objectForKey:@"$eq"]) {
        if ([self.where objectForKey:@"$and"]) {
            NSMutableArray *eqArray = [self.where objectForKey:@"$and"];
            int removeIndex = -1;
            for (NSDictionary *eqDict in eqArray) {
                if ([eqDict objectForKey:key]) {
                    removeIndex = (int)[eqArray indexOfObject:eqDict];
                }
            }
            
            if (removeIndex >= 0) {
                [eqArray removeObjectAtIndex:removeIndex];
            }
            
            [eqArray addObject:@{key:[dict objectForKey:@"$eq"]}];
        } else {
            NSMutableArray *eqArray = [[NSMutableArray alloc] init];
            [eqArray addObject:@{key:[dict objectForKey:@"$eq"]}];
            [self.where setObject:eqArray forKey:@"$and"];
        }
    } else {
        if ([self.where objectForKey:key]) {
            [[self.where objectForKey:key] addEntriesFromDictionary:dict];
        } else {
            NSMutableDictionary *mutableDict = [[NSMutableDictionary alloc] initWithDictionary:dict];
            [self.where setObject:mutableDict forKey:key];
        }
    }
}

- (void)whereKeyExists:(NSString *)key
{
    NSDictionary * dict = @{@"$exists": [NSNumber numberWithBool:YES]};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKeyDoesNotExist:(NSString *)key
{
    NSDictionary * dict = @{@"$exists": [NSNumber numberWithBool:NO]};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key equalTo:(id)object
{
        [self addWhereItem:@{@"$eq":object} forKey:key];
}

- (void)whereKey:(NSString *)key sizeEqualTo:(NSUInteger)count
{
    [self addWhereItem:@{@"$size": [NSNumber numberWithUnsignedInteger:count]} forKey:key];
}


- (void)whereKey:(NSString *)key lessThan:(id)object
{
    NSDictionary * dict = @{@"$lt":object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key lessThanOrEqualTo:(id)object
{
    NSDictionary * dict = @{@"$lte":object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key greaterThan:(id)object
{
    NSDictionary * dict = @{@"$gt": object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key greaterThanOrEqualTo:(id)object
{
    NSDictionary * dict = @{@"$gte": object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key notEqualTo:(id)object
{
    NSDictionary * dict = @{@"$ne": object};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key containedIn:(NSArray *)array
{
    NSDictionary * dict = @{@"$in": array };
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key notContainedIn:(NSArray *)array
{
    NSDictionary * dict = @{@"$nin": array };
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key containsAllObjectsInArray:(NSArray *)array
{
    NSDictionary * dict = @{@"$all": array };
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key nearGeoPoint:(AVGeoPoint *)geopoint
{
    NSDictionary * dict = @{@"$nearSphere" : [[self class] dictionaryFromGeoPoint:geopoint]};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key nearGeoPoint:(AVGeoPoint *)geopoint withinMiles:(double)maxDistance
{
    NSDictionary * dict = @{@"$nearSphere" : [[self class] dictionaryFromGeoPoint:geopoint], @"$maxDistanceInMiles":@(maxDistance)};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key nearGeoPoint:(AVGeoPoint *)geopoint withinKilometers:(double)maxDistance
{
    NSDictionary * dict = @{@"$nearSphere" : [[self class] dictionaryFromGeoPoint:geopoint], @"$maxDistanceInKilometers":@(maxDistance)};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key nearGeoPoint:(AVGeoPoint *)geopoint withinRadians:(double)maxDistance
{
    NSDictionary * dict = @{@"$nearSphere" : [[self class] dictionaryFromGeoPoint:geopoint], @"$maxDistanceInRadians":@(maxDistance)};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key withinGeoBoxFromSouthwest:(AVGeoPoint *)southwest toNortheast:(AVGeoPoint *)northeast
{
    NSDictionary * dict = @{@"$within": @{@"$box" : @[[[self class] dictionaryFromGeoPoint:southwest], [[self class] dictionaryFromGeoPoint:northeast]]}};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex
{
    NSDictionary * dict = @{@"$regex": regex};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex modifiers:(NSString *)modifiers
{
    NSDictionary * dict = @{@"$regex":regex, @"$options":modifiers};
    [self addWhereItem:dict forKey:key];
}

- (void)whereKey:(NSString *)key containsString:(NSString *)substring
{
    [self whereKey:key matchesRegex:[NSString stringWithFormat:@".*%@.*",substring]];
}

- (void)whereKey:(NSString *)key hasPrefix:(NSString *)prefix
{
    [self whereKey:key matchesRegex:[NSString stringWithFormat:@"^%@.*",prefix]];
}

- (void)whereKey:(NSString *)key hasSuffix:(NSString *)suffix
{
    [self whereKey:key matchesRegex:[NSString stringWithFormat:@".*%@$",suffix]];
}

- (void)orderByAscending:(NSString *)key
{
    self.order = [NSString stringWithFormat:@"%@", key];
}

- (void)addAscendingOrder:(NSString *)key
{
    if (self.order.length <= 0)
    {
        [self orderByAscending:key];
        return;
    }
    self.order = [NSString stringWithFormat:@"%@,%@", self.order, key];
}

- (void)orderByDescending:(NSString *)key
{
    self.order = [NSString stringWithFormat:@"-%@", key];
}

- (void)addDescendingOrder:(NSString *)key
{
    if (self.order.length <= 0)
    {
        [self orderByDescending:key];
        return;
    }
    self.order = [NSString stringWithFormat:@"%@,-%@", self.order, key];
}

- (void)orderBySortDescriptor:(NSSortDescriptor *)sortDescriptor
{
    NSString *symbol = sortDescriptor.ascending ? @"" : @"-";
    self.order = [symbol stringByAppendingString:sortDescriptor.key];
}

- (void)orderBySortDescriptors:(NSArray *)sortDescriptors
{
    if (sortDescriptors.count == 0) return;
    
    self.order = @"";
    for (NSSortDescriptor *sortDescriptor in sortDescriptors) {
        NSString *symbol = sortDescriptor.ascending ? @"" : @"-";
        if (self.order.length) {
            self.order = [NSString stringWithFormat:@"%@,%@%@", self.order, symbol, sortDescriptor.key];
        } else {
            self.order=[NSString stringWithFormat:@"%@%@", symbol, sortDescriptor.key];
        }
        
    }
}

- (void)invokeInSpecifiedQueue:(void (^)(void))block
{
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

- (void)getConversationById:(NSString *)conversationId
                   callback:(void (^)(AVIMConversation * _Nullable, NSError * _Nullable))callback
{
    [self whereKey:kLCIMConv_objectId equalTo:conversationId];
    [self findConversationsWithCallback:^(NSArray<AVIMConversation *> * _Nullable conversations, NSError * _Nullable error) {
        if (error) {
            callback(nil, error);
            return;
        }
        if (conversations && conversations.count == 1) {
            callback(conversations.firstObject, nil);
        } else {
            callback(nil, LCError(kAVIMErrorConversationNotFound, @"conversation not found.", nil));
        }
    }];
}

- (void)findConversationsWithCallback:(void (^)(NSArray<AVIMConversation *> * _Nullable, NSError * _Nullable))callback
{
    AVIMClient *client = self.client;
    if (!client) {
        [self invokeInSpecifiedQueue:^{
            callback(nil, LCErrorInternal(@"client invalid."));
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        AVIMJsonObjectMessage *jsonObjectMessage = [AVIMJsonObjectMessage new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Query;
        outCommand.convMessage = convCommand;
        
        if (self.order) {
            convCommand.sort = self.order;
        }
        if (self.option) {
            convCommand.flag = self.option;
        }
        if (self.skip) {
            convCommand.skip = (int32_t)self.skip;
        }
        if (self.limit > 0) {
            convCommand.limit = (int32_t)self.limit;
        } else {
            convCommand.limit = 10;
        }
        NSString *whereString = self.whereString;
        if (whereString) {
            convCommand.where = jsonObjectMessage;
            jsonObjectMessage.data_p = whereString;
        }
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            if (self.cachePolicy == kAVIMCachePolicyNetworkElseCache) {
                [self fetchCachedResultsForOutCommand:commandWrapper.outCommand client:client callback:^(NSArray *conversations) {
                    [self invokeInSpecifiedQueue:^{
                        callback(conversations, nil);
                    }];
                }];
            } else {
                [self invokeInSpecifiedQueue:^{
                    callback(nil, commandWrapper.error);
                }];
            }
            return;
        }
        
        NSArray<AVIMConversation *> *conversations = ({
            NSMutableArray<NSMutableDictionary *> *results = ({
                NSString *jsonString = commandWrapper.inCommand.convMessage.results.data_p;
                NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                NSError *error = nil;
                NSMutableArray<NSMutableDictionary *> *results = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                if (error) {
                    [self invokeInSpecifiedQueue:^{
                        callback(nil, error);
                    }];
                    return;
                }
                results;
            });
            NSMutableArray<AVIMConversation *> *conversations = [NSMutableArray array];
            for (NSMutableDictionary *jsonDic in results) {
                if (![NSMutableDictionary lc__checkingType:jsonDic]) {
                    continue;
                }
                NSString *conversationId = [NSString lc__decodingDictionary:jsonDic key:kLCIMConv_objectId];
                if (!conversationId) {
                    continue;
                }
                AVIMConversation *conv = [client getConversationFromMemory:conversationId];
                if (conv) {
                    [conv setRawJSONData:jsonDic];
                    [conversations addObject:conv];
                } else {
                    conv = [AVIMConversation conversationWithRawJSONData:jsonDic client:client];
                    if (conv) {
                        [client cacheConversationToMemory:conv];
                        [conversations addObject:conv];
                    }
                }
            }
            conversations;
        });
        
        if (self.cachePolicy != kAVIMCachePolicyIgnoreCache) {
            [client.conversationCache cacheConversations:conversations maxAge:self.cacheMaxAge forCommand:commandWrapper.outCommand.avim_conversationForCache];
        }
        
        [self invokeInSpecifiedQueue:^{
            callback(conversations, nil);
        }];
    }];
    
    switch (self.cachePolicy)
    {
        case kAVIMCachePolicyIgnoreCache:
        case kAVIMCachePolicyNetworkOnly:
        case kAVIMCachePolicyNetworkElseCache:
        {
            [client sendCommandWrapper:commandWrapper];
        }break;
        case kAVIMCachePolicyCacheOnly:
        {
            [self fetchCachedResultsForOutCommand:commandWrapper.outCommand client:client callback:^(NSArray *conversations) {
                [self invokeInSpecifiedQueue:^{
                    callback(conversations, nil);
                }];
            }];
        }break;
        case kAVIMCachePolicyCacheElseNetwork:
        {
            [self fetchCachedResultsForOutCommand:commandWrapper.outCommand client:client callback:^(NSArray *conversations) {
                if (conversations.count > 0) {
                    [self invokeInSpecifiedQueue:^{
                        callback(conversations, nil);
                    }];
                } else {
                    [client sendCommandWrapper:commandWrapper];
                }
            }];
        }break;
        case kAVIMCachePolicyCacheThenNetwork:
        {   // issue
            [self fetchCachedResultsForOutCommand:commandWrapper.outCommand client:client callback:^(NSArray *conversations) {
                [self invokeInSpecifiedQueue:^{
                    callback(conversations, nil);
                }];
                [client sendCommandWrapper:commandWrapper];
            }];
        }break;
        default: break;
    }
}

- (void)findTemporaryConversationsWith:(NSArray<NSString *> *)tempConvIds
                              callback:(void (^)(NSArray<AVIMTemporaryConversation *> * _Nullable, NSError * _Nullable))callback
{
    AVIMClient *client = self.client;
    if (!client) {
        [self invokeInSpecifiedQueue:^{
            callback(nil, LCErrorInternal(@"client invalid."));
        }];
        return;
    }
    
    if (!tempConvIds || tempConvIds.count == 0) {
        [self invokeInSpecifiedQueue:^{
            callback(@[], nil);
        }];
        return;
    }
    
    LCIMProtobufCommandWrapper *commandWrapper = ({
        
        AVIMGenericCommand *outCommand = [AVIMGenericCommand new];
        AVIMConvCommand *convCommand = [AVIMConvCommand new];
        
        outCommand.cmd = AVIMCommandType_Conv;
        outCommand.op = AVIMOpType_Query;
        outCommand.convMessage = convCommand;
        
        if (self.option) {
            convCommand.flag = self.option;
        }
        convCommand.tempConvIdsArray = tempConvIds.mutableCopy;
        
        LCIMProtobufCommandWrapper *commandWrapper = [LCIMProtobufCommandWrapper new];
        commandWrapper.outCommand = outCommand;
        commandWrapper;
    });
    
    [commandWrapper setCallback:^(LCIMProtobufCommandWrapper *commandWrapper) {
        
        if (commandWrapper.error) {
            [self invokeInSpecifiedQueue:^{
                callback(nil, commandWrapper.error);
            }];
            return;
        }
        
        NSArray<AVIMTemporaryConversation *> *conversations = ({
            NSMutableArray<NSMutableDictionary *> *results = ({
                NSString *jsonString = commandWrapper.inCommand.convMessage.results.data_p;
                NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                NSError *error = nil;
                NSMutableArray<NSMutableDictionary *> *results = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                if (error) {
                    [self invokeInSpecifiedQueue:^{
                        callback(nil, error);
                    }];
                    return;
                }
                results;
            });
            NSMutableArray<AVIMTemporaryConversation *> *conversations = [NSMutableArray array];
            for (NSMutableDictionary *jsonDic in results) {
                if (![NSMutableDictionary lc__checkingType:jsonDic]) {
                    continue;
                }
                NSString *conversationId = [NSString lc__decodingDictionary:jsonDic key:kLCIMConv_objectId];
                if (!conversationId) {
                    continue;
                }
                AVIMTemporaryConversation *tempConv = (AVIMTemporaryConversation *)[client getConversationFromMemory:conversationId];
                if (tempConv) {
                    [tempConv setRawJSONData:jsonDic];
                    [conversations addObject:tempConv];
                } else {
                    tempConv = [AVIMTemporaryConversation conversationWithRawJSONData:jsonDic client:client];
                    if (tempConv) {
                        [client cacheConversationToMemory:tempConv];
                        [conversations addObject:tempConv];
                    }
                }
            }
            conversations;
        });
        
        [self invokeInSpecifiedQueue:^{
            callback(conversations, nil);
        }];
    }];
    
    [client sendCommandWrapper:commandWrapper];
}

- (void)fetchCachedResultsForOutCommand:(AVIMGenericCommand *)outCommand
                                 client:(AVIMClient *)client
                               callback:(void(^)(NSArray *conversations))callback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *conversations = [client.conversationCache conversationsForCommand:outCommand.avim_conversationForCache];
        [client addOperationToInternalSerialQueue:^(AVIMClient *client) {
            NSMutableArray *results = [NSMutableArray array];
            for (AVIMConversation *conv in conversations) {
                AVIMConversation *convInMemory = [client getConversationFromMemory:conv.conversationId];
                if (convInMemory) {
                    [results addObject:convInMemory];
                } else {
                    [results addObject:conv];
                    [client cacheConversationToMemory:conv];
                }
            }
            callback(results);
        }];
    });
}

@end
