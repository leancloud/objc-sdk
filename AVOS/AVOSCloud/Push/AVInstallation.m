//
//  AVInstallation.m
//  LeanCloud

#import <Foundation/Foundation.h>
#import "AVObject_Internal.h"
#import "AVQuery.h"
#import "AVInstallation.h"
#import "AVPaasClient.h"
#import "AVInstallation_Internal.h"
#import "AVUtils.h"
#import "AVObjectUtils.h"
#import "AVPersistenceUtils.h"
#import "AVErrorUtils.h"
#import "LCRouter_Internal.h"

@implementation AVInstallation

+ (AVQuery *)query
{
    AVQuery *query = [[AVQuery alloc] initWithClassName:@"_Installation"];
    return query;
}

+(AVQuery *)installationQuery
{
    AVQuery *query = [[AVQuery alloc] initWithClassName:[AVInstallation className]];
    return query;
}

+(NSString *)installationTag
{
    return @"Installation";
}

+(AVInstallation *)installation
{
    AVInstallation * installation = [[AVInstallation alloc] init];
    return installation;
}

+ (AVInstallation *)defaultInstallation
{
    static AVInstallation *installation = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        installation = [[AVInstallation alloc] init];
    });
    
    return installation;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.className  = [AVInstallation className];
        self.deviceType = [AVInstallation deviceType];
        self.timeZone   = [[NSTimeZone systemTimeZone] name];
        self.apnsTopic  = [NSBundle mainBundle].bundleIdentifier;
        
        NSString *path = [AVPersistenceUtils currentInstallationArchivePath];
        if ([AVPersistenceUtils fileExist:path]) {
            NSMutableDictionary *installationDict = [NSMutableDictionary dictionaryWithDictionary:[AVPersistenceUtils getJSONFromPath:path]];
            if (installationDict) {
                [AVObjectUtils copyDictionary:installationDict toObject:self];
            }
        }
    }
    return self;
}

- (void)setDeviceTokenFromData:(NSData *)deviceTokenData
{
    [self setDeviceTokenFromData:deviceTokenData
                          teamId:nil];
}

