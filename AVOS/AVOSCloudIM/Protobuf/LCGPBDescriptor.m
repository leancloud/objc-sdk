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

#import "LCGPBDescriptor_PackagePrivate.h"

#import <objc/runtime.h>

#import "LCGPBUtilities_PackagePrivate.h"
#import "LCGPBWireFormat.h"
#import "LCGPBMessage_PackagePrivate.h"

// Direct access is use for speed, to avoid even internally declaring things
// read/write, etc. The warning is enabled in the project to ensure code calling
// protos can turn on -Wdirect-ivar-access without issues.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

// The addresses of these variables are used as keys for objc_getAssociatedObject.
static const char kTextFormatExtraValueKey = 0;
static const char kParentClassNameValueKey = 0;
static const char kClassNameSuffixKey = 0;

// Utility function to generate selectors on the fly.
static SEL SelFromStrings(const char *prefix, const char *middle,
                          const char *suffix, BOOL takesArg) {
  if (prefix == NULL && suffix == NULL && !takesArg) {
    return sel_getUid(middle);
  }
  const size_t prefixLen = prefix != NULL ? strlen(prefix) : 0;
  const size_t middleLen = strlen(middle);
  const size_t suffixLen = suffix != NULL ? strlen(suffix) : 0;
  size_t totalLen =
      prefixLen + middleLen + suffixLen + 1;  // include space for null on end.
  if (takesArg) {
    totalLen += 1;
  }
  char buffer[totalLen];
  if (prefix != NULL) {
    memcpy(buffer, prefix, prefixLen);
    memcpy(buffer + prefixLen, middle, middleLen);
    buffer[prefixLen] = (char)toupper(buffer[prefixLen]);
  } else {
    memcpy(buffer, middle, middleLen);
  }
  if (suffix != NULL) {
    memcpy(buffer + prefixLen + middleLen, suffix, suffixLen);
  }
  if (takesArg) {
    buffer[totalLen - 2] = ':';
  }
  // Always null terminate it.
  buffer[totalLen - 1] = 0;

  SEL result = sel_getUid(buffer);
  return result;
}

static NSArray *NewFieldsArrayForHasIndex(int hasIndex,
                                          NSArray *allMessageFields)
    __attribute__((ns_returns_retained));

static NSArray *NewFieldsArrayForHasIndex(int hasIndex,
                                          NSArray *allMessageFields) {
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (LCGPBFieldDescriptor *fieldDesc in allMessageFields) {
    if (fieldDesc->description_->hasIndex == hasIndex) {
      [result addObject:fieldDesc];
    }
  }
  return result;
}

@implementation LCGPBDescriptor {
  Class messageClass_;
  LCGPBFileDescriptor *file_;
  BOOL wireFormat_;
}

@synthesize messageClass = messageClass_;
@synthesize fields = fields_;
@synthesize oneofs = oneofs_;
@synthesize extensionRanges = extensionRanges_;
@synthesize extensionRangesCount = extensionRangesCount_;
@synthesize file = file_;
@synthesize wireFormat = wireFormat_;

+ (instancetype)
    allocDescriptorForClass:(Class)messageClass
                  rootClass:(Class)rootClass
                       file:(LCGPBFileDescriptor *)file
                     fields:(void *)fieldDescriptions
                 fieldCount:(uint32_t)fieldCount
                storageSize:(uint32_t)storageSize
                      flags:(LCGPBDescriptorInitializationFlags)flags {
  // The rootClass is no longer used, but it is passed in to ensure it
  // was started up during initialization also.
  (void)rootClass;
  NSMutableArray *fields = nil;
  LCGPBFileSyntax syntax = file.syntax;
  BOOL fieldsIncludeDefault =
      (flags & LCGPBDescriptorInitializationFlag_FieldsWithDefault) != 0;

  void *desc;
  for (uint32_t i = 0; i < fieldCount; ++i) {
    if (fields == nil) {
      fields = [[NSMutableArray alloc] initWithCapacity:fieldCount];
    }
    // Need correctly typed pointer for array indexing below to work.
    if (fieldsIncludeDefault) {
      LCGPBMessageFieldDescriptionWithDefault *fieldDescWithDefault = fieldDescriptions;
      desc = &(fieldDescWithDefault[i]);
    } else {
      LCGPBMessageFieldDescription *fieldDesc = fieldDescriptions;
      desc = &(fieldDesc[i]);
    }
    LCGPBFieldDescriptor *fieldDescriptor =
        [[LCGPBFieldDescriptor alloc] initWithFieldDescription:desc
                                             includesDefault:fieldsIncludeDefault
                                                      syntax:syntax];
    [fields addObject:fieldDescriptor];
    [fieldDescriptor release];
  }

  BOOL wireFormat = (flags & LCGPBDescriptorInitializationFlag_WireFormat) != 0;
  LCGPBDescriptor *descriptor = [[self alloc] initWithClass:messageClass
                                                     file:file
                                                   fields:fields
                                              storageSize:storageSize
                                               wireFormat:wireFormat];
  [fields release];
  return descriptor;
}

