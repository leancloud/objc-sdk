// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// https://developers.google.com/protocol-buffers/
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <Foundation/Foundation.h>

#import "LCGPBDictionary.h"

@class LCGPBCodedInputStream;
@class LCGPBCodedOutputStream;
@class LCGPBExtensionRegistry;
@class LCGPBFieldDescriptor;

@protocol LCGPBDictionaryInternalsProtocol
- (size_t)computeSerializedSizeAsField:(LCGPBFieldDescriptor *)field;
- (void)writeToCodedOutputStream:(LCGPBCodedOutputStream *)outputStream
                         asField:(LCGPBFieldDescriptor *)field;
- (void)setLCGPBGenericValue:(LCGPBGenericValue *)value
     forLCGPBGenericValueKey:(LCGPBGenericValue *)key;
- (void)enumerateForTextFormat:(void (^)(id keyObj, id valueObj))block;
@end

//%PDDM-DEFINE DICTIONARY_PRIV_INTERFACES_FOR_POD_KEY(KEY_NAME)
//%DICTIONARY_POD_PRIV_INTERFACES_FOR_KEY(KEY_NAME)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, Object, Object)
//%PDDM-DEFINE DICTIONARY_POD_PRIV_INTERFACES_FOR_KEY(KEY_NAME)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, UInt32, Basic)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, Int32, Basic)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, UInt64, Basic)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, Int64, Basic)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, Bool, Basic)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, Float, Basic)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, Double, Basic)
//%DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, Enum, Enum)

//%PDDM-DEFINE DICTIONARY_PRIVATE_INTERFACES(KEY_NAME, VALUE_NAME, HELPER)
//%@interface LCGPB##KEY_NAME##VALUE_NAME##Dictionary () <LCGPBDictionaryInternalsProtocol> {
//% @package
//%  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
//%}
//%EXTRA_DICTIONARY_PRIVATE_INTERFACES_##HELPER()@end
//%

//%PDDM-DEFINE EXTRA_DICTIONARY_PRIVATE_INTERFACES_Basic()
// Empty
//%PDDM-DEFINE EXTRA_DICTIONARY_PRIVATE_INTERFACES_Object()
//%- (BOOL)isInitialized;
//%- (instancetype)deepCopyWithZone:(NSZone *)zone
//%    __attribute__((ns_returns_retained));
//%
//%PDDM-DEFINE EXTRA_DICTIONARY_PRIVATE_INTERFACES_Enum()
//%- (NSData *)serializedDataForUnknownValue:(int32_t)value
//%                                   forKey:(LCGPBGenericValue *)key
//%                              keyDataType:(LCGPBDataType)keyDataType;
//%

//%PDDM-EXPAND DICTIONARY_PRIV_INTERFACES_FOR_POD_KEY(UInt32)
// This block of code is generated, do not edit it directly.

@interface LCGPBUInt32UInt32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt32Int32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt32UInt64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt32Int64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt32BoolDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt32FloatDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt32DoubleDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt32EnumDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (NSData *)serializedDataForUnknownValue:(int32_t)value
                                   forKey:(LCGPBGenericValue *)key
                              keyDataType:(LCGPBDataType)keyDataType;
@end

@interface LCGPBUInt32ObjectDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (BOOL)isInitialized;
- (instancetype)deepCopyWithZone:(NSZone *)zone
    __attribute__((ns_returns_retained));
@end

//%PDDM-EXPAND DICTIONARY_PRIV_INTERFACES_FOR_POD_KEY(Int32)
// This block of code is generated, do not edit it directly.

@interface LCGPBInt32UInt32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt32Int32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt32UInt64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt32Int64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt32BoolDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt32FloatDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt32DoubleDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt32EnumDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (NSData *)serializedDataForUnknownValue:(int32_t)value
                                   forKey:(LCGPBGenericValue *)key
                              keyDataType:(LCGPBDataType)keyDataType;
@end

@interface LCGPBInt32ObjectDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (BOOL)isInitialized;
- (instancetype)deepCopyWithZone:(NSZone *)zone
    __attribute__((ns_returns_retained));
@end

