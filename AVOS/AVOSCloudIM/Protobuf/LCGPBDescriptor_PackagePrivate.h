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

// This header is private to the ProtobolBuffers library and must NOT be
// included by any sources outside this library. The contents of this file are
// subject to change at any time without notice.

#import "LCGPBDescriptor.h"
#import "LCGPBWireFormat.h"

// Describes attributes of the field.
typedef NS_OPTIONS(uint16_t, LCGPBFieldFlags) {
  LCGPBFieldNone            = 0,
  // These map to standard protobuf concepts.
  LCGPBFieldRequired        = 1 << 0,
  LCGPBFieldRepeated        = 1 << 1,
  LCGPBFieldPacked          = 1 << 2,
  LCGPBFieldOptional        = 1 << 3,
  LCGPBFieldHasDefaultValue = 1 << 4,

  // Indicates the field needs custom handling for the TextFormat name, if not
  // set, the name can be derived from the ObjC name.
  LCGPBFieldTextFormatNameCustom = 1 << 6,
  // Indicates the field has an enum descriptor.
  LCGPBFieldHasEnumDescriptor = 1 << 7,

  // These are not standard protobuf concepts, they are specific to the
  // Objective C runtime.

  // These bits are used to mark the field as a map and what the key
  // type is.
  LCGPBFieldMapKeyMask     = 0xF << 8,
  LCGPBFieldMapKeyInt32    =  1 << 8,
  LCGPBFieldMapKeyInt64    =  2 << 8,
  LCGPBFieldMapKeyUInt32   =  3 << 8,
  LCGPBFieldMapKeyUInt64   =  4 << 8,
  LCGPBFieldMapKeySInt32   =  5 << 8,
  LCGPBFieldMapKeySInt64   =  6 << 8,
  LCGPBFieldMapKeyFixed32  =  7 << 8,
  LCGPBFieldMapKeyFixed64  =  8 << 8,
  LCGPBFieldMapKeySFixed32 =  9 << 8,
  LCGPBFieldMapKeySFixed64 = 10 << 8,
  LCGPBFieldMapKeyBool     = 11 << 8,
  LCGPBFieldMapKeyString   = 12 << 8,
};

// NOTE: The structures defined here have their members ordered to minimize
// their size. This directly impacts the size of apps since these exist per
// field/extension.

// Describes a single field in a protobuf as it is represented as an ivar.
typedef struct LCGPBMessageFieldDescription {
  // Name of ivar.
  const char *name;
  union {
    const char *className;  // Name for message class.
    // For enums only: If EnumDescriptors are compiled in, it will be that,
    // otherwise it will be the verifier.
    LCGPBEnumDescriptorFunc enumDescFunc;
    LCGPBEnumValidationFunc enumVerifier;
  } dataTypeSpecific;
  // The field number for the ivar.
  uint32_t number;
  // The index (in bits) into _has_storage_.
  //   >= 0: the bit to use for a value being set.
  //   = LCGPBNoHasBit(INT32_MAX): no storage used.
  //   < 0: in a oneOf, use a full int32 to record the field active.
  int32_t hasIndex;
  // Offset of the variable into it's structure struct.
  uint32_t offset;
  // Field flags. Use accessor functions below.
  LCGPBFieldFlags flags;
  // Data type of the ivar.
  LCGPBDataType dataType;
} LCGPBMessageFieldDescription;

// Fields in messages defined in a 'proto2' syntax file can provide a default
// value. This struct provides the default along with the field info.
typedef struct LCGPBMessageFieldDescriptionWithDefault {
  // Default value for the ivar.
  LCGPBGenericValue defaultValue;

  LCGPBMessageFieldDescription core;
} LCGPBMessageFieldDescriptionWithDefault;

// Describes attributes of the extension.
typedef NS_OPTIONS(uint8_t, LCGPBExtensionOptions) {
  LCGPBExtensionNone          = 0,
  // These map to standard protobuf concepts.
  LCGPBExtensionRepeated      = 1 << 0,
  LCGPBExtensionPacked        = 1 << 1,
  LCGPBExtensionSetWireFormat = 1 << 2,
};

