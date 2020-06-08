//
//  AVIMTypedMessage.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/8/15.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMMessage.h"

@class AVFile;
@class AVGeoPoint;

NS_ASSUME_NONNULL_BEGIN

@protocol AVIMTypedMessageSubclassing <NSObject>

@required

/// The type of the typed message,
/// The zero and negative number is reserved for default typed message,
/// Any other typed message should use positive number.
+ (AVIMMessageMediaType)classMediaType;

@end

/**
 * Base class for rich media message.
 */
@interface AVIMTypedMessage : AVIMMessage

/// The string text.
@property (nonatomic, nullable) NSString *text;

/// The custom attributes.
@property (nonatomic, nullable) NSDictionary *attributes;

/// The file.
@property (nonatomic, nullable) AVFile *file;

/// The location.
@property (nonatomic, nullable) AVGeoPoint *location;

/**
 * Add custom property for message.
 *
 * @param object The property value.
 * @param key    The property name.
 */
- (void)setObject:(id _Nullable)object forKey:(NSString *)key;

/**
 Get a user-defiend property for a key.

 @param key The key of property that you want to get.
 @return The value for key.
 */
- (id _Nullable)objectForKey:(NSString *)key;

/// Any custom typed message should be registered at first.
+ (void)registerSubclass;

/// Create a message with file from local path.
/// @param text The string text.
/// @param attachedFilePath The local path of the file.
/// @param attributes The custom attributes.
+ (instancetype)messageWithText:(NSString * _Nullable)text
               attachedFilePath:(NSString *)attachedFilePath
                     attributes:(NSDictionary * _Nullable)attributes;

/// Create a message with text, file and attributes.
/// @param text The string text.
/// @param file The file object.
/// @param attributes The custom attributes.
+ (instancetype)messageWithText:(NSString * _Nullable)text
                           file:(AVFile *)file
                     attributes:(NSDictionary * _Nullable)attributes;

@end

NS_ASSUME_NONNULL_END
