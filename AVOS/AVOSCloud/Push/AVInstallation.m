//
//  AVInstallation.m
//  LeanCloud

#import <Foundation/Foundation.h>
#import "AVInstallation_Internal.h"
#import "AVObject_Internal.h"
#import "AVPaasClient.h"
#import "AVUtils.h"
#import "AVObjectUtils.h"
#import "AVPersistenceUtils.h"
#import "AVErrorUtils.h"
#import "LCRouter_Internal.h"

@implementation AVInstallation

+ (NSString *)className
{
    return @"_Installation";
}

+ (NSString *)endPoint
{
    return @"installations";
}

+ (instancetype)installation
{
    return [[AVInstallation alloc] init];
}

+ (AVQuery *)query
{
    return [[AVQuery alloc] initWithClassName:[AVInstallation className]];
}

+ (instancetype)defaultInstallation
{
    static AVInstallation *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [AVInstallation installation];
        NSString *path = [AVPersistenceUtils currentInstallationArchivePath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:
                                               [AVPersistenceUtils getJSONFromPath:path]];
            if (dictionary) {
                [AVObjectUtils copyDictionary:dictionary
                                     toObject:instance];
            }
        }
    });
    return instance;
}

+ (instancetype)currentInstallation
{
    return [AVInstallation defaultInstallation];
}

+ (NSString *)deviceType
{
#if TARGET_OS_TV
    return @"tvos";
#elif TARGET_OS_WATCH
    return @"watchos";
#elif TARGET_OS_IOS
    return @"ios";
#elif TARGET_OS_OSX
    return @"macos";
#else
    return nil;
#endif
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.className = [AVInstallation className];
        _deviceType = [AVInstallation deviceType];
        _timeZone = [[NSTimeZone systemTimeZone] name];
        _apnsTopic = [NSBundle mainBundle].bundleIdentifier;
    }
    return self;
}

- (NSString *)hexadecimalStringFromData:(NSData *)data
{
    NSUInteger dataLength = data.length;
    if (!dataLength) {
        return nil;
    }
    const unsigned char *dataBuffer = data.bytes;
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendFormat:@"%02.2hhx", dataBuffer[i]];
    }
    return hexString;
}

- (void)setDeviceTokenFromData:(NSData *)deviceTokenData
                        teamId:(NSString *)teamId
{
    NSString *deviceTokenHexString = [self hexadecimalStringFromData:deviceTokenData];
    if (![deviceTokenHexString length]) {
        return;
    }
    [self setDeviceTokenHexString:deviceTokenHexString
                           teamId:teamId];
}

- (void)setDeviceTokenHexString:(NSString *)deviceTokenString
                         teamId:(NSString *)teamId
{
    [self setDeviceToken:deviceTokenString];
    [self setApnsTeamId:teamId];
}

- (void)postProcessBatchRequests:(NSMutableArray *)requests
{
    NSString *batchPath = [[LCRouter sharedInstance] batchPathForPath:[AVInstallation endPoint]];
    for (NSMutableDictionary *request in [requests copy]) {
        if ([request_path(request) hasPrefix:batchPath] &&
            ([request_method(request) isEqualToString:@"PUT"] ||
             [request_method(request) isEqualToString:@"POST"])) {
            request[@"method"] = @"POST";
            request[@"path"] = batchPath;
            NSMutableDictionary *body = request[@"body"];
            [body removeObjectForKey:keyPath(self, createdAt)];
            [body removeObjectForKey:keyPath(self, updatedAt)];
            [body removeObjectForKey:kAVTypeTag];
            [body removeObjectForKey:classNameTag];
            if (self.deviceToken) {
                body[keyPath(self, deviceToken)] = self.deviceToken;
            }
            if (self.apnsTeamId) {
                body[keyPath(self, apnsTeamId)] = self.apnsTeamId;
            }
            if (self.objectId) {
                body[keyPath(self, objectId)] = self.objectId;
            }
            if (self.deviceType) {
                body[keyPath(self, deviceType)] = self.deviceType;
            }
            if (self.timeZone) {
                body[keyPath(self, timeZone)] = self.timeZone;
            }
            if (self.apnsTopic) {
                body[keyPath(self, apnsTopic)] = self.apnsTopic;
            }
        }
    }
}

- (NSError *)preSave
{
    if (![self.deviceToken length]) {
        return LCError(9976, @"deviceToken not found.", nil);
    }
    if (![self.apnsTeamId length]) {
        return LCError(9976, @"apnsTeamId not found.", nil);
    }
    return nil;
}

- (void)postSave
{
    [super postSave];
    if (self == [AVInstallation defaultInstallation]) {
        NSMutableDictionary *data = [self postData];
        if (self.deviceToken) {
            data[keyPath(self, deviceToken)] = self.deviceToken;
        }
        if (self.apnsTeamId) {
            data[keyPath(self, apnsTeamId)] = self.apnsTeamId;
        }
        [AVPersistenceUtils saveJSON:data toPath:[AVPersistenceUtils currentInstallationArchivePath]];
    }
}

- (void)setBadge:(NSInteger)badge {
    _badge = badge;
    [self addSetRequest:keyPath(self, badge) object:@(badge)];
}

- (void)setChannels:(NSArray *)channels {
    _channels = channels;
    [self addSetRequest:keyPath(self, channels) object:channels];
}

- (void)setDeviceToken:(NSString *)deviceToken {
    _deviceToken = [deviceToken copy];
    [self addSetRequest:keyPath(self, deviceToken) object:_deviceToken];
}

- (void)setDeviceProfile:(NSString *)deviceProfile {
    _deviceProfile = [deviceProfile copy];
    [self addSetRequest:keyPath(self, deviceProfile) object:_deviceProfile];
}

- (void)setApnsTopic:(NSString *)apnsTopic {
    _apnsTopic = [apnsTopic copy];
    [self addSetRequest:keyPath(self, apnsTopic) object:_apnsTopic];
}

- (void)setApnsTeamId:(NSString *)apnsTeamId {
    _apnsTeamId = [apnsTeamId copy];
    [self addSetRequest:keyPath(self, apnsTeamId) object:_apnsTeamId];
}

- (void)setTimeZone:(NSString *)timeZone {
    _timeZone = [timeZone copy];
    [self addSetRequest:keyPath(self, timeZone) object:_timeZone];
}

- (void)setDeviceType:(NSString *)deviceType {
    _deviceType = [deviceType copy];
    [self addSetRequest:keyPath(self, deviceType) object:_deviceType];
}

- (void)setInstallationId:(NSString *)installationId {
    _installationId = [installationId copy];
    [self addSetRequest:keyPath(self, installationId) object:_installationId];
}

- (void)updateChannels:(NSArray *)channels {
    _channels = channels;
}

@end
