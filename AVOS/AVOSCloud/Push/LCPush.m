//
//  LCPush.h
//  AVOS Inc
//

#import <Foundation/Foundation.h>
#import "LCPush.h"
#import "LCPush_Internal.h"
#import "LCPaasClient.h"
#import "AVUtils.h"
#import "LCQuery_Internal.h"
#import "LCInstallation_Internal.h"
#import "LCObjectUtils.h"
#import "LCRouter_Internal.h"

/*!
 A class which defines a push notification that can be sent from
 a client device.

 The preferred way of modifying or retrieving channel subscriptions is to use
 the LCInstallation class, instead of the class methods in LCPush.

 This class is currently for iOS only. LeanCloud does not handle Push Notifications
 to LeanCloud applications running on OS X. Push Notifications can be sent from OS X
 applications via Cloud Code or the REST API to push-enabled devices (e.g. iOS
 or Android).
 */

static BOOL _isProduction = YES;
static BOOL _isIgnoreProd = false;

NSString *const kLCPushTargetPlatformIOS = @"ios";
NSString *const kLCPushTargetPlatformAndroid = @"android";
NSString *const kLCPushTargetPlatformWindowsPhone = @"wp";

@implementation LCPush

@synthesize pushQuery = _pushQuery;
@synthesize pushChannels = _pushChannels;
@synthesize pushData = _pushData;
@synthesize expirationDate = _expirationDate;
@synthesize expireTimeInterval = _expireTimeInterval;
@synthesize pushTarget = _pushTarget;

+(NSString *)myObjectPath
{
    return [[LCRouter sharedInstance] appURLForPath:@"push" appID:[AVOSCloud getApplicationId]];
}

-(id)init
{
    self = [super init];
    _pushChannels = [[NSMutableArray alloc] init];
    _pushData = [[NSMutableDictionary alloc] init];
    
    _pushTarget = [[NSMutableArray alloc] init];
    return self;
}

+ (instancetype)push
{
    LCPush * push = [[LCPush alloc] init];
    return push;
}

/*! @name Configuring a Push Notification */

/*!
 Sets the channel on which this push notification will be sent.
 @param channel The channel to set for this push. The channel name must start
 with a letter and contain only letters, numbers, dashes, and underscores.
 */
- (void)setChannel:(NSString *)channel
{
    [self.pushChannels removeAllObjects];
    [self.pushChannels addObject:channel];
}

- (void)setChannels:(NSArray *)channels
{
    [self.pushChannels removeAllObjects];
    [self.pushChannels addObjectsFromArray:channels];
}

- (void)setQuery:(LCQuery *)query
{
    self.pushQuery = query;
}

- (void)setMessage:(NSString *)message
{
    [self.pushData removeAllObjects];
    [self.pushData setObject:message forKey:@"alert"];
}

- (void)setData:(NSDictionary *)data
{
    [self.pushData removeAllObjects];
    [self.pushData addEntriesFromDictionary:data];
}

- (void)setPushToTargetPlatforms:(NSArray *)platforms {
    if (platforms) {
        self.pushTarget = [platforms mutableCopy];
    } else {
        self.pushTarget = [[NSMutableArray alloc] init];
    }
}

- (void)setPushToAndroid:(BOOL)pushToAndroid {
    if (pushToAndroid) {
        [self.pushTarget addObject:kLCPushTargetPlatformAndroid];
    } else {
        [self.pushTarget removeObject:kLCPushTargetPlatformAndroid];
    }
}

- (void)setPushToIOS:(BOOL)pushToIOS {
    if (pushToIOS) {
        [self.pushTarget addObject:kLCPushTargetPlatformIOS];
    } else {
        [self.pushTarget removeObject:kLCPushTargetPlatformIOS];
    }
}

- (void)setPushToWP:(BOOL)pushToWP {
    if (pushToWP) {
        [self.pushTarget addObject:kLCPushTargetPlatformWindowsPhone];
    } else {
        [self.pushTarget removeObject:kLCPushTargetPlatformWindowsPhone];
    }
}

- (void)setPushDate:(NSDate *)dateToPush{
    self.pushTime=dateToPush;
}

- (void)expireAtDate:(NSDate *)date
{
    self.expirationDate = date;
}

- (void)expireAfterTimeInterval:(NSTimeInterval)timeInterval
{
    self.expireTimeInterval = timeInterval;
}

- (void)clearExpiration
{
    self.expirationDate = nil;
    self.expireTimeInterval = 0.0;
}

+ (void)setProductionMode:(BOOL)isProduction {
    _isProduction = isProduction;
}

+ (void)setIgnoreProdParameterEnabled:(BOOL)isIgnoreProd {
    _isIgnoreProd = isIgnoreProd;
}

+ (BOOL)sendPushMessage:(LCPush *)push
                   wait:(BOOL)wait
                  block:(AVBooleanResultBlock)block
                  error:(NSError **)theError
{
    BOOL __block theResult = NO;
    BOOL __block hasCalledBack = NO;
    NSError __block *blockError = nil;
    
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        [AVUtils callBooleanResultBlock:block error:error];
        blockError = error;
        
        if (wait) {
            theResult = (error == nil);
            hasCalledBack = YES;
        }
    }];
    
    // wait until called back if necessary
    if (wait) {
        [AVUtils warnMainThreadIfNecessary];
        AV_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (theError != NULL) *theError = blockError;
    return theResult;
}


