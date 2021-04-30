//
//  AVAnonymousUtils.h
//  AVOSCloud
//
//

#import <Foundation/Foundation.h>
#import "LCUser.h"
#import "LCConstants.h"
#import "AVAnonymousUtils.h"
#import "LCUtils.h"
#import "LCObjectUtils.h"
#import "LCPaasClient.h"
#import "LCUser.h"
#import "LCUser_Internal.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation AVAnonymousUtils

+(NSDictionary *)anonymousAuthData
{
    NSString *anonymousId = [[NSUserDefaults standardUserDefaults] objectForKey:AnonymousIdKey];
    if (!anonymousId) {
        anonymousId = [LCUtils generateCompactUUID];
        [[NSUserDefaults standardUserDefaults] setObject:anonymousId forKey:AnonymousIdKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    NSDictionary * data = @{authDataTag: @{@"anonymous": @{@"id": anonymousId}}};
    return data;
}

+ (void)logInWithBlock:(LCUserResultBlock)block
{
    NSDictionary * parameters = [AVAnonymousUtils anonymousAuthData];
    [[LCPaasClient sharedInstance] postObject:@"users" withParameters:parameters block:^(id object, NSError *error) {
        LCUser * user = nil;
        if (error == nil)
        {
            if (![object objectForKey:@"authData"]) {
                object = [NSMutableDictionary dictionaryWithDictionary:object];
                [object addEntriesFromDictionary:parameters];
            }
            user = [LCUser userOrSubclassUser];
            [LCObjectUtils copyDictionary:object toObject:user];
            [LCUser changeCurrentUser:user save:YES];
        }
        [LCUtils callUserResultBlock:block user:user error:error];
    }];
}

+ (BOOL)isLinkedWithUser:(LCUser *)user
{
    if ([[user linkedServiceNames] containsObject:@"anonymous"])
    {
        return YES;
    }
    return NO;
}

@end
#pragma clang diagnostic pop
