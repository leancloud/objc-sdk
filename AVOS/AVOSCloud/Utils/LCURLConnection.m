//
//  LCURLConnection.m
//  AVOS
//
//  Created by Tang Tianyong on 12/10/15.
//  Copyright © 2015 LeanCloud Inc. All rights reserved.
//

#import "LCURLConnection.h"

@implementation LCURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request
                 returningResponse:(NSURLResponse *__autoreleasing *)response
                             error:(NSError *__autoreleasing *)error
{
    if (@available(iOS 7.0, macOS 10.9, tvOS 9.0, watchOS 2.0, *)) {
        __block NSData *data = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *taskData, NSURLResponse *taskResponse, NSError *taskError) {
            data = taskData;

            if (response)
                *response = taskResponse;

            if (error)
                *error = taskError;

            dispatch_semaphore_signal(semaphore);
        }] resume];

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        return data;
    } else {
#if TARGET_OS_WATCH
        return nil;
#else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [NSURLConnection sendSynchronousRequest:request returningResponse:response error:error];
#pragma clang diagnostic pop
#endif
    }
}

@end
