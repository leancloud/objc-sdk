//
//  LCStatus.m
//  paas
//
//  Created by Travis on 13-12-23.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "LCStatus.h"
#import "LCPaasClient.h"
#import "AVErrorUtils.h"
#import "LCObjectUtils.h"
#import "LCObject_Internal.h"
#import "LCQuery_Internal.h"
#import "AVUtils.h"
#import "AVUser_Internal.h"

NSString * const kLCStatusTypeTimeline=@"default";
NSString * const kLCStatusTypePrivateMessage=@"private";

@interface LCStatus () {
    
}
@property (nonatomic,   copy) NSString *objectId;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, assign) NSUInteger messageId;

/* 用Query来设定受众群 */
@property(nonatomic,strong) LCQuery *targetQuery;

+(NSString*)parseClassName;

+(LCStatus*)statusFromCloudData:(NSDictionary*)data;

@end

@implementation LCQuery (Status)

-(NSDictionary*)dictionaryForStatusRequest{
    NSMutableDictionary *dict=[[self assembleParameters] mutableCopy];
    [dict setObject:self.className forKey:@"className"];
    
    //`where` here is a string, but the server ask for dictionary
    [dict removeObjectForKey:@"where"];
    [dict setObject:[LCObjectUtils dictionaryFromDictionary:self.where] forKey:@"where"];
    return dict;
}
@end


@interface LCStatusQuery ()
@property(nonatomic,copy) NSString *externalQueryPath;
@end

@implementation LCStatusQuery

- (id)init
{
    self = [super initWithClassName:[LCStatus parseClassName]];
    if (self) {
        
    }
    return self;
}

- (NSString *)queryPath {
    return self.externalQueryPath?self.externalQueryPath:[super queryPath];
}


- (NSMutableDictionary *)assembleParameters {
    BOOL handleInboxType=NO;
    if (self.inboxType) {
        if (self.externalQueryPath) {
            handleInboxType=YES;
        } else {
            [self whereKey:@"inboxType" equalTo:self.inboxType];
        }
        
    }
    [super assembleParameters];
    
    if (self.sinceId > 0)
    {
        [self.parameters setObject:@(self.sinceId) forKey:@"sinceId"];
    }
    if (self.maxId > 0)
    {
        [self.parameters setObject:@(self.maxId) forKey:@"maxId"];
    }
    
    if (self.owner) {
        [self.parameters setObject:[LCObjectUtils dictionaryFromObjectPointer:self.owner] forKey:@"owner"];
    }
    
    if (handleInboxType) {
        [self.parameters setObject:self.inboxType forKey:@"inboxType"];
    }
    
    return self.parameters;
}

-(void)queryWithBlock:(NSString *)path
           parameters:(NSDictionary *)parameters
                block:(AVArrayResultBlock)resultBlock {
    _end = NO;
    [super queryWithBlock:path parameters:parameters block:resultBlock];
}

- (LCObject *)getFirstObjectWithBlock:(LCObjectResultBlock)resultBlock
                        waitUntilDone:(BOOL)wait
                                error:(NSError **)theError {
    _end = NO;
    return [super getFirstObjectWithBlock:resultBlock waitUntilDone:wait error:theError];
}

// only called in findobjects, these object's data is ready
- (NSMutableArray *)processResults:(NSArray *)results className:(NSString *)className
{
    
    NSMutableArray *statuses=[NSMutableArray arrayWithCapacity:[results count]];
    
    for (NSDictionary *info in results) {
        [statuses addObject:[LCStatus statusFromCloudData:info]];
    }
    [statuses sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"messageId" ascending:NO]]];
    return statuses;
}

- (void)processEnd:(BOOL)end {
    _end = end;
}
@end



@implementation LCStatus

+(NSString*)parseClassName{
    return @"_Status";
}

+ (NSString *)statusInboxPath {
    return @"subscribe/statuses/inbox";
}

