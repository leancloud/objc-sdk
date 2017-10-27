//
//  AVUser+Social.m
//  AVOSCloud-iOS
//
//  Created by ZapCannon87 on 23/10/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVUser+Social.h"
#import "AVUser_Internal.h"
#import "AVUtils.h"
#import "AVErrorUtils.h"
#import "AVObjectUtils.h"
#import "AVObject_Internal.h"
#import "AVPaasClient.h"

NSString *const LeanCloudSocialPlatformWeiBo  = @"weibo";
NSString *const LeanCloudSocialPlatformQQ     = @"qq";
NSString *const LeanCloudSocialPlatformWeiXin = @"weixin";

NSString *const LeanCloudSocialErrorDomain = @"LeanCloudSocialErrorDomain";

NSString *const UserAuthDataKey = @"authData";

@implementation AVUser (Social)

#pragma mark - public

+ (void)loginOrSignUpWithAuthData:(NSDictionary *)authData
                         platform:(NSString *)platform
                            block:(AVUserResultBlock)block
{
    [self loginOrSignUpWithAuthData:authData
                               user:nil
                           platform:platform
                              block:block];
}

+ (void)loginOrSignUpWithAuthData:(NSDictionary *)authData
                             user:(AVUser *)user
                         platform:(NSString *)platform
                            block:(AVUserResultBlock)block
{
    /* check `authData` */
    
    NSError *ckErr = nil;
    
    [self checkingAuthData:authData
                  platform:platform
                     error:&ckErr];
    
    if (ckErr) {
        
        [AVUtils callUserResultBlock:block
                                user:nil
                               error:ckErr];
        
        return;
    }
    
    /* POST */
    
    AVIdResultBlock callback = ^(id object, NSError *cbErr) {
        
        if (cbErr) {
            
            [AVUtils callUserResultBlock:block
                                    user:nil
                                   error:cbErr];
            
            return;
            
        } else {
            
            NSDictionary *dic = (NSDictionary *)object;
            
            AVUser *aUser = nil;
            
            if (user) {
                
                aUser = user;
                
            } else {
                
                aUser = [self userOrSubclassUser];
                
            }
            
            if (dic[UserAuthDataKey] == nil) {
                
                [aUser setNewFlag:true]; // unnecessary?
                
                [aUser setObject:authData[UserAuthDataKey]
                          forKey:UserAuthDataKey];
                
            }
            
            [self configAndChangeCurrentUserWithUser:aUser
                                              object:dic];
            
            [AVUtils callUserResultBlock:block
                                    user:aUser
                                   error:nil];
            
            return;
        }
        
    };
    
    [AVPaasClient.sharedInstance postObject:@"users"
                             withParameters:authData
                                      block:callback];
}

- (void)associateWithAuthData:(NSDictionary *)authData
                     platform:(NSString *)platform
                        block:(AVUserResultBlock)block
{
    if (self.objectId && self.sessionToken) { /* check the user if registered */
        
        /* check `authData` */
        
        NSError *ckErr = nil;
        
        [self.class checkingAuthData:authData
                            platform:platform
                               error:&ckErr];
        
        if (ckErr) {
            
            [AVUtils callUserResultBlock:block
                                    user:nil
                                   error:ckErr];
            
            return;
        }
        
        /* POST */
        
        AVIdResultBlock callback = ^(id object, NSError *cbErr) {
            
            if (cbErr) {
                
                [AVUtils callUserResultBlock:block
                                        user:nil
                                       error:cbErr];
                
                return;
                
            } else {
                
                [self setObject:authData[UserAuthDataKey]
                         forKey:UserAuthDataKey];
                
                [self.class configAndChangeCurrentUserWithUser:self
                                                        object:@{}];
                
                [AVUtils callUserResultBlock:block
                                        user:self
                                       error:nil];
                
                return;
            }
            
        };
        
        NSString *path = [NSString stringWithFormat:@"users/%@", self.objectId];
        
        [AVPaasClient.sharedInstance putObject:path
                                withParameters:authData
                                  sessionToken:self.sessionToken
                                         block:callback];
        
    } else {
        
        /* register the user */
        
        [self.class loginOrSignUpWithAuthData:authData
                                         user:self
                                     platform:platform
                                        block:block];
        
    }
}

