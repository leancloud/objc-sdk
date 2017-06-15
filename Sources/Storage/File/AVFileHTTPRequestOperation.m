//
//  AVFileHTTPRequestOperation.m
//  paas
//
//  Created by Summer on 13-5-27.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import "AVFileHTTPRequestOperation.h"

@implementation AVFileHTTPRequestOperation

+ (BOOL)canProcessRequest:(NSURLRequest *)request {
    return YES;
}

- (BOOL)hasAcceptableContentType {
    return YES;
}

@end
