//
//  AVDynamicObject_Internal.h
//  AVOS
//
//  Created by Tang Tianyong on 03/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVDynamicObject.h"

@interface AVDynamicObject ()

@property (nonatomic, strong, readonly) NSDictionary *properties;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end
