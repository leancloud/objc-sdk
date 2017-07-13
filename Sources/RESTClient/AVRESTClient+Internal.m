//
//  AVRESTClient+Internal.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/07/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVRESTClient+Internal.h"

@implementation AVRESTClient (Internal)

- (void)getRTMServerTableWithBlock:(void (^)(NSDictionary *RTMServerTable, NSError *error))block {
    [self.router getRTMServerTableWithBlock:block];
}

@end
