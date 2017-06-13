//
//  AVSDK.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 13/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AVSDK : NSObject

@property (nonatomic, readonly, strong) NSString *version;

+ (instancetype)sharedInstance;

@end