//%PDDM-EXPAND DICTIONARY_PRIV_INTERFACES_FOR_POD_KEY(UInt64)
// This block of code is generated, do not edit it directly.

@interface LCGPBUInt64UInt32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt64Int32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt64UInt64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt64Int64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt64BoolDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt64FloatDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt64DoubleDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBUInt64EnumDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (NSData *)serializedDataForUnknownValue:(int32_t)value
                                   forKey:(LCGPBGenericValue *)key
                              keyDataType:(LCGPBDataType)keyDataType;
@end

@interface LCGPBUInt64ObjectDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (BOOL)isInitialized;
- (instancetype)deepCopyWithZone:(NSZone *)zone
    __attribute__((ns_returns_retained));
@end

//%PDDM-EXPAND DICTIONARY_PRIV_INTERFACES_FOR_POD_KEY(Int64)
// This block of code is generated, do not edit it directly.

@interface LCGPBInt64UInt32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt64Int32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt64UInt64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt64Int64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt64BoolDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt64FloatDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt64DoubleDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBInt64EnumDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (NSData *)serializedDataForUnknownValue:(int32_t)value
                                   forKey:(LCGPBGenericValue *)key
                              keyDataType:(LCGPBDataType)keyDataType;
@end

@interface LCGPBInt64ObjectDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (BOOL)isInitialized;
- (instancetype)deepCopyWithZone:(NSZone *)zone
    __attribute__((ns_returns_retained));
@end

//%PDDM-EXPAND DICTIONARY_PRIV_INTERFACES_FOR_POD_KEY(Bool)
// This block of code is generated, do not edit it directly.

@interface LCGPBBoolUInt32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBBoolInt32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBBoolUInt64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBBoolInt64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBBoolBoolDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBBoolFloatDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBBoolDoubleDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBBoolEnumDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (NSData *)serializedDataForUnknownValue:(int32_t)value
                                   forKey:(LCGPBGenericValue *)key
                              keyDataType:(LCGPBDataType)keyDataType;
@end

@interface LCGPBBoolObjectDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (BOOL)isInitialized;
- (instancetype)deepCopyWithZone:(NSZone *)zone
    __attribute__((ns_returns_retained));
@end

//%PDDM-EXPAND DICTIONARY_POD_PRIV_INTERFACES_FOR_KEY(String)
// This block of code is generated, do not edit it directly.

@interface LCGPBStringUInt32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBStringInt32Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBStringUInt64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBStringInt64Dictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBStringBoolDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBStringFloatDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBStringDoubleDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

@interface LCGPBStringEnumDictionary () <LCGPBDictionaryInternalsProtocol> {
 @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
- (NSData *)serializedDataForUnknownValue:(int32_t)value
                                   forKey:(LCGPBGenericValue *)key
                              keyDataType:(LCGPBDataType)keyDataType;
@end

//%PDDM-EXPAND-END (6 expansions)

#pragma mark - NSDictionary Subclass

@interface LCGPBAutocreatedDictionary : NSMutableDictionary {
  @package
  LCGPB_UNSAFE_UNRETAINED LCGPBMessage *_autocreator;
}
@end

#pragma mark - Helpers

CF_EXTERN_C_BEGIN

// Helper to compute size when an NSDictionary is used for the map instead
// of a custom type.
size_t LCGPBDictionaryComputeSizeInternalHelper(NSDictionary *dict,
                                              LCGPBFieldDescriptor *field);

// Helper to write out when an NSDictionary is used for the map instead
// of a custom type.
void LCGPBDictionaryWriteToStreamInternalHelper(
    LCGPBCodedOutputStream *outputStream, NSDictionary *dict,
    LCGPBFieldDescriptor *field);

// Helper to check message initialization when an NSDictionary is used for
// the map instead of a custom type.
BOOL LCGPBDictionaryIsInitializedInternalHelper(NSDictionary *dict,
                                              LCGPBFieldDescriptor *field);

// Helper to read a map instead.
void LCGPBDictionaryReadEntry(id mapDictionary, LCGPBCodedInputStream *stream,
                            LCGPBExtensionRegistry *registry,
                            LCGPBFieldDescriptor *field,
                            LCGPBMessage *parentMessage);

CF_EXTERN_C_END
