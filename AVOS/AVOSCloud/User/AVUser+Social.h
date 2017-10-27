//
//  AVUser+Social.h
//  AVOSCloud-iOS
//
//  Created by ZapCannon87 on 23/10/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVUser.h"

extern NSString *const LeanCloudSocialPlatformWeiBo;
extern NSString *const LeanCloudSocialPlatformQQ;
extern NSString *const LeanCloudSocialPlatformWeiXin;

@interface AVUser (Social)

+ (void)loginOrSignUpWithAuthData:(NSDictionary *)authData
                         platform:(NSString *)platform
                            block:(AVUserResultBlock)block;

+ (void)loginOrSignUpWithAuthData:(NSDictionary *)authData
                             user:(AVUser *)user
                         platform:(NSString *)platform
                            block:(AVUserResultBlock)block;

- (void)associateWithAuthData:(NSDictionary *)authData
                     platform:(NSString *)platform
                        block:(AVUserResultBlock)block;

- (void)disassociateWithPlatform:(NSString *)platform
                           block:(AVUserResultBlock)block;

@end
