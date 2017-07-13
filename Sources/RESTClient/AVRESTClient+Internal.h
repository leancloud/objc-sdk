//
//  AVRESTClient+Internal.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVRESTClient.h"
#import "LCRouter.h"

@interface AVRESTClient ()

@property (nonatomic, strong) LCRouter *router;

@end

@interface AVRESTClient (Internal)

- (void)getRTMServerTableWithBlock:(void(^)(NSDictionary *RTMServerTable, NSError *error))block;

@end