// An extension
typedef struct LCGPBExtensionDescription {
  LCGPBGenericValue defaultValue;
  const char *singletonName;
  const char *extendedClass;
  const char *messageOrGroupClassName;
  LCGPBEnumDescriptorFunc enumDescriptorFunc;
  int32_t fieldNumber;
  LCGPBDataType dataType;
  LCGPBExtensionOptions options;
} LCGPBExtensionDescription;

typedef NS_OPTIONS(uint32_t, LCGPBDescriptorInitializationFlags) {
  LCGPBDescriptorInitializationFlag_None              = 0,
  LCGPBDescriptorInitializationFlag_FieldsWithDefault = 1 << 0,
  LCGPBDescriptorInitializationFlag_WireFormat        = 1 << 1,
};

@interface LCGPBDescriptor () {
 @package
  NSArray *fields_;
  NSArray *oneofs_;
  uint32_t storageSize_;
}

// fieldDescriptions have to be long lived, they are held as raw pointers.
+ (instancetype)
    allocDescriptorForClass:(Class)messageClass
                  rootClass:(Class)rootClass
                       file:(LCGPBFileDescriptor *)file
                     fields:(void *)fieldDescriptions
                 fieldCount:(uint32_t)fieldCount
                storageSize:(uint32_t)storageSize
                      flags:(LCGPBDescriptorInitializationFlags)flags;

- (instancetype)initWithClass:(Class)messageClass
                         file:(LCGPBFileDescriptor *)file
                       fields:(NSArray *)fields
                  storageSize:(uint32_t)storage
                   wireFormat:(BOOL)wireFormat;

// Called right after init to provide extra information to avoid init having
// an explosion of args. These pointers are recorded, so they are expected
// to live for the lifetime of the app.
- (void)setupOneofs:(const char **)oneofNames
              count:(uint32_t)count
      firstHasIndex:(int32_t)firstHasIndex;
- (void)setupExtraTextInfo:(const char *)extraTextFormatInfo;
- (void)setupExtensionRanges:(const LCGPBExtensionRange *)ranges count:(int32_t)count;
- (void)setupContainingMessageClassName:(const char *)msgClassName;
- (void)setupMessageClassNameSuffix:(NSString *)suffix;

@end

@interface LCGPBFileDescriptor ()
- (instancetype)initWithPackage:(NSString *)package
                     objcPrefix:(NSString *)objcPrefix
                         syntax:(LCGPBFileSyntax)syntax;
- (instancetype)initWithPackage:(NSString *)package
                         syntax:(LCGPBFileSyntax)syntax;
@end

@interface LCGPBOneofDescriptor () {
 @package
  const char *name_;
  NSArray *fields_;
  SEL caseSel_;
}
// name must be long lived.
- (instancetype)initWithName:(const char *)name fields:(NSArray *)fields;
@end

@interface LCGPBFieldDescriptor () {
 @package
  LCGPBMessageFieldDescription *description_;
  LCGPB_UNSAFE_UNRETAINED LCGPBOneofDescriptor *containingOneof_;

  SEL getSel_;
  SEL setSel_;
  SEL hasOrCountSel_;  // *Count for map<>/repeated fields, has* otherwise.
  SEL setHasSel_;
}

// Single initializer
// description has to be long lived, it is held as a raw pointer.
- (instancetype)initWithFieldDescription:(void *)description
                         includesDefault:(BOOL)includesDefault
                                  syntax:(LCGPBFileSyntax)syntax;
@end

@interface LCGPBEnumDescriptor ()
// valueNames, values and extraTextFormatInfo have to be long lived, they are
// held as raw pointers.
+ (instancetype)
    allocDescriptorForName:(NSString *)name
                valueNames:(const char *)valueNames
                    values:(const int32_t *)values
                     count:(uint32_t)valueCount
              enumVerifier:(LCGPBEnumValidationFunc)enumVerifier;
+ (instancetype)
    allocDescriptorForName:(NSString *)name
                valueNames:(const char *)valueNames
                    values:(const int32_t *)values
                     count:(uint32_t)valueCount
              enumVerifier:(LCGPBEnumValidationFunc)enumVerifier
       extraTextFormatInfo:(const char *)extraTextFormatInfo;

- (instancetype)initWithName:(NSString *)name
                  valueNames:(const char *)valueNames
                      values:(const int32_t *)values
                       count:(uint32_t)valueCount
                enumVerifier:(LCGPBEnumValidationFunc)enumVerifier;
