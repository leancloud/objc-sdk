//
//  AVApplication+RESTClient.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 20/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <AVOSCloudFoundation/AVOSCloudFoundation.h>

@interface AVApplication (RESTClient)

@property (nonatomic, readonly, strong) NSDictionary *authorizationHTTPHeaders;

@end
