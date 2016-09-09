//
//  AVFileBreakpoint.m
//  AVOS
//
//  Created by Tang Tianyong on 8/26/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import "AVFileBreakpoint.h"

@implementation AVFileBreakpoint

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];

    if (self) {
        _size     = (uint64_t)[aDecoder decodeInt64ForKey:@"size"];
        _offset   = (uint64_t)[aDecoder decodeInt64ForKey:@"offset"];
        _checksum = [aDecoder decodeObjectForKey:@"checksum"];
        _contexts = [aDecoder decodeObjectForKey:@"contexts"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt64:(int64_t)_size   forKey:@"size"];
    [aCoder encodeInt64:(int64_t)_offset forKey:@"offset"];
    [aCoder encodeObject:_checksum       forKey:@"checksum"];
    [aCoder encodeObject:_contexts       forKey:@"contexts"];
}

- (NSString *)provider {
    return self.info[@"provider"];
}

@end
