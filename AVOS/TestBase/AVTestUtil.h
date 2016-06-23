//
//  AVTestUtil.h
//  AVOS
//
//  Created by Qihe Bian on 1/27/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AVTestUtil : NSObject
+ (void)registerUserWithName:(NSString *)name;
+ (void)loginUserWithName:(NSString *)name;
+ (void)logoutUser;
@end
