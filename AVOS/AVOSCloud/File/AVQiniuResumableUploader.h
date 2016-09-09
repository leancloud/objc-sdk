//
//  AVQiniuResumableUploader.h
//  AVOS
//
//  Created by Tang Tianyong on 8/26/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AVFile.h"
#import "AVFileBreakpoint.h"

typedef void(^AVFileBreakpointBlock)(AVFileBreakpoint *);
typedef BOOL(^AVFileCancellationBlock)(void);

@interface AVQiniuResumableUploader : NSObject

- (instancetype)initWithFile:(AVFile *)file
                        info:(NSDictionary *)info
                         key:(NSString *)key
                       token:(NSString *)token
                        host:(NSString *)host
                  breakpoint:(AVFileBreakpoint *)breakpoint
         breakpointDidUpdate:(AVFileBreakpointBlock)breakpointDidUpdateBlock
                    progress:(AVProgressBlock)progressBlock
                cancellation:(AVFileCancellationBlock)cancellationBlock
                  completion:(AVBooleanResultBlock)completionBlock;

- (void)upload;

@end
