//
//  AVFileAccessor.h
//  AVOS
//
//  Created by Tang Tianyong on 8/27/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AVFileAccessor : NSObject

- (instancetype)initWithPath:(NSString *)path;

- (NSData *)dataForOffset:(uint64_t)offset size:(uint64_t)size;

@end