@end

@interface LCGPBExtensionDescriptor () {
 @package
  LCGPBExtensionDescription *description_;
}
@property(nonatomic, readonly) LCGPBWireFormat wireType;

// For repeated extensions, alternateWireType is the wireType with the opposite
// value for the packable property.  i.e. - if the extension was marked packed
// it would be the wire type for unpacked; if the extension was marked unpacked,
// it would be the wire type for packed.
@property(nonatomic, readonly) LCGPBWireFormat alternateWireType;

// description has to be long lived, it is held as a raw pointer.
- (instancetype)initWithExtensionDescription:
    (LCGPBExtensionDescription *)description;
- (NSComparisonResult)compareByFieldNumber:(LCGPBExtensionDescriptor *)other;
@end

CF_EXTERN_C_BEGIN

// Direct access is use for speed, to avoid even internally declaring things
// read/write, etc. The warning is enabled in the project to ensure code calling
// protos can turn on -Wdirect-ivar-access without issues.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

LCGPB_INLINE BOOL LCGPBFieldIsMapOrArray(LCGPBFieldDescriptor *field) {
  return (field->description_->flags &
          (LCGPBFieldRepeated | LCGPBFieldMapKeyMask)) != 0;
}

LCGPB_INLINE LCGPBDataType LCGPBGetFieldDataType(LCGPBFieldDescriptor *field) {
  return field->description_->dataType;
}

LCGPB_INLINE int32_t LCGPBFieldHasIndex(LCGPBFieldDescriptor *field) {
  return field->description_->hasIndex;
}

LCGPB_INLINE uint32_t LCGPBFieldNumber(LCGPBFieldDescriptor *field) {
  return field->description_->number;
}

#pragma clang diagnostic pop

uint32_t LCGPBFieldTag(LCGPBFieldDescriptor *self);

// For repeated fields, alternateWireType is the wireType with the opposite
// value for the packable property.  i.e. - if the field was marked packed it
// would be the wire type for unpacked; if the field was marked unpacked, it
// would be the wire type for packed.
uint32_t LCGPBFieldAlternateTag(LCGPBFieldDescriptor *self);

LCGPB_INLINE BOOL LCGPBHasPreservingUnknownEnumSemantics(LCGPBFileSyntax syntax) {
  return syntax == LCGPBFileSyntaxProto3;
}

LCGPB_INLINE BOOL LCGPBExtensionIsRepeated(LCGPBExtensionDescription *description) {
  return (description->options & LCGPBExtensionRepeated) != 0;
}

LCGPB_INLINE BOOL LCGPBExtensionIsPacked(LCGPBExtensionDescription *description) {
  return (description->options & LCGPBExtensionPacked) != 0;
}

LCGPB_INLINE BOOL LCGPBExtensionIsWireFormat(LCGPBExtensionDescription *description) {
  return (description->options & LCGPBExtensionSetWireFormat) != 0;
}

// Helper for compile time assets.
#ifndef LCGPBInternalCompileAssert
  #if __has_feature(c_static_assert) || __has_extension(c_static_assert)
    #define LCGPBInternalCompileAssert(test, msg) _Static_assert((test), #msg)
  #else
    // Pre-Xcode 7 support.
    #define LCGPBInternalCompileAssertSymbolInner(line, msg) LCGPBInternalCompileAssert ## line ## __ ## msg
    #define LCGPBInternalCompileAssertSymbol(line, msg) LCGPBInternalCompileAssertSymbolInner(line, msg)
    #define LCGPBInternalCompileAssert(test, msg) \
        typedef char LCGPBInternalCompileAssertSymbol(__LINE__, msg) [ ((test) ? 1 : -1) ]
  #endif  // __has_feature(c_static_assert) || __has_extension(c_static_assert)
#endif // LCGPBInternalCompileAssert

// Sanity check that there isn't padding between the field description
// structures with and without a default.
LCGPBInternalCompileAssert(sizeof(LCGPBMessageFieldDescriptionWithDefault) ==
                         (sizeof(LCGPBGenericValue) +
                          sizeof(LCGPBMessageFieldDescription)),
                         DescriptionsWithDefault_different_size_than_expected);

CF_EXTERN_C_END
