//
//  LCMPMessagePackReader.h
//  LCMPMessagePack
//
//  Created by Gabriel on 7/3/14.
//  Copyright (c) 2014 Gabriel Handford. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LCMPMessagePackReaderOptions) {
  LCMPMessagePackReaderOptionsUseOrderedDictionary = 1 << 0,
};


@interface LCMPMessagePackReader : NSObject

@property (readonly) size_t index;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithData:(NSData *)data options:(LCMPMessagePackReaderOptions)options;

- (id)readObject:(NSError * __autoreleasing *)error;

+ (id)readData:(NSData *)data error:(NSError * __autoreleasing *)error;

+ (id)readData:(NSData *)data options:(LCMPMessagePackReaderOptions)options error:(NSError * __autoreleasing *)error;

@end
