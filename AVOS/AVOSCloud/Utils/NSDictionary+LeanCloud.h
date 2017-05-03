//
//  NSDictionary+LeanCloud.h
//  AVOS
//
//  Created by Tang Tianyong on 03/05/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (LeanCloud)

- (instancetype)lc_selectEntriesWithKeyMappings:(NSDictionary *)keyMappings;

@end
