//
//  AVApplication.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 18/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AVApplication : NSObject

@property (nonatomic, readonly, strong) NSString *ID;
@property (nonatomic, readonly, strong) NSString *key;

- (instancetype)initWithID:(NSString *)ID key:(NSString *)key;

@end
