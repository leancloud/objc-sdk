//
//  AVApplication+Internal.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVApplication.h"

@interface AVApplicationIdentity ()

@property (nonatomic, copy) NSString *environment;

@end

@interface AVApplication (Internal)

- (NSString *)relativePath;

@end
