//
//  AVFileSaveOption.h
//  AVOS
//
//  Created by Tang Tianyong on 8/29/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVFileBreakpoint.h"

@interface AVFileSaveOption : NSObject

@property (nonatomic, strong) AVFileBreakpoint *breakpoint;
@property (nonatomic,   copy) void(^breakpointDidUpdateBlock)(AVFileBreakpoint *breakpoint);
@property (nonatomic,   copy) BOOL(^cancellationBlock)(void);

@end
