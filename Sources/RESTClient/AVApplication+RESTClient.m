//
//  AVApplication+RESTClient.m
//  AVOSCloud
//
//  Created by Tang Tianyong on 20/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVApplication+RESTClient.h"
#import "AVRESTClient.h"

@implementation AVApplication (RESTClient)

- (NSString *)authorizationSignature {
    NSString *timestamp = [NSString stringWithFormat:@"%.0f", 1000 * [[NSDate date] timeIntervalSince1970]];
    NSString *signature = [[LCUtility MD5ForString:[NSString stringWithFormat:@"%@%@", timestamp, self.identity.key]] lowercaseString];
    NSString *headerValue = [NSString stringWithFormat:@"%@,%@", signature, timestamp];

    return headerValue;
}

- (NSDictionary *)authorizationHTTPHeaders {
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];

    headers[AVHTTPHeaderFieldNameId]        = self.identity.ID;
    headers[AVHTTPHeaderFieldNameSignature] = [self authorizationSignature];

    return headers;
}

@end