- (instancetype)initWithClass:(Class)messageClass
                         file:(LCGPBFileDescriptor *)file
                       fields:(NSArray *)fields
                  storageSize:(uint32_t)storageSize
                   wireFormat:(BOOL)wireFormat {
  if ((self = [super init])) {
    messageClass_ = messageClass;
    file_ = file;
    fields_ = [fields retain];
    storageSize_ = storageSize;
    wireFormat_ = wireFormat;
  }
  return self;
}

- (void)dealloc {
  [fields_ release];
  [oneofs_ release];
  [super dealloc];
}

- (void)setupOneofs:(const char **)oneofNames
              count:(uint32_t)count
      firstHasIndex:(int32_t)firstHasIndex {
  NSCAssert(firstHasIndex < 0, @"Should always be <0");
  NSMutableArray *oneofs = [[NSMutableArray alloc] initWithCapacity:count];
  for (uint32_t i = 0, hasIndex = firstHasIndex; i < count; ++i, --hasIndex) {
    const char *name = oneofNames[i];
    NSArray *fieldsForOneof = NewFieldsArrayForHasIndex(hasIndex, fields_);
    NSCAssert(fieldsForOneof.count > 0,
              @"No fields for this oneof? (%s:%d)", name, hasIndex);
    LCGPBOneofDescriptor *oneofDescriptor =
        [[LCGPBOneofDescriptor alloc] initWithName:name fields:fieldsForOneof];
    [oneofs addObject:oneofDescriptor];
    [oneofDescriptor release];
    [fieldsForOneof release];
  }
  oneofs_ = oneofs;
}

