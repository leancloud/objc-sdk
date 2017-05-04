//
//  NSDictionary+LeanCloud.m
//  AVOS
//
//  Created by Tang Tianyong on 03/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "NSDictionary+LeanCloud.h"

@implementation NSDictionary (LeanCloud)

- (instancetype)lc_selectEntriesWithKeyMappings:(NSDictionary *)keyMappings {
    NSMutableDictionary *selected = [NSMutableDictionary dictionary];

    for (id sourceKey in keyMappings)
        selected[keyMappings[sourceKey]] = self[sourceKey];

    return selected;
}

@end