- (void)disassociateWithPlatform:(NSString *)platform
                           block:(AVUserResultBlock)block
{
    if (self.objectId && self.sessionToken) { /* check the user if registered */
        
        /* generate `authData` */
        
        NSMutableDictionary *platformDic = @{ platform : @"" }.mutableCopy;
        
        platformDic[platform] = nil;
        
        NSDictionary *authData = @{ UserAuthDataKey : platformDic };
        
        /* POST */
        
        AVIdResultBlock callback = ^(id object, NSError *cbErr) {
            
            if (cbErr) {
                
                [AVUtils callUserResultBlock:block
                                        user:nil
                                       error:cbErr];
                
                return;
                
            } else {
                
                NSMutableDictionary *authDataValue = ((NSDictionary *)[self objectForKey:UserAuthDataKey]).mutableCopy;
                
                authDataValue[platform] = nil;
                
                [self setObject:authDataValue forKey:UserAuthDataKey];
                
                [self.class configAndChangeCurrentUserWithUser:self
                                                        object:@{}];
                
                [AVUtils callUserResultBlock:block
                                        user:self
                                       error:nil];
                
                return;
            }
            
        };
        
        NSString *path = [NSString stringWithFormat:@"users/%@", self.objectId];
        
        [AVPaasClient.sharedInstance putObject:path
                                withParameters:authData
                                  sessionToken:self.sessionToken
                                         block:callback];
        
    } else {
        
        NSString *reason = @"The user which call the method is not registered.";
        
        NSDictionary *info = @{ @"reason" : reason };
        
        NSError *fkErr = [NSError errorWithDomain:LeanCloudSocialErrorDomain
                                             code:0
                                         userInfo:info];
        
        [AVUtils callUserResultBlock:block
                                user:nil
                               error:fkErr];
    }
}

#pragma mark - internal

+ (void)checkingAuthData:(NSDictionary *)authData
                platform:(NSString *)platform
                   error:(NSError * __autoreleasing *)error
{
    /* do not call me baby! */
    
    NSError *(^fuckingErr)(NSString *) = ^NSError *(NSString *key) {
        
        NSString *reason = [NSString stringWithFormat:@"The value for key('%@') is not a valid type", key];
        
        NSDictionary *info = @{ @"reason" : reason };
        
        NSError *err = [NSError errorWithDomain:LeanCloudSocialErrorDomain
                                           code:0
                                       userInfo:info];
        
        return err;
    };
    
    /* check value for key('authData') */
    
    NSDictionary *authDataValue = authData[UserAuthDataKey];
    
    if ([NSDictionary lc_isInvalidForCheckingTypeWith:authDataValue]) {
        
        *error = fuckingErr(UserAuthDataKey);
        
        return;
    }
    
    /* check value for key('platform') */
    
    NSDictionary *platformValue = authDataValue[platform];
    
    if ([NSDictionary lc_isInvalidForCheckingTypeWith:platformValue]) {
        
        *error = fuckingErr(platform);
        
        return;
    }
    
    /* check value for key('unique id') */
    
    NSString *just_id_key = nil;
    
    if ([LeanCloudSocialPlatformWeiBo isEqualToString:platform]) {
        
        just_id_key = @"uid";
        
    } else if ([LeanCloudSocialPlatformQQ isEqualToString:platform]) {
        
        just_id_key = @"openid";
        
    } else if ([LeanCloudSocialPlatformWeiXin isEqualToString:platform]) {
        
        just_id_key = @"openid";
        
    } else {
        
        just_id_key = @"uid";
        
    }
    
    NSString *just_id = platformValue[just_id_key];
    
    if ([NSString lc_isInvalidForCheckingTypeWith:just_id]) {
        
        *error = fuckingErr(just_id_key);
        
        return;
    }
    
    /* check value for key('accessToken') */
    
    NSString *access_token = platformValue[@"access_token"];
    
    if ([NSString lc_isInvalidForCheckingTypeWith:access_token]) {
        
        *error = fuckingErr(@"access_token");
        
        return;
    }
}

@end