+(LCStatus*)statusFromCloudData:(NSDictionary*)data{
    if ([data isKindOfClass:[NSDictionary class]] && data[@"objectId"]) {
        LCStatus *status=[[LCStatus alloc] init];
        
        status.objectId=data[@"objectId"];
        status.type=data[@"inboxType"];
        status.createdAt = [AVDate dateFromValue:data[@"createdAt"]];
        status.messageId=[data[@"messageId"] integerValue];
        status.source=[LCObjectUtils lcObjectFromDictionary:data[@"source"]];
        
        NSMutableDictionary *newData=[data mutableCopy];
        [newData removeObjectsForKeys:@[@"inboxType",@"objectId",@"createdAt",@"updatedAt",@"messageId",@"source"]];
        
        status.data=newData;
        return status;
    }
    
    return nil;
}

+(NSError*)permissionCheck{
    if (![[AVUser currentUser] isAuthDataExistInMemory]) {
        return LCError(kAVErrorUserCannotBeAlteredWithoutSession, nil, nil);
    }
    
    return nil;
}

+(NSString*)stringOfStatusOwner:(NSString*)userObjectId{
    if (userObjectId) {
        NSString *info=[NSString stringWithFormat:@"{\"__type\":\"Pointer\", \"className\":\"_User\", \"objectId\":\"%@\"}",userObjectId];
        return info;
    }
    return nil;
}


#pragma mark - 查询


+(LCStatusQuery*)inboxQuery:(LCStatusType *)inboxType{
    LCStatusQuery *query=[[LCStatusQuery alloc] init];
    query.owner=[AVUser currentUser];
    query.inboxType=inboxType;
    query.externalQueryPath= @"subscribe/statuses";
    return query;
}


+(LCStatusQuery*)statusQuery{
    LCStatusQuery *q=[[LCStatusQuery alloc] init];
    [q whereKey:@"source" equalTo:[AVUser currentUser]];
    return q;
}

+(void)getStatusesWithType:(LCStatusType*)type skip:(NSUInteger)skip limit:(NSUInteger)limit andCallback:(AVArrayResultBlock)callback{
    NSParameterAssert(type);
    
    NSError *error=[self permissionCheck];
    if (error) {
        callback(nil,error);
        return;
    }
    
    if (limit>100 || limit<=0) {
        limit=100;
    }
    
    LCStatusQuery *q=[LCStatus inboxQuery:type];
    q.limit=limit;
    q.skip=skip;
    [q findObjectsInBackgroundWithBlock:callback];
    
}
+(void) getStatusesFromCurrentUserWithType:(LCStatusType*)type skip:(NSUInteger)skip limit:(NSUInteger)limit andCallback:(AVArrayResultBlock)callback{
    
    NSError *error=[self permissionCheck];
    if (error) {
        callback(nil,error);
        return;
    }
    
    [self getStatusesFromUser:[AVUser currentUser].objectId skip:skip limit:limit andCallback:callback];
    
}
+(void)getStatusesFromUser:(NSString *)userId skip:(NSUInteger)skip limit:(NSUInteger)limit andCallback:(AVArrayResultBlock)callback{
    NSParameterAssert(userId);
    
    LCQuery *q=[LCStatus statusQuery];
    q.limit=limit;
    q.skip=skip;
    [q whereKey:@"source" equalTo:[LCObject objectWithoutDataWithClassName:@"_User" objectId:userId]];
    [q findObjectsInBackgroundWithBlock:callback];
}



+(void)getStatusWithID:(NSString *)objectId andCallback:(LCStatusResultBlock)callback{
    NSError *error=[self permissionCheck];
    if (error) {
        callback(nil,error);
        return;
    }
    
    NSString *owner=[LCStatus stringOfStatusOwner:[AVUser currentUser].objectId];
    [[LCPaasClient sharedInstance] getObject:[NSString stringWithFormat:@"statuses/%@",objectId] withParameters:@{@"owner":owner,@"include":@"source"} block:^(id object, NSError *error) {
        
        if (!error) {
            
            object = [self statusFromCloudData:object];
        }
        
        [AVUtils callIdResultBlock:callback object:object error:error];
    }];
}