- (void)setupExtraTextInfo:(const char *)extraTextFormatInfo {
  // Extra info is a compile time option, so skip the work if not needed.
  if (extraTextFormatInfo) {
    NSValue *extraInfoValue = [NSValue valueWithPointer:extraTextFormatInfo];
    for (LCGPBFieldDescriptor *fieldDescriptor in fields_) {
      if (fieldDescriptor->description_->flags & LCGPBFieldTextFormatNameCustom) {
        objc_setAssociatedObject(fieldDescriptor, &kTextFormatExtraValueKey,
                                 extraInfoValue,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      }
    }
  }
}

- (void)setupExtensionRanges:(const LCGPBExtensionRange *)ranges count:(int32_t)count {
  extensionRanges_ = ranges;
  extensionRangesCount_ = count;
}

- (void)setupContainingMessageClassName:(const char *)msgClassName {
  // Note: Only fetch the class here, can't send messages to it because
  // that could cause cycles back to this class within +initialize if
  // two messages have each other in fields (i.e. - they build a graph).
  NSAssert(objc_getClass(msgClassName), @"Class %s not defined", msgClassName);
  NSValue *parentNameValue = [NSValue valueWithPointer:msgClassName];
  objc_setAssociatedObject(self, &kParentClassNameValueKey,
                           parentNameValue,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setupMessageClassNameSuffix:(NSString *)suffix {
  if (suffix.length) {
    objc_setAssociatedObject(self, &kClassNameSuffixKey,
                             suffix,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
}

- (NSString *)name {
  return NSStringFromClass(messageClass_);
}

- (LCGPBDescriptor *)containingType {
  NSValue *parentNameValue =
      objc_getAssociatedObject(self, &kParentClassNameValueKey);
  if (!parentNameValue) {
    return nil;
  }
  const char *parentName = [parentNameValue pointerValue];
  Class parentClass = objc_getClass(parentName);
  NSAssert(parentClass, @"Class %s not defined", parentName);
  return [parentClass descriptor];
}

- (NSString *)fullName {
  NSString *className = NSStringFromClass(self.messageClass);
  LCGPBFileDescriptor *file = self.file;
  NSString *objcPrefix = file.objcPrefix;
  if (objcPrefix && ![className hasPrefix:objcPrefix]) {
    NSAssert(0,
             @"Class didn't have correct prefix? (%@ - %@)",
             className, objcPrefix);
    return nil;
  }
  LCGPBDescriptor *parent = self.containingType;

  NSString *name = nil;
  if (parent) {
    NSString *parentClassName = NSStringFromClass(parent.messageClass);
    // The generator will add _Class to avoid reserved words, drop it.
    NSString *suffix = objc_getAssociatedObject(parent, &kClassNameSuffixKey);
    if (suffix) {
      if (![parentClassName hasSuffix:suffix]) {
        NSAssert(0,
                 @"ParentMessage class didn't have correct suffix? (%@ - %@)",
                 className, suffix);
        return nil;
      }
      parentClassName =
          [parentClassName substringToIndex:(parentClassName.length - suffix.length)];
    }
    NSString *parentPrefix = [parentClassName stringByAppendingString:@"_"];
    if (![className hasPrefix:parentPrefix]) {
      NSAssert(0,
               @"Class didn't have the correct parent name prefix? (%@ - %@)",
               parentPrefix, className);
      return nil;
    }
    name = [className substringFromIndex:parentPrefix.length];
  } else {
    name = [className substringFromIndex:objcPrefix.length];
  }

  // The generator will add _Class to avoid reserved words, drop it.
  NSString *suffix = objc_getAssociatedObject(self, &kClassNameSuffixKey);
  if (suffix) {
    if (![name hasSuffix:suffix]) {
      NSAssert(0,
               @"Message class didn't have correct suffix? (%@ - %@)",
               name, suffix);
      return nil;
    }
    name = [name substringToIndex:(name.length - suffix.length)];
  }

  NSString *prefix = (parent != nil ? parent.fullName : file.package);
  NSString *result;
  if (prefix.length > 0) {
    result = [NSString stringWithFormat:@"%@.%@", prefix, name];
  } else {
    result = name;
  }
  return result;
}

- (id)copyWithZone:(NSZone *)zone {
#pragma unused(zone)
  return [self retain];
}

- (LCGPBFieldDescriptor *)fieldWithNumber:(uint32_t)fieldNumber {
  for (LCGPBFieldDescriptor *descriptor in fields_) {
    if (LCGPBFieldNumber(descriptor) == fieldNumber) {
      return descriptor;
    }
  }
  return nil;
}

- (LCGPBFieldDescriptor *)fieldWithName:(NSString *)name {
  for (LCGPBFieldDescriptor *descriptor in fields_) {
    if ([descriptor.name isEqual:name]) {
      return descriptor;
    }
  }
  return nil;
}

- (LCGPBOneofDescriptor *)oneofWithName:(NSString *)name {
  for (LCGPBOneofDescriptor *descriptor in oneofs_) {
    if ([descriptor.name isEqual:name]) {
      return descriptor;
    }
  }
  return nil;
}

@end

@implementation LCGPBFileDescriptor {
  NSString *package_;
  NSString *objcPrefix_;
  LCGPBFileSyntax syntax_;
}

@synthesize package = package_;
@synthesize objcPrefix = objcPrefix_;
@synthesize syntax = syntax_;

- (instancetype)initWithPackage:(NSString *)package
                     objcPrefix:(NSString *)objcPrefix
                         syntax:(LCGPBFileSyntax)syntax {
  self = [super init];
  if (self) {
    package_ = [package copy];
    objcPrefix_ = [objcPrefix copy];
    syntax_ = syntax;
  }
  return self;
}

- (instancetype)initWithPackage:(NSString *)package
                         syntax:(LCGPBFileSyntax)syntax {
  self = [super init];
  if (self) {
    package_ = [package copy];
    syntax_ = syntax;
  }
  return self;
}

- (void)dealloc {
  [package_ release];
  [objcPrefix_ release];
  [super dealloc];
}

@end

@implementation LCGPBOneofDescriptor

@synthesize fields = fields_;

- (instancetype)initWithName:(const char *)name fields:(NSArray *)fields {
  self = [super init];
  if (self) {
    name_ = name;
    fields_ = [fields retain];
    for (LCGPBFieldDescriptor *fieldDesc in fields) {
      fieldDesc->containingOneof_ = self;
    }

    caseSel_ = SelFromStrings(NULL, name, "OneOfCase", NO);
  }
  return self;
}

- (void)dealloc {
  [fields_ release];
  [super dealloc];
}

- (NSString *)name {
  return (NSString * _Nonnull)@(name_);
}

- (LCGPBFieldDescriptor *)fieldWithNumber:(uint32_t)fieldNumber {
  for (LCGPBFieldDescriptor *descriptor in fields_) {
    if (LCGPBFieldNumber(descriptor) == fieldNumber) {
      return descriptor;
    }
  }
  return nil;
}

- (LCGPBFieldDescriptor *)fieldWithName:(NSString *)name {
  for (LCGPBFieldDescriptor *descriptor in fields_) {
    if ([descriptor.name isEqual:name]) {
      return descriptor;
    }
  }
  return nil;
}

@end

uint32_t LCGPBFieldTag(LCGPBFieldDescriptor *self) {
  LCGPBMessageFieldDescription *description = self->description_;
  LCGPBWireFormat format;
  if ((description->flags & LCGPBFieldMapKeyMask) != 0) {
    // Maps are repeated messages on the wire.
    format = LCGPBWireFormatForType(LCGPBDataTypeMessage, NO);
  } else {
    format = LCGPBWireFormatForType(description->dataType,
                                  ((description->flags & LCGPBFieldPacked) != 0));
  }
  return LCGPBWireFormatMakeTag(description->number, format);
}

uint32_t LCGPBFieldAlternateTag(LCGPBFieldDescriptor *self) {
  LCGPBMessageFieldDescription *description = self->description_;
  NSCAssert((description->flags & LCGPBFieldRepeated) != 0,
            @"Only valid on repeated fields");
  LCGPBWireFormat format =
      LCGPBWireFormatForType(description->dataType,
                           ((description->flags & LCGPBFieldPacked) == 0));
  return LCGPBWireFormatMakeTag(description->number, format);
}

@implementation LCGPBFieldDescriptor {
  LCGPBGenericValue defaultValue_;

  // Message ivars
  Class msgClass_;

  // Enum ivars.
  // If protos are generated with GenerateEnumDescriptors on then it will
  // be a enumDescriptor, otherwise it will be a enumVerifier.
  union {
    LCGPBEnumDescriptor *enumDescriptor_;
    LCGPBEnumValidationFunc enumVerifier_;
  } enumHandling_;
}

@synthesize msgClass = msgClass_;
@synthesize containingOneof = containingOneof_;

- (instancetype)init {
  // Throw an exception if people attempt to not use the designated initializer.
  self = [super init];
  if (self != nil) {
    [self doesNotRecognizeSelector:_cmd];
    self = nil;
  }
  return self;
}

- (instancetype)initWithFieldDescription:(void *)description
                         includesDefault:(BOOL)includesDefault
                                  syntax:(LCGPBFileSyntax)syntax {
  if ((self = [super init])) {
    LCGPBMessageFieldDescription *coreDesc;
    if (includesDefault) {
      coreDesc = &(((LCGPBMessageFieldDescriptionWithDefault *)description)->core);
    } else {
      coreDesc = description;
    }
    description_ = coreDesc;
    getSel_ = sel_getUid(coreDesc->name);
    setSel_ = SelFromStrings("set", coreDesc->name, NULL, YES);

    LCGPBDataType dataType = coreDesc->dataType;
    BOOL isMessage = LCGPBDataTypeIsMessage(dataType);
    BOOL isMapOrArray = LCGPBFieldIsMapOrArray(self);

    if (isMapOrArray) {
      // map<>/repeated fields get a *Count property (inplace of a has*) to
      // support checking if there are any entries without triggering
      // autocreation.
      hasOrCountSel_ = SelFromStrings(NULL, coreDesc->name, "_Count", NO);
    } else {
      // If there is a positive hasIndex, then:
      //   - All fields types for proto2 messages get has* selectors.
      //   - Only message fields for proto3 messages get has* selectors.
      // Note: the positive check is to handle oneOfs, we can't check
      // containingOneof_ because it isn't set until after initialization.
      if ((coreDesc->hasIndex >= 0) &&
          (coreDesc->hasIndex != LCGPBNoHasBit) &&
          ((syntax != LCGPBFileSyntaxProto3) || isMessage)) {
        hasOrCountSel_ = SelFromStrings("has", coreDesc->name, NULL, NO);
        setHasSel_ = SelFromStrings("setHas", coreDesc->name, NULL, YES);
      }
    }

    // Extra type specific data.
    if (isMessage) {
      const char *className = coreDesc->dataTypeSpecific.className;
      // Note: Only fetch the class here, can't send messages to it because
      // that could cause cycles back to this class within +initialize if
      // two messages have each other in fields (i.e. - they build a graph).
      msgClass_ = objc_getClass(className);
      NSAssert(msgClass_, @"Class %s not defined", className);
    } else if (dataType == LCGPBDataTypeEnum) {
      if ((coreDesc->flags & LCGPBFieldHasEnumDescriptor) != 0) {
        enumHandling_.enumDescriptor_ =
            coreDesc->dataTypeSpecific.enumDescFunc();
      } else {
        enumHandling_.enumVerifier_ =
            coreDesc->dataTypeSpecific.enumVerifier;
      }
    }

    // Non map<>/repeated fields can have defaults in proto2 syntax.
    if (!isMapOrArray && includesDefault) {
      defaultValue_ = ((LCGPBMessageFieldDescriptionWithDefault *)description)->defaultValue;
      if (dataType == LCGPBDataTypeBytes) {
        // Data stored as a length prefixed (network byte order) c-string in
        // descriptor structure.
        const uint8_t *bytes = (const uint8_t *)defaultValue_.valueData;
        if (bytes) {
          uint32_t length;
          memcpy(&length, bytes, sizeof(length));
          length = ntohl(length);
          bytes += sizeof(length);
          defaultValue_.valueData =
              [[NSData alloc] initWithBytes:bytes length:length];
        }
      }
    }
  }
  return self;
}

- (void)dealloc {
  if (description_->dataType == LCGPBDataTypeBytes &&
      !(description_->flags & LCGPBFieldRepeated)) {
    [defaultValue_.valueData release];
  }
  [super dealloc];
}

- (LCGPBDataType)dataType {
  return description_->dataType;
}

- (BOOL)hasDefaultValue {
  return (description_->flags & LCGPBFieldHasDefaultValue) != 0;
}

- (uint32_t)number {
  return description_->number;
}

- (NSString *)name {
  return (NSString * _Nonnull)@(description_->name);
}

- (BOOL)isRequired {
  return (description_->flags & LCGPBFieldRequired) != 0;
}

- (BOOL)isOptional {
  return (description_->flags & LCGPBFieldOptional) != 0;
}

- (LCGPBFieldType)fieldType {
  LCGPBFieldFlags flags = description_->flags;
  if ((flags & LCGPBFieldRepeated) != 0) {
    return LCGPBFieldTypeRepeated;
  } else if ((flags & LCGPBFieldMapKeyMask) != 0) {
    return LCGPBFieldTypeMap;
  } else {
    return LCGPBFieldTypeSingle;
  }
}

- (LCGPBDataType)mapKeyDataType {
  switch (description_->flags & LCGPBFieldMapKeyMask) {
    case LCGPBFieldMapKeyInt32:
      return LCGPBDataTypeInt32;
    case LCGPBFieldMapKeyInt64:
      return LCGPBDataTypeInt64;
    case LCGPBFieldMapKeyUInt32:
      return LCGPBDataTypeUInt32;
    case LCGPBFieldMapKeyUInt64:
      return LCGPBDataTypeUInt64;
    case LCGPBFieldMapKeySInt32:
      return LCGPBDataTypeSInt32;
    case LCGPBFieldMapKeySInt64:
      return LCGPBDataTypeSInt64;
    case LCGPBFieldMapKeyFixed32:
      return LCGPBDataTypeFixed32;
    case LCGPBFieldMapKeyFixed64:
      return LCGPBDataTypeFixed64;
    case LCGPBFieldMapKeySFixed32:
      return LCGPBDataTypeSFixed32;
    case LCGPBFieldMapKeySFixed64:
      return LCGPBDataTypeSFixed64;
    case LCGPBFieldMapKeyBool:
      return LCGPBDataTypeBool;
    case LCGPBFieldMapKeyString:
      return LCGPBDataTypeString;

    default:
      NSAssert(0, @"Not a map type");
      return LCGPBDataTypeInt32;  // For lack of anything better.
  }
}

- (BOOL)isPackable {
  return (description_->flags & LCGPBFieldPacked) != 0;
}

- (BOOL)isValidEnumValue:(int32_t)value {
  NSAssert(description_->dataType == LCGPBDataTypeEnum,
           @"Field Must be of type LCGPBDataTypeEnum");
  if (description_->flags & LCGPBFieldHasEnumDescriptor) {
    return enumHandling_.enumDescriptor_.enumVerifier(value);
  } else {
    return enumHandling_.enumVerifier_(value);
  }
}

- (LCGPBEnumDescriptor *)enumDescriptor {
  if (description_->flags & LCGPBFieldHasEnumDescriptor) {
    return enumHandling_.enumDescriptor_;
  } else {
    return nil;
  }
}

- (LCGPBGenericValue)defaultValue {
  // Depends on the fact that defaultValue_ is initialized either to "0/nil" or
  // to an actual defaultValue in our initializer.
  LCGPBGenericValue value = defaultValue_;

  if (!(description_->flags & LCGPBFieldRepeated)) {
    // We special handle data and strings. If they are nil, we replace them
    // with empty string/empty data.
    LCGPBDataType type = description_->dataType;
    if (type == LCGPBDataTypeBytes && value.valueData == nil) {
      value.valueData = LCGPBEmptyNSData();
    } else if (type == LCGPBDataTypeString && value.valueString == nil) {
      value.valueString = @"";
    }
  }
  return value;
}

- (NSString *)textFormatName {
  if ((description_->flags & LCGPBFieldTextFormatNameCustom) != 0) {
    NSValue *extraInfoValue =
        objc_getAssociatedObject(self, &kTextFormatExtraValueKey);
    // Support can be left out at generation time.
    if (!extraInfoValue) {
      return nil;
    }
    const uint8_t *extraTextFormatInfo = [extraInfoValue pointerValue];
    return LCGPBDecodeTextFormatName(extraTextFormatInfo, LCGPBFieldNumber(self),
                                   self.name);
  }

  // The logic here has to match SetCommonFieldVariables() from
  // objectivec_field.cc in the proto compiler.
  NSString *name = self.name;
  NSUInteger len = [name length];

  // Remove the "_p" added to reserved names.
  if ([name hasSuffix:@"_p"]) {
    name = [name substringToIndex:(len - 2)];
    len = [name length];
  }

  // Remove "Array" from the end for repeated fields.
  if (((description_->flags & LCGPBFieldRepeated) != 0) &&
      [name hasSuffix:@"Array"]) {
    name = [name substringToIndex:(len - 5)];
    len = [name length];
  }

  // Groups vs. other fields.
  if (description_->dataType == LCGPBDataTypeGroup) {
    // Just capitalize the first letter.
    unichar firstChar = [name characterAtIndex:0];
    if (firstChar >= 'a' && firstChar <= 'z') {
      NSString *firstCharString =
          [NSString stringWithFormat:@"%C", (unichar)(firstChar - 'a' + 'A')];
      NSString *result =
          [name stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                        withString:firstCharString];
      return result;
    }
    return name;

  } else {
    // Undo the CamelCase.
    NSMutableString *result = [NSMutableString stringWithCapacity:len];
    for (uint32_t i = 0; i < len; i++) {
      unichar c = [name characterAtIndex:i];
      if (c >= 'A' && c <= 'Z') {
        if (i > 0) {
          [result appendFormat:@"_%C", (unichar)(c - 'A' + 'a')];
        } else {
          [result appendFormat:@"%C", c];
        }
      } else {
        [result appendFormat:@"%C", c];
      }
    }
    return result;
  }
}

@end

@implementation LCGPBEnumDescriptor {
  NSString *name_;
  // valueNames_ is a single c string with all of the value names appended
  // together, each null terminated.  -calcValueNameOffsets fills in
  // nameOffsets_ with the offsets to allow quicker access to the individual
  // names.
  const char *valueNames_;
  const int32_t *values_;
  LCGPBEnumValidationFunc enumVerifier_;
  const uint8_t *extraTextFormatInfo_;
  uint32_t *nameOffsets_;
  uint32_t valueCount_;
}

@synthesize name = name_;
@synthesize enumVerifier = enumVerifier_;

+ (instancetype)
    allocDescriptorForName:(NSString *)name
                valueNames:(const char *)valueNames
                    values:(const int32_t *)values
                     count:(uint32_t)valueCount
              enumVerifier:(LCGPBEnumValidationFunc)enumVerifier {
  LCGPBEnumDescriptor *descriptor = [[self alloc] initWithName:name
                                                  valueNames:valueNames
                                                      values:values
                                                       count:valueCount
                                                enumVerifier:enumVerifier];
  return descriptor;
}

+ (instancetype)
    allocDescriptorForName:(NSString *)name
                valueNames:(const char *)valueNames
                    values:(const int32_t *)values
                     count:(uint32_t)valueCount
              enumVerifier:(LCGPBEnumValidationFunc)enumVerifier
       extraTextFormatInfo:(const char *)extraTextFormatInfo {
  // Call the common case.
  LCGPBEnumDescriptor *descriptor = [self allocDescriptorForName:name
                                                    valueNames:valueNames
                                                        values:values
                                                         count:valueCount
                                                  enumVerifier:enumVerifier];
  // Set the extra info.
  descriptor->extraTextFormatInfo_ = (const uint8_t *)extraTextFormatInfo;
  return descriptor;
}

- (instancetype)initWithName:(NSString *)name
                  valueNames:(const char *)valueNames
                      values:(const int32_t *)values
                       count:(uint32_t)valueCount
                enumVerifier:(LCGPBEnumValidationFunc)enumVerifier {
  if ((self = [super init])) {
    name_ = [name copy];
    valueNames_ = valueNames;
    values_ = values;
    valueCount_ = valueCount;
    enumVerifier_ = enumVerifier;
  }
  return self;
}

- (void)dealloc {
  [name_ release];
  if (nameOffsets_) free(nameOffsets_);
  [super dealloc];
}

- (void)calcValueNameOffsets {
  @synchronized(self) {
    if (nameOffsets_ != NULL) {
      return;
    }
    uint32_t *offsets = malloc(valueCount_ * sizeof(uint32_t));
    if (!offsets) return;
    const char *scan = valueNames_;
    for (uint32_t i = 0; i < valueCount_; ++i) {
      offsets[i] = (uint32_t)(scan - valueNames_);
      while (*scan != '\0') ++scan;
      ++scan;  // Step over the null.
    }
    nameOffsets_ = offsets;
  }
}

- (NSString *)enumNameForValue:(int32_t)number {
  for (uint32_t i = 0; i < valueCount_; ++i) {
    if (values_[i] == number) {
      return [self getEnumNameForIndex:i];
    }
  }
  return nil;
}

- (BOOL)getValue:(int32_t *)outValue forEnumName:(NSString *)name {
  // Must have the prefix.
  NSUInteger prefixLen = name_.length + 1;
  if ((name.length <= prefixLen) || ![name hasPrefix:name_] ||
      ([name characterAtIndex:prefixLen - 1] != '_')) {
    return NO;
  }

  // Skip over the prefix.
  const char *nameAsCStr = [name UTF8String];
  nameAsCStr += prefixLen;

  if (nameOffsets_ == NULL) [self calcValueNameOffsets];
  if (nameOffsets_ == NULL) return NO;

  // Find it.
  for (uint32_t i = 0; i < valueCount_; ++i) {
    const char *valueName = valueNames_ + nameOffsets_[i];
    if (strcmp(nameAsCStr, valueName) == 0) {
      if (outValue) {
        *outValue = values_[i];
      }
      return YES;
    }
  }
  return NO;
}

- (BOOL)getValue:(int32_t *)outValue forEnumTextFormatName:(NSString *)textFormatName {
    if (nameOffsets_ == NULL) [self calcValueNameOffsets];
    if (nameOffsets_ == NULL) return NO;

    for (uint32_t i = 0; i < valueCount_; ++i) {
        NSString *valueTextFormatName = [self getEnumTextFormatNameForIndex:i];
        if ([valueTextFormatName isEqual:textFormatName]) {
            if (outValue) {
                *outValue = values_[i];
            }
            return YES;
        }
    }
    return NO;
}

- (NSString *)textFormatNameForValue:(int32_t)number {
  // Find the EnumValue descriptor and its index.
  BOOL foundIt = NO;
  uint32_t valueDescriptorIndex;
  for (valueDescriptorIndex = 0; valueDescriptorIndex < valueCount_;
       ++valueDescriptorIndex) {
    if (values_[valueDescriptorIndex] == number) {
      foundIt = YES;
      break;
    }
  }

  if (!foundIt) {
    return nil;
  }
  return [self getEnumTextFormatNameForIndex:valueDescriptorIndex];
}

- (uint32_t)enumNameCount {
  return valueCount_;
}

- (NSString *)getEnumNameForIndex:(uint32_t)index {
  if (nameOffsets_ == NULL) [self calcValueNameOffsets];
  if (nameOffsets_ == NULL) return nil;

  if (index >= valueCount_) {
    return nil;
  }
  const char *valueName = valueNames_ + nameOffsets_[index];
  NSString *fullName = [NSString stringWithFormat:@"%@_%s", name_, valueName];
  return fullName;
}

- (NSString *)getEnumTextFormatNameForIndex:(uint32_t)index {
  if (nameOffsets_ == NULL) [self calcValueNameOffsets];
  if (nameOffsets_ == NULL) return nil;

  if (index >= valueCount_) {
    return nil;
  }
  NSString *result = nil;
  // Naming adds an underscore between enum name and value name, skip that also.
  const char *valueName = valueNames_ + nameOffsets_[index];
  NSString *shortName = @(valueName);

  // See if it is in the map of special format handling.
  if (extraTextFormatInfo_) {
    result = LCGPBDecodeTextFormatName(extraTextFormatInfo_,
                                     (int32_t)index, shortName);
  }
  // Logic here needs to match what objectivec_enum.cc does in the proto
  // compiler.
  if (result == nil) {
    NSUInteger len = [shortName length];
    NSMutableString *worker = [NSMutableString stringWithCapacity:len];
    for (NSUInteger i = 0; i < len; i++) {
      unichar c = [shortName characterAtIndex:i];
      if (i > 0 && c >= 'A' && c <= 'Z') {
        [worker appendString:@"_"];
      }
      [worker appendFormat:@"%c", toupper((char)c)];
    }
    result = worker;
  }
  return result;
}

@end

@implementation LCGPBExtensionDescriptor {
  LCGPBGenericValue defaultValue_;
}

@synthesize containingMessageClass = containingMessageClass_;

- (instancetype)initWithExtensionDescription:
        (LCGPBExtensionDescription *)description {
  if ((self = [super init])) {
    description_ = description;

#if defined(DEBUG) && DEBUG
    const char *className = description->messageOrGroupClassName;
    if (className) {
      NSAssert(objc_lookUpClass(className) != Nil,
               @"Class %s not defined", className);
    }
#endif

    if (description->extendedClass) {
      Class containingClass = objc_lookUpClass(description->extendedClass);
      NSAssert(containingClass, @"Class %s not defined",
               description->extendedClass);
      containingMessageClass_ = containingClass;
    }

    LCGPBDataType type = description_->dataType;
    if (type == LCGPBDataTypeBytes) {
      // Data stored as a length prefixed c-string in descriptor records.
      const uint8_t *bytes =
          (const uint8_t *)description->defaultValue.valueData;
      if (bytes) {
        uint32_t length;
        memcpy(&length, bytes, sizeof(length));
        // The length is stored in network byte order.
        length = ntohl(length);
        bytes += sizeof(length);
        defaultValue_.valueData =
            [[NSData alloc] initWithBytes:bytes length:length];
      }
    } else if (type == LCGPBDataTypeMessage || type == LCGPBDataTypeGroup) {
      // The default is looked up in -defaultValue instead since extensions
      // aren't common, we avoid the hit startup hit and it avoid initialization
      // order issues.
    } else {
      defaultValue_ = description->defaultValue;
    }
  }
  return self;
}

- (void)dealloc {
  if ((description_->dataType == LCGPBDataTypeBytes) &&
      !LCGPBExtensionIsRepeated(description_)) {
    [defaultValue_.valueData release];
  }
  [super dealloc];
}

- (instancetype)copyWithZone:(NSZone *)zone {
#pragma unused(zone)
  // Immutable.
  return [self retain];
}

- (NSString *)singletonName {
  return (NSString * _Nonnull)@(description_->singletonName);
}

- (const char *)singletonNameC {
  return description_->singletonName;
}

- (uint32_t)fieldNumber {
  return description_->fieldNumber;
}

- (LCGPBDataType)dataType {
  return description_->dataType;
}

- (LCGPBWireFormat)wireType {
  return LCGPBWireFormatForType(description_->dataType,
                              LCGPBExtensionIsPacked(description_));
}

- (LCGPBWireFormat)alternateWireType {
  NSAssert(LCGPBExtensionIsRepeated(description_),
           @"Only valid on repeated extensions");
  return LCGPBWireFormatForType(description_->dataType,
                              !LCGPBExtensionIsPacked(description_));
}

- (BOOL)isRepeated {
  return LCGPBExtensionIsRepeated(description_);
}

- (BOOL)isPackable {
  return LCGPBExtensionIsPacked(description_);
}

- (Class)msgClass {
  return objc_getClass(description_->messageOrGroupClassName);
}

- (LCGPBEnumDescriptor *)enumDescriptor {
  if (description_->dataType == LCGPBDataTypeEnum) {
    LCGPBEnumDescriptor *enumDescriptor = description_->enumDescriptorFunc();
    return enumDescriptor;
  }
  return nil;
}

- (id)defaultValue {
  if (LCGPBExtensionIsRepeated(description_)) {
    return nil;
  }

  switch (description_->dataType) {
    case LCGPBDataTypeBool:
      return @(defaultValue_.valueBool);
    case LCGPBDataTypeFloat:
      return @(defaultValue_.valueFloat);
    case LCGPBDataTypeDouble:
      return @(defaultValue_.valueDouble);
    case LCGPBDataTypeInt32:
    case LCGPBDataTypeSInt32:
    case LCGPBDataTypeEnum:
    case LCGPBDataTypeSFixed32:
      return @(defaultValue_.valueInt32);
    case LCGPBDataTypeInt64:
    case LCGPBDataTypeSInt64:
    case LCGPBDataTypeSFixed64:
      return @(defaultValue_.valueInt64);
    case LCGPBDataTypeUInt32:
    case LCGPBDataTypeFixed32:
      return @(defaultValue_.valueUInt32);
    case LCGPBDataTypeUInt64:
    case LCGPBDataTypeFixed64:
      return @(defaultValue_.valueUInt64);
    case LCGPBDataTypeBytes:
      // Like message fields, the default is zero length data.
      return (defaultValue_.valueData ? defaultValue_.valueData
                                      : LCGPBEmptyNSData());
    case LCGPBDataTypeString:
      // Like message fields, the default is zero length string.
      return (defaultValue_.valueString ? defaultValue_.valueString : @"");
    case LCGPBDataTypeGroup:
    case LCGPBDataTypeMessage:
      return nil;
  }
}

- (NSComparisonResult)compareByFieldNumber:(LCGPBExtensionDescriptor *)other {
  int32_t selfNumber = description_->fieldNumber;
  int32_t otherNumber = other->description_->fieldNumber;
  if (selfNumber < otherNumber) {
    return NSOrderedAscending;
  } else if (selfNumber == otherNumber) {
    return NSOrderedSame;
  } else {
    return NSOrderedDescending;
  }
}

@end

#pragma clang diagnostic pop