+ (BOOL)sendPushMessageToChannel:(NSString *)channel
                     withMessage:(NSString *)message
                           error:(NSError **)error
{
    LCPush * push = [LCPush push];
    [push setChannel:channel];
    [push setMessage:message];
    return [LCPush sendPushMessage:push wait:YES block:^(BOOL succeeded, NSError *error) {} error:error];
}

+ (void)sendPushMessageToChannelInBackground:(NSString *)channel
                                 withMessage:(NSString *)message
{
    LCPush * push = [LCPush push];
    [push setChannel:channel];
    [push setMessage:message];
    [LCPush sendPushMessage:push wait:YES block:^(BOOL succeeded, NSError *error) {} error:nil];
}

+ (void)sendPushMessageToChannelInBackground:(NSString *)channel
                                 withMessage:(NSString *)message
                                       block:(AVBooleanResultBlock)block
{
    LCPush * push = [LCPush push];
    [push setChannel:channel];
    [push setMessage:message];
    [LCPush sendPushMessage:push wait:YES block:block error:nil];
}

+ (BOOL)sendPushMessageToQuery:(LCQuery *)query
                   withMessage:(NSString *)message
                         error:(NSError **)theError
{
    LCPush * push = [LCPush push];
    [push setQuery:query];
    [push setMessage:message];
    return [LCPush sendPushMessage:push wait:YES block:^(BOOL succeeded, NSError *error) {} error:theError];
}

+ (void)sendPushMessageToQueryInBackground:(LCQuery *)query
                               withMessage:(NSString *)message
{
    LCPush * push = [LCPush push];
    [push setQuery:query];
    [push setMessage:message];
    [LCPush sendPushMessage:push wait:NO block:^(BOOL succeeded, NSError *error) {} error:nil];
}

+ (void)sendPushMessageToQueryInBackground:(LCQuery *)query
                               withMessage:(NSString *)message
                                     block:(AVBooleanResultBlock)block
{
    LCPush * push = [LCPush push];
    [push setQuery:query];
    [push setMessage:message];
    [LCPush sendPushMessage:push wait:NO block:block error:nil];
}

- (BOOL)sendPush:(NSError **)error
{
    return [LCPush sendPushMessage:self wait:YES block:^(BOOL succeeded, NSError *error) {} error:error];
}

- (BOOL)sendPushAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self sendPush:error];
}

- (void)sendPushInBackground
{
    [LCPush sendPushMessage:self wait:NO block:^(BOOL succeeded, NSError *error) {} error:nil];
}

-(NSDictionary *)queryData
{
    return [self.pushQuery assembleParameters];
}

-(NSDictionary *) pushChannelsData
{
    return @{channelsTag:self.pushChannels};
}

-(NSDictionary *)pushDataMessage
{
    return @{@"data": self.pushData};
}

-(NSMutableDictionary *)postData
{
    NSMutableDictionary * data = [[NSMutableDictionary alloc] init];
    NSString *prod = @"prod";
    if (!_isProduction) {
        prod = @"dev";
    }
    if (!_isIgnoreProd) {
        [data setObject:prod forKey:@"prod"];
    }
    if (self.pushQuery)
    {
        [data addEntriesFromDictionary:[self queryData]];
    }
    else if (self.pushChannels.count > 0)
    {
        [data addEntriesFromDictionary:[self pushChannelsData]];
    }
    
    if (self.pushTime) {
        data[@"push_time"] = [AVDate stringFromDate:self.pushTime];
    }
    if (self.expirationDate) {
        data[@"expiration_time"] = [AVDate stringFromDate:self.expirationDate];
    }
    if (self.expireTimeInterval > 0) {
        if (!self.pushTime) {
            data[@"push_time"] = [AVDate stringFromDate:[NSDate date]];
        }
        data[@"expiration_interval"] = @(self.expireTimeInterval);
    }
    
    if (self.pushTarget.count > 0)
    {
        NSMutableDictionary *where = [[NSMutableDictionary alloc] init];
        NSDictionary *condition = @{@"$in": self.pushTarget};
        [where setObject:condition forKey:deviceTypeTag];
        [data setObject:where forKey:@"where"];
    }
    
    [data addEntriesFromDictionary:[self pushDataMessage]];
    return data;
}

- (void)sendPushInBackgroundWithBlock:(AVBooleanResultBlock)block
{
    NSString *path = [LCPush myObjectPath];
    [[LCPaasClient sharedInstance] postObject:path
                               withParameters:[self postData]
                                   eventually:false
                                        block:^(id object, NSError *error) {
                                                [AVUtils callBooleanResultBlock:block error:error];
    }];
}

+ (BOOL)sendPushDataToChannel:(NSString *)channel
                     withData:(NSDictionary *)data
                        error:(NSError **)error
{
    LCPush * push = [LCPush push];
    [push setChannel:channel];
    [push setData:data];
    return [LCPush sendPushMessage:push wait:YES block:nil error:error];
}