+(void)deleteStatusWithID:(NSString *)objectId andCallback:(AVBooleanResultBlock)callback{
    NSError *error=[self permissionCheck];
    if (error) {
        callback(NO,error);
        return;
    }
    
    NSString *owner=[LCStatus stringOfStatusOwner:[AVUser currentUser].objectId];
    [[LCPaasClient sharedInstance] deleteObject:[NSString stringWithFormat:@"statuses/%@",objectId] withParameters:@{@"owner":owner} block:^(id object, NSError *error) {
        
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}

+ (BOOL)deleteInboxStatusForMessageId:(NSUInteger)messageId inboxType:(NSString *)inboxType receiver:(NSString *)receiver error:(NSError *__autoreleasing *)error {
    if (!receiver) {
        if (error) *error = LCErrorInternal(@"Receiver of status can not be nil.");
        return NO;
    }

    if (!inboxType) {
        if (error) *error = LCErrorInternal(@"Inbox type of status can not be nil.");
        return NO;
    }

    NSDictionary *parameters = @{
        @"messageId" : [NSString stringWithFormat:@"%lu", (unsigned long)messageId],
        @"owner"     : [LCObjectUtils dictionaryFromObjectPointer:[AVUser objectWithoutDataWithObjectId:receiver]],
        @"inboxType" : inboxType
    };

    __block NSError *responseError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    [[LCPaasClient sharedInstance] deleteObject:[self statusInboxPath] withParameters:parameters block:^(id object, NSError *error) {
        responseError = error;
        dispatch_semaphore_signal(sema);
    }];

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

    if (error) {
        *error = responseError;
    }

    return responseError == nil;
}

+ (void)deleteInboxStatusInBackgroundForMessageId:(NSUInteger)messageId inboxType:(NSString *)inboxType receiver:(NSString *)receiver block:(AVBooleanResultBlock)block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        [self deleteInboxStatusForMessageId:messageId inboxType:inboxType receiver:receiver error:&error];
        [AVUtils callBooleanResultBlock:block error:error];
    });
}

+(void)getUnreadStatusesCountWithType:(LCStatusType*)type andCallback:(AVIntegerResultBlock)callback{
    NSError *error=[self permissionCheck];

    if (error) {
        [AVUtils callIntegerResultBlock:callback number:0 error:error];
        return;
    }
    
    NSString *owner=[LCStatus stringOfStatusOwner:[AVUser currentUser].objectId];
    
    [[LCPaasClient sharedInstance] getObject:@"subscribe/statuses/count" withParameters:@{@"owner":owner,@"inboxType":type} block:^(id object, NSError *error) {
        NSUInteger count=[object[@"unread"] integerValue];
        [AVUtils callIntegerResultBlock:callback number:count error:error];
    }];
}

+ (void)resetUnreadStatusesCountWithType:(LCStatusType *)type andCallback:(AVBooleanResultBlock)callback {
    NSError *error = [self permissionCheck];

    if (error) {
        [AVUtils callBooleanResultBlock:callback error:error];
        return;
    }

    NSString *owner = [LCStatus stringOfStatusOwner:[AVUser currentUser].objectId];

    [[LCPaasClient sharedInstance] postObject:@"subscribe/statuses/resetUnreadCount" withParameters:@{@"owner": owner, @"inboxType": type} block:^(id object, NSError *error) {
        [AVUtils callBooleanResultBlock:callback error:error];
    }];
}

