//
//  LCInstallation_Internal.h
//  LeanCloud
//
//  Created by Zhu Zeng on 3/27/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "LCInstallation.h"

@interface LCInstallation ()

+ (NSString *)className;
+ (NSString *)endPoint;

- (void)updateChannels:(NSArray *)channels;

@end
