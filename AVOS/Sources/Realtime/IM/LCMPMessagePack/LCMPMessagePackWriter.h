//
//  LCMPMessagePackWriter.h
//  LCMPMessagePack
//
//  Created by Gabriel on 7/3/14.
//  Copyright (c) 2014 Gabriel Handford. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LCMPMessagePackWriterOptions) {
  LCMPMessagePackWriterOptionsSortDictionaryKeys = 1 << 0,
};

@interface LCMPMessagePackWriter : NSObject

- (NSMutableData *)writeObject:(id)obj options:(LCMPMessagePackWriterOptions)options error:(NSError * __autoreleasing *)error;

+ (NSMutableData *)writeObject:(id)obj error:(NSError * __autoreleasing *)error;

+ (NSMutableData *)writeObject:(id)obj options:(LCMPMessagePackWriterOptions)options error:(NSError * __autoreleasing *)error;

@end
