//
//  AVInstallation_Internal.h
//  LeanCloud
//
//  Created by Zhu Zeng on 3/27/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "AVInstallation.h"

@interface AVInstallation ()

+ (NSString *)className;
+ (NSString *)endPoint;

- (void)updateChannels:(NSArray *)channels;

@end
