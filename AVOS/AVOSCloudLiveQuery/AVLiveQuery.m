//
//  AVLiveQuery.m
//  AVOS
//
//  Created by Tang Tianyong on 15/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVLiveQuery.h"
#import "AVSubscriber.h"

#import "AVUser.h"
#import "AVQuery.h"
#import "AVQuery_Internal.h"
#import "AVPaasClient.h"
#import "AVUtils.h"

static NSString *const AVSubscriptionEndpoint = @"LiveQuery/subscribe";
static NSString *const AVUnsubscriptionEndpoint = @"LiveQuery/unsubscribe";

@interface AVLiveQuery ()

@property (nonatomic, copy) NSString *queryId;
@property (nonatomic, weak) AVSubscriber *subscriber;

@end

@implementation AVLiveQuery

- (instancetype)initWithQuery:(AVQuery *)query {
    self = [super init];

    if (self) {
        _query = query;
        _subscriber = [AVSubscriber sharedInstance];
    }

    return self;
}

- (NSDictionary *)subscriptionParameters {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    query[@"className"] = self.query.className;
    query[@"where"]     = [self.query whereJSONDictionary];
    query[@"keys"]      = self.query.selectedKeys;

    parameters[@"query"] = query;
    parameters[@"sessionToken"] = [AVUser currentUser].sessionToken;
    parameters[@"id"] = self.subscriber.identifier;

    return parameters;
}

- (void)subscribeWithCallback:(void (^)(BOOL, NSError *))callback {
    [[AVSubscriber sharedInstance] start];

    NSDictionary *parameters = [self subscriptionParameters];

    AVIdResultBlock block = ^(id object, NSError *error) {
        if (error) {
            [AVUtils callBooleanResultBlock:callback error:error];
            return;
        }

        self.queryId = object[@"query_id"];
        [AVUtils callBooleanResultBlock:callback error:nil];
    };

    [[AVPaasClient sharedInstance] postObject:AVSubscriptionEndpoint
                               withParameters:parameters
                                        block:block];
}

- (NSDictionary *)unsubscriptionParameters {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    parameters[@"id"] = self.subscriber.identifier;
    parameters[@"query_id"] = self.queryId;

    return parameters;
}

- (void)unsubscribeWithCallback:(AVBooleanResultBlock)callback {
    NSDictionary *parameters = [self unsubscriptionParameters];

    AVIdResultBlock block = ^(id object, NSError *error) {
        if (error) {
            [AVUtils callBooleanResultBlock:callback error:error];
            return;
        }

        self.queryId = nil;
        [AVUtils callBooleanResultBlock:callback error:nil];
    };

    [[AVPaasClient sharedInstance] postObject:AVUnsubscriptionEndpoint
                               withParameters:parameters
                                        block:block];
}

@end
