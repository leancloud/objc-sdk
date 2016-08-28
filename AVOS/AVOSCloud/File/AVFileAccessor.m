//
//  AVFileAccessor.m
//  AVOS
//
//  Created by Tang Tianyong on 8/27/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import "AVFileAccessor.h"

@interface AVFileAccessor ()

@property (nonatomic,   copy) NSString     *path;
@property (nonatomic, assign) uint64_t      size;
@property (nonatomic, strong) NSData       *data;
@property (nonatomic, strong) NSFileHandle *fileHandler;

@end

@implementation AVFileAccessor

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];

    if (self) {
        _path = [path copy];
        _size = [[[NSFileManager defaultManager] attributesOfItemAtPath:_path error:NULL] fileSize];

        // https://issues.apache.org/jira/browse/CB-5790
        if (_size > 16 * 1024 * 1024) {
            _fileHandler = [NSFileHandle fileHandleForReadingAtPath:path];
        } else {
            _data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
        }
    }

    return self;
}

- (NSData *)dataForOffset:(uint64_t)offset size:(uint64_t)size {
    if (_data != nil) {
        return [_data subdataWithRange:NSMakeRange(offset, (unsigned int)size)];
    } else {
        [_fileHandler seekToFileOffset:offset];
        return [_fileHandler readDataOfLength:size];
    }
}

@end