- (void)setDeviceTokenFromData:(NSData *)deviceTokenData
                        teamId:(NSString *)teamId
{
    if (!deviceTokenData || deviceTokenData.length == 0) {
        
        return;
    }
    
    NSCharacterSet *charactersSet = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
    
    NSString *newDeviceToken = [deviceTokenData.description stringByTrimmingCharactersInSet:charactersSet];
    
    newDeviceToken = [newDeviceToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    if (newDeviceToken.length == 0) {
        
        return;
    }
    
    NSString *oldDeviceToken = self.deviceToken;
    
    NSString *oldTeamId = self.apnsTeamId;
    
    if (![oldDeviceToken isEqualToString:newDeviceToken] || ![teamId isEqualToString:oldTeamId]) {
        
        self.deviceToken = newDeviceToken;
        
        self.apnsTeamId = teamId;
        
        [self._requestManager synchronize:^{
            
            [self updateInstallationDictionary:[self._requestManager setDict]];
        }];
    }
}

+(NSString *)deviceType
{
#if TARGET_OS_TV
    return @"tvos";
#elif TARGET_OS_WATCH
    return @"watchos";
#elif TARGET_OS_IOS
    return @"ios";
#elif AV_TARGET_OS_OSX
    return @"osx";
#else
    return @"unknown";
#endif
}

- (NSMutableDictionary *)installationDictionaryForCache {
    NSMutableDictionary *data = [self postData];
    return data;
}

- (void)saveInstallationToLocalCache {
    [AVPersistenceUtils saveJSON:[self installationDictionaryForCache]
                          toPath:[AVPersistenceUtils currentInstallationArchivePath]];
}

- (BOOL)isDirty {
    if ([super isDirty]) {
        return YES;
    } else if ([AVInstallation defaultInstallation] == self) {
        /* If cache expired, we deem that it is dirty. */
        if (!self.updatedAt || [self.updatedAt timeIntervalSinceNow] < - 60 * 60 * 24) {
            return YES;
        }
    }

    return NO;
}

-(NSError *)preSave {
    if ([self isDirty]) {
        [self._requestManager synchronize:^{
            [self updateInstallationDictionary:[self._requestManager setDict]];
        }];
    }
    if (self.installationId==nil && self.deviceToken==nil) {
        return LCError(kAVErrorInvalidDeviceToken, @"无法保存Installation数据, 请检查deviceToken是否在`application: didRegisterForRemoteNotificationsWithDeviceToken`方法中正常设置", nil);
    }

    return nil;
}

-(void)postSave {
    [super postSave];
    [self saveInstallationToLocalCache];
}

-(NSMutableDictionary *)updateInstallationDictionary:(NSMutableDictionary * )data
{
    [data addEntriesFromDictionary:@{
        badgeTag: @(self.badge),
        deviceTypeTag: [AVInstallation deviceType],
        timeZoneTag: self.timeZone,
    }];

    if (self.objectId) {
        [data setObject:self.objectId forKey:@"objectId"];
    }
    if (self.channels)
    {
        [data setObject:self.channels forKey:channelsTag];
    }
    if (self.installationId)
    {
        [data setObject:self.installationId forKey:installationIdTag];
    }
    if (self.deviceToken)
    {
        [data setObject:self.deviceToken forKey:deviceTokenTag];
    }
    if (self.deviceProfile)
    {
        [data setObject:self.deviceProfile forKey:deviceProfileTag];
    }
    if (self.apnsTopic) {
        [data setObject:self.apnsTopic forKey:topicTag];
    }
    if (self.apnsTeamId) {
        [data setObject:self.apnsTeamId forKey:@"apnsTeamId"];
    }

    __block NSDictionary *localDataCopy = nil;
    [self internalSyncLock:^{
        localDataCopy = self._localData.copy;
    }];
    NSDictionary *updationData = [AVObjectUtils dictionaryFromObject:localDataCopy];

    [data addEntriesFromDictionary:updationData];

    return data;
}

+(NSString *)className
{
    return @"_Installation";
}

+(NSString *)endPoint
{
    return @"installations";    
}

-(void)setBadge:(NSInteger)badge {
    _badge = badge;
    [self addSetRequest:badgeTag object:@(self.badge)];
}

-(void)setChannels:(NSArray *)channels {
    if ([_channels isEqual:channels]) {
        return;
    }
    _channels = channels;
    [self addSetRequest:channelsTag object:self.channels];
}

-(void)setDeviceToken:(NSString *)deviceToken {
    if ([_deviceToken isEqualToString:deviceToken]) {
        return;
    }
    _deviceToken = deviceToken;
    [self addSetRequest:deviceTokenTag object:self.deviceToken];
}

-(void)setDeviceProfile:(NSString *)deviceProfile {
    if ([_deviceProfile isEqualToString:deviceProfile]) {
        return;
    }
    _deviceProfile = deviceProfile;
    [self addSetRequest:deviceProfileTag object:self.deviceProfile];
}

- (void)setApnsTopic:(NSString *)apnsTopic
{
    if (_apnsTopic && [_apnsTopic isEqualToString:apnsTopic]) {
        
        return;
    }
    
    _apnsTopic = apnsTopic;
    
    [self addSetRequest:@"apnsTopic" object:apnsTopic];
}

- (void)setApnsTeamId:(NSString *)apnsTeamId
{
    if (_apnsTeamId && [_apnsTeamId isEqualToString:apnsTeamId]) {
        
        return;
    }
    
    _apnsTeamId = apnsTeamId;
    
    [self addSetRequest:@"apnsTeamId" object:apnsTeamId];
}

- (void)postProcessBatchRequests:(NSMutableArray *)requests {
    NSString *path = [[self class] endPoint];
    NSString *batchPath = [[LCRouter sharedInstance] batchPathForPath:path];

    for (NSMutableDictionary *request in [requests copy]) {
        if ([request_path(request) hasPrefix:batchPath] && [request_method(request) isEqualToString:@"PUT"]) {
            request[@"method"] = @"POST";
            request[@"path"]   = batchPath;
            request[@"body"][@"objectId"]    = self.objectId;
            request[@"body"][@"deviceType"]  = self.deviceType;
            request[@"body"][@"deviceToken"] = self.deviceToken;
        }
    }
}

// MARK: - Deprecated

+ (AVInstallation *)currentInstallation
{
    return [AVInstallation defaultInstallation];
}

@end