+ (void)sendPushDataToChannelInBackground:(NSString *)channel
                                 withData:(NSDictionary *)data
{
    LCPush * push = [LCPush push];
    [push setChannel:channel];
    [push setData:data];
    [LCPush sendPushMessage:push wait:YES block:nil error:nil];
}

+ (void)sendPushDataToChannelInBackground:(NSString *)channel
                                 withData:(NSDictionary *)data
                                    block:(AVBooleanResultBlock)block
{
    LCPush * push = [LCPush push];
    [push setChannel:channel];
    [push setData:data];
    [LCPush sendPushMessage:push wait:NO block:block error:nil];
}

+ (BOOL)sendPushDataToQuery:(LCQuery *)query
                   withData:(NSDictionary *)data
                      error:(NSError **)error
{
    LCPush * push = [LCPush push];
    [push setQuery:query];
    [push setData:data];
    return [LCPush sendPushMessage:push wait:YES block:nil error:error];
}

+ (void)sendPushDataToQueryInBackground:(LCQuery *)query
                               withData:(NSDictionary *)data
{
    LCPush * push = [LCPush push];
    [push setQuery:query];
    [push setData:data];
    [LCPush sendPushMessage:push wait:NO block:nil error:nil];
}

+ (void)sendPushDataToQueryInBackground:(LCQuery *)query
                               withData:(NSDictionary *)data
                                  block:(AVBooleanResultBlock)block
{
    LCPush * push = [LCPush push];
    [push setQuery:query];
    [push setData:data];
    [LCPush sendPushMessage:push wait:NO block:block error:nil];
}

+ (NSSet *)getSubscribedChannels:(NSError **)error
{
    return [LCPush getSubscribedChannelsWithBlock:^(NSSet *channels, NSError *error) {
    } wait:YES error:error];
}

+ (NSSet *)getSubscribedChannelsAndThrowsWithError:(NSError * _Nullable __autoreleasing *)error {
    return [self getSubscribedChannels:error];
}

+ (void)getSubscribedChannelsInBackgroundWithBlock:(AVSetResultBlock)block
{
    [LCPush getSubscribedChannelsWithBlock:^(NSSet *channels, NSError *error) {
        [AVUtils callSetResultBlock:block set:channels error:error];
    } wait:NO error:nil];
}

+ (NSSet *)getSubscribedChannelsWithBlock:(AVSetResultBlock)block
                                     wait:(BOOL)wait
                                    error:(NSError **)theError
{
    BOOL __block theResult = NO;
    BOOL __block hasCalledBack = NO;
    NSError __block *blockError = nil;
    __block  NSSet * resultSet = nil;

    LCQuery * query = [LCInstallation query];
    [query whereKey:deviceTokenTag equalTo:[LCInstallation defaultInstallation].deviceToken];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (objects.count > 0)
        {
            LCInstallation * installation = [objects objectAtIndex:0];
            resultSet = [NSSet setWithArray:installation.channels];
        }
        [AVUtils callSetResultBlock:block set:resultSet error:error];
        
        blockError = error;
        
        if (wait) {
            theResult = (error == nil);
            hasCalledBack = YES;
        }
    }];
    
    // wait until called back if necessary
    if (wait) {
        [AVUtils warnMainThreadIfNecessary];
        AV_WAIT_TIL_TRUE(hasCalledBack, 0.1);
    };
    
    if (theError != NULL) *theError = blockError;
    return resultSet;
}


+ (BOOL)subscribeToChannel:(NSString *)channel error:(NSError **)error
{
    LCInstallation * installation = [LCInstallation defaultInstallation];
    [installation addUniqueObject:channel forKey:channelsTag];
    return [installation save:error];
}

+ (void)subscribeToChannelInBackground:(NSString *)channel
{
    LCInstallation * installation = [LCInstallation defaultInstallation];
    [installation addUniqueObject:channel forKey:channelsTag];
    [installation saveInBackground];
}

+ (void)subscribeToChannelInBackground:(NSString *)channel
                                 block:(AVBooleanResultBlock)block
{
    LCInstallation * installation = [LCInstallation defaultInstallation];
    [installation addUniqueObject:channel forKey:channelsTag];
    [installation saveInBackgroundWithBlock:block];
}

+ (BOOL)unsubscribeFromChannel:(NSString *)channel error:(NSError **)error
{
    LCInstallation * installation = [LCInstallation defaultInstallation];
    [installation removeObject:channel forKey:channelsTag];
    return [installation save:error];
}

+ (void)unsubscribeFromChannelInBackground:(NSString *)channel
{
    LCInstallation * installation = [LCInstallation defaultInstallation];
    [installation removeObject:channel forKey:channelsTag];
    [installation saveInBackground];
}


+ (void)unsubscribeFromChannelInBackground:(NSString *)channel
                                     block:(AVBooleanResultBlock)block
{
    LCInstallation * installation = [LCInstallation defaultInstallation];
    [installation removeObject:channel forKey:channelsTag];
    [installation saveInBackgroundWithBlock:block];
}

@end