+(void)sendStatusToFollowers:(LCStatus*)status andCallback:(AVBooleanResultBlock)callback{
    NSError *error=[self permissionCheck];
    if (error) {
        callback(NO,error);
        return;
    }
    status.source=[AVUser currentUser];
    status.targetQuery=[AVUser followerQuery:[AVUser currentUser].objectId];
    [status sendInBackgroundWithBlock:callback];
}

+(void)sendPrivateStatus:(LCStatus *)status toUserWithID:(NSString *)userId andCallback:(AVBooleanResultBlock)callback{
    NSError *error=[self permissionCheck];
    if (error) {
        callback(NO,error);
        return;
    }
    status.source=[AVUser currentUser];
    [status setType:kLCStatusTypePrivateMessage];
    
    LCQuery *q=[AVUser query];
    [q whereKey:@"objectId" equalTo:userId];
    
    status.targetQuery=q;
    [status sendInBackgroundWithBlock:callback];
}

-(void)setQuery:(LCQuery*)query{
    self.targetQuery=query;
}

-(NSError *)preSave
{
    NSParameterAssert(self.data);
    
    if ([self objectId]) {
        return LCError(kAVErrorOperationForbidden, @"status can't be update", nil);
    }
    
    if ([AVUser currentUser]==nil) {
        return LCError(kAVErrorOperationForbidden, @"do NOT have an current user, please login first", nil);
    }
    
    if (self.source==nil) {
        self.source=[AVUser currentUser];
    }
    
    if (self.targetQuery==nil) {
        self.targetQuery=[AVUser followerQuery:[AVUser currentUser].objectId];
    }
    
    if (self.type==nil) {
        [self setType:kLCStatusTypeTimeline];
    }

    return nil;
}

-(void)sendInBackgroundWithBlock:(AVBooleanResultBlock)block{
    NSError *error=[self preSave];
    if (error) {
        block(NO,error);
        return;
    }
    
    NSMutableDictionary *body=[NSMutableDictionary dictionary];
    
    NSMutableDictionary *data=[self.data mutableCopy];
    [data setObject:self.source forKey:@"source"];
    
    [body setObject:[LCObjectUtils dictionaryFromDictionary:data] forKey:@"data"];
    
    
    NSDictionary *queryInfo=[self.targetQuery dictionaryForStatusRequest];
    
    [body setObject:queryInfo forKey:@"query"];
    [body setObject:self.type forKey:@"inboxType"];

    LCPaasClient *client = [LCPaasClient sharedInstance];
    NSURLRequest *request = [client requestWithPath:@"statuses" method:@"POST" headers:nil parameters:body];

    [client
     performRequest:request
     success:^(NSHTTPURLResponse *response, id responseObject) {
         if ([responseObject isKindOfClass:[NSDictionary class]]) {
             NSString *objectId = responseObject[@"objectId"];

             if (objectId) {
                 self.objectId = objectId;
                 self.createdAt = [AVDate dateFromValue:responseObject[@"createdAt"]];
                 [AVUtils callBooleanResultBlock:block error:nil];
                 return;
             }
         }

         [AVUtils callBooleanResultBlock:block error:LCError(kAVErrorInvalidJSON, @"unexpected result return", nil)];
     }
     failure:^(NSHTTPURLResponse *response, id responseObject, NSError *error) {
         [AVUtils callBooleanResultBlock:block error:error];
     }];
}

-(NSString*)debugDescription{
    if (self.messageId>0) {
        return [[super debugDescription] stringByAppendingFormat:@" <id: %@,messageId:%lu type: %@, createdAt:%@, source:%@(%@)>: %@",self.objectId,(unsigned long)self.messageId,self.type,self.createdAt,NSStringFromClass([self.source class]), [self.source objectId],[self.data debugDescription]];
    }
    return [[super debugDescription] stringByAppendingFormat:@" <id: %@, type: %@, createdAt:%@, source:%@(%@)>: %@",self.objectId,self.type,self.createdAt,NSStringFromClass([self.source class]), [self.source objectId],[self.data debugDescription]];
}

@end

