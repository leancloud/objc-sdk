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

#import "LCGPBUtilities_PackagePrivate.h"

#import <objc/runtime.h>

#import "LCGPBArray_PackagePrivate.h"
#import "LCGPBDescriptor_PackagePrivate.h"
#import "LCGPBDictionary_PackagePrivate.h"
#import "LCGPBMessage_PackagePrivate.h"
#import "LCGPBUnknownField.h"
#import "LCGPBUnknownFieldSet.h"

// Direct access is use for speed, to avoid even internally declaring things
// read/write, etc. The warning is enabled in the project to ensure code calling
// protos can turn on -Wdirect-ivar-access without issues.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

static void AppendTextFormatForMessage(LCGPBMessage *message,
                                       NSMutableString *toStr,
                                       NSString *lineIndent);

// Are two datatypes the same basic type representation (ex Int32 and SInt32).
// Marked unused because currently only called from asserts/debug.
static BOOL DataTypesEquivalent(LCGPBDataType type1,
                                LCGPBDataType type2) __attribute__ ((unused));

// Basic type representation for a type (ex: for SInt32 it is Int32).
// Marked unused because currently only called from asserts/debug.
static LCGPBDataType BaseDataType(LCGPBDataType type) __attribute__ ((unused));

// String name for a data type.
// Marked unused because currently only called from asserts/debug.
static NSString *TypeToString(LCGPBDataType dataType) __attribute__ ((unused));

NSData *LCGPBEmptyNSData(void) {
  static dispatch_once_t onceToken;
  static NSData *defaultNSData = nil;
  dispatch_once(&onceToken, ^{
    defaultNSData = [[NSData alloc] init];
  });
  return defaultNSData;
}

void LCGPBMessageDropUnknownFieldsRecursively(LCGPBMessage *initialMessage) {
  if (!initialMessage) {
    return;
  }

  // Use an array as a list to process to avoid recursion.
  NSMutableArray *todo = [NSMutableArray arrayWithObject:initialMessage];

  while (todo.count) {
    LCGPBMessage *msg = todo.lastObject;
    [todo removeLastObject];

    // Clear unknowns.
    msg.unknownFields = nil;

    // Handle the message fields.
    LCGPBDescriptor *descriptor = [[msg class] descriptor];
    for (LCGPBFieldDescriptor *field in descriptor->fields_) {
      if (!LCGPBFieldDataTypeIsMessage(field)) {
        continue;
      }
      switch (field.fieldType) {
        case LCGPBFieldTypeSingle:
          if (LCGPBGetHasIvarField(msg, field)) {
            LCGPBMessage *fieldMessage = LCGPBGetObjectIvarWithFieldNoAutocreate(msg, field);
            [todo addObject:fieldMessage];
          }
          break;

        case LCGPBFieldTypeRepeated: {
          NSArray *fieldMessages = LCGPBGetObjectIvarWithFieldNoAutocreate(msg, field);
          if (fieldMessages.count) {
            [todo addObjectsFromArray:fieldMessages];
          }
          break;
        }

        case LCGPBFieldTypeMap: {
          id rawFieldMap = LCGPBGetObjectIvarWithFieldNoAutocreate(msg, field);
          switch (field.mapKeyDataType) {
            case LCGPBDataTypeBool:
              [(LCGPBBoolObjectDictionary*)rawFieldMap enumerateKeysAndObjectsUsingBlock:^(
                  BOOL key, id _Nonnull object, BOOL * _Nonnull stop) {
                #pragma unused(key, stop)
                [todo addObject:object];
              }];
              break;
            case LCGPBDataTypeFixed32:
            case LCGPBDataTypeUInt32:
              [(LCGPBUInt32ObjectDictionary*)rawFieldMap enumerateKeysAndObjectsUsingBlock:^(
                  uint32_t key, id _Nonnull object, BOOL * _Nonnull stop) {
                #pragma unused(key, stop)
                [todo addObject:object];
              }];
              break;
            case LCGPBDataTypeInt32:
            case LCGPBDataTypeSFixed32:
            case LCGPBDataTypeSInt32:
              [(LCGPBInt32ObjectDictionary*)rawFieldMap enumerateKeysAndObjectsUsingBlock:^(
                  int32_t key, id _Nonnull object, BOOL * _Nonnull stop) {
                #pragma unused(key, stop)
                [todo addObject:object];
              }];
              break;
            case LCGPBDataTypeFixed64:
            case LCGPBDataTypeUInt64:
              [(LCGPBUInt64ObjectDictionary*)rawFieldMap enumerateKeysAndObjectsUsingBlock:^(
                  uint64_t key, id _Nonnull object, BOOL * _Nonnull stop) {
                #pragma unused(key, stop)
                [todo addObject:object];
              }];
              break;
            case LCGPBDataTypeInt64:
            case LCGPBDataTypeSFixed64:
            case LCGPBDataTypeSInt64:
              [(LCGPBInt64ObjectDictionary*)rawFieldMap enumerateKeysAndObjectsUsingBlock:^(
                  int64_t key, id _Nonnull object, BOOL * _Nonnull stop) {
                #pragma unused(key, stop)
                [todo addObject:object];
              }];
              break;
            case LCGPBDataTypeString:
              [(NSDictionary*)rawFieldMap enumerateKeysAndObjectsUsingBlock:^(
                  NSString * _Nonnull key, LCGPBMessage * _Nonnull obj, BOOL * _Nonnull stop) {
                #pragma unused(key, stop)
                [todo addObject:obj];
              }];
              break;
            case LCGPBDataTypeFloat:
            case LCGPBDataTypeDouble:
            case LCGPBDataTypeEnum:
            case LCGPBDataTypeBytes:
            case LCGPBDataTypeGroup:
            case LCGPBDataTypeMessage:
              NSCAssert(NO, @"Aren't valid key types.");
          }
          break;
        }  // switch(field.mapKeyDataType)
      }  // switch(field.fieldType)
    }  // for(fields)

    // Handle any extensions holding messages.
    for (LCGPBExtensionDescriptor *extension in [msg extensionsCurrentlySet]) {
      if (!LCGPBDataTypeIsMessage(extension.dataType)) {
        continue;
      }
      if (extension.isRepeated) {
        NSArray *extMessages = [msg getExtension:extension];
        [todo addObjectsFromArray:extMessages];
      } else {
        LCGPBMessage *extMessage = [msg getExtension:extension];
        [todo addObject:extMessage];
      }
    }  // for(extensionsCurrentlySet)

  }  // while(todo.count)
}


// -- About Version Checks --
// There's actually 3 places these checks all come into play:
// 1. When the generated source is compile into .o files, the header check
//    happens. This is checking the protoc used matches the library being used
//    when making the .o.
// 2. Every place a generated proto header is included in a developer's code,
//    the header check comes into play again. But this time it is checking that
//    the current library headers being used still support/match the ones for
//    the generated code.
// 3. At runtime the final check here (LCGPBCheckRuntimeVersionsInternal), is
//    called from the generated code passing in values captured when the
//    generated code's .o was made. This checks that at runtime the generated
//    code and runtime library match.

void LCGPBCheckRuntimeVersionSupport(int32_t objcRuntimeVersion) {
  // NOTE: This is passing the value captured in the compiled code to check
  // against the values captured when the runtime support was compiled. This
  // ensures the library code isn't in a different framework/library that
  // was generated with a non matching version.
  if (GOOGLE_PROTOBUF_OBJC_VERSION < objcRuntimeVersion) {
    // Library is too old for headers.
    [NSException raise:NSInternalInconsistencyException
                format:@"Linked to ProtocolBuffer runtime version %d,"
                       @" but code compiled needing atleast %d!",
                       GOOGLE_PROTOBUF_OBJC_VERSION, objcRuntimeVersion];
  }
  if (objcRuntimeVersion < GOOGLE_PROTOBUF_OBJC_MIN_SUPPORTED_VERSION) {
    // Headers are too old for library.
    [NSException raise:NSInternalInconsistencyException
                format:@"Proto generation source compiled against runtime"
                       @" version %d, but this version of the runtime only"
                       @" supports back to %d!",
                       objcRuntimeVersion,
                       GOOGLE_PROTOBUF_OBJC_MIN_SUPPORTED_VERSION];
  }
}

// This api is no longer used for version checks. 30001 is the last version
// using this old versioning model. When that support is removed, this function
// can be removed (along with the declaration in LCGPBUtilities_PackagePrivate.h).
void LCGPBCheckRuntimeVersionInternal(int32_t version) {
  LCGPBInternalCompileAssert(GOOGLE_PROTOBUF_OBJC_MIN_SUPPORTED_VERSION == 30001,
                           time_to_remove_this_old_version_shim);
  if (version != GOOGLE_PROTOBUF_OBJC_MIN_SUPPORTED_VERSION) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Linked to ProtocolBuffer runtime version %d,"
                       @" but code compiled with version %d!",
                       GOOGLE_PROTOBUF_OBJC_GEN_VERSION, version];
  }
}

BOOL LCGPBMessageHasFieldNumberSet(LCGPBMessage *self, uint32_t fieldNumber) {
  LCGPBDescriptor *descriptor = [self descriptor];
  LCGPBFieldDescriptor *field = [descriptor fieldWithNumber:fieldNumber];
  return LCGPBMessageHasFieldSet(self, field);
}

BOOL LCGPBMessageHasFieldSet(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
  if (self == nil || field == nil) return NO;

  // Repeated/Map don't use the bit, they check the count.
  if (LCGPBFieldIsMapOrArray(field)) {
    // Array/map type doesn't matter, since LCGPB*Array/NSArray and
    // LCGPB*Dictionary/NSDictionary all support -count;
    NSArray *arrayOrMap = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
    return (arrayOrMap.count > 0);
  } else {
    return LCGPBGetHasIvarField(self, field);
  }
}

void LCGPBClearMessageField(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
  // If not set, nothing to do.
  if (!LCGPBGetHasIvarField(self, field)) {
    return;
  }

  if (LCGPBFieldStoresObject(field)) {
    // Object types are handled slightly differently, they need to be released.
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    id *typePtr = (id *)&storage[field->description_->offset];
    [*typePtr release];
    *typePtr = nil;
  } else {
    // POD types just need to clear the has bit as the Get* method will
    // fetch the default when needed.
  }
  LCGPBSetHasIvarField(self, field, NO);
}

BOOL LCGPBGetHasIvar(LCGPBMessage *self, int32_t idx, uint32_t fieldNumber) {
  NSCAssert(self->messageStorage_ != NULL,
            @"%@: All messages should have storage (from init)",
            [self class]);
  if (idx < 0) {
    NSCAssert(fieldNumber != 0, @"Invalid field number.");
    BOOL hasIvar = (self->messageStorage_->_has_storage_[-idx] == fieldNumber);
    return hasIvar;
  } else {
    NSCAssert(idx != LCGPBNoHasBit, @"Invalid has bit.");
    uint32_t byteIndex = idx / 32;
    uint32_t bitMask = (1U << (idx % 32));
    BOOL hasIvar =
        (self->messageStorage_->_has_storage_[byteIndex] & bitMask) ? YES : NO;
    return hasIvar;
  }
}

uint32_t LCGPBGetHasOneof(LCGPBMessage *self, int32_t idx) {
  NSCAssert(idx < 0, @"%@: invalid index (%d) for oneof.",
            [self class], idx);
  uint32_t result = self->messageStorage_->_has_storage_[-idx];
  return result;
}

void LCGPBSetHasIvar(LCGPBMessage *self, int32_t idx, uint32_t fieldNumber,
                   BOOL value) {
  if (idx < 0) {
    NSCAssert(fieldNumber != 0, @"Invalid field number.");
    uint32_t *has_storage = self->messageStorage_->_has_storage_;
    has_storage[-idx] = (value ? fieldNumber : 0);
  } else {
    NSCAssert(idx != LCGPBNoHasBit, @"Invalid has bit.");
    uint32_t *has_storage = self->messageStorage_->_has_storage_;
    uint32_t byte = idx / 32;
    uint32_t bitMask = (1U << (idx % 32));
    if (value) {
      has_storage[byte] |= bitMask;
    } else {
      has_storage[byte] &= ~bitMask;
    }
  }
}

void LCGPBMaybeClearOneof(LCGPBMessage *self, LCGPBOneofDescriptor *oneof,
                        int32_t oneofHasIndex, uint32_t fieldNumberNotToClear) {
  uint32_t fieldNumberSet = LCGPBGetHasOneof(self, oneofHasIndex);
  if ((fieldNumberSet == fieldNumberNotToClear) || (fieldNumberSet == 0)) {
    // Do nothing/nothing set in the oneof.
    return;
  }

  // Like LCGPBClearMessageField(), free the memory if an objecttype is set,
  // pod types don't need to do anything.
  LCGPBFieldDescriptor *fieldSet = [oneof fieldWithNumber:fieldNumberSet];
  NSCAssert(fieldSet,
            @"%@: oneof set to something (%u) not in the oneof?",
            [self class], fieldNumberSet);
  if (fieldSet && LCGPBFieldStoresObject(fieldSet)) {
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    id *typePtr = (id *)&storage[fieldSet->description_->offset];
    [*typePtr release];
    *typePtr = nil;
  }

  // Set to nothing stored in the oneof.
  // (field number doesn't matter since setting to nothing).
  LCGPBSetHasIvar(self, oneofHasIndex, 1, NO);
}

#pragma mark - IVar accessors

//%PDDM-DEFINE IVAR_POD_ACCESSORS_DEFN(NAME, TYPE)
//%TYPE LCGPBGetMessage##NAME##Field(LCGPBMessage *self,
//% TYPE$S            NAME$S       LCGPBFieldDescriptor *field) {
//%#if defined(DEBUG) && DEBUG
//%  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
//%                                LCGPBDataType##NAME),
//%            @"Attempting to get value of TYPE from field %@ "
//%            @"of %@ which is of type %@.",
//%            [self class], field.name,
//%            TypeToString(LCGPBGetFieldDataType(field)));
//%#endif
//%  if (LCGPBGetHasIvarField(self, field)) {
//%    uint8_t *storage = (uint8_t *)self->messageStorage_;
//%    TYPE *typePtr = (TYPE *)&storage[field->description_->offset];
//%    return *typePtr;
//%  } else {
//%    return field.defaultValue.value##NAME;
//%  }
//%}
//%
//%// Only exists for public api, no core code should use this.
//%void LCGPBSetMessage##NAME##Field(LCGPBMessage *self,
//%                   NAME$S     LCGPBFieldDescriptor *field,
//%                   NAME$S     TYPE value) {
//%  if (self == nil || field == nil) return;
//%  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
//%  LCGPBSet##NAME##IvarWithFieldInternal(self, field, value, syntax);
//%}
//%
//%void LCGPBSet##NAME##IvarWithFieldInternal(LCGPBMessage *self,
//%            NAME$S                     LCGPBFieldDescriptor *field,
//%            NAME$S                     TYPE value,
//%            NAME$S                     LCGPBFileSyntax syntax) {
//%#if defined(DEBUG) && DEBUG
//%  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
//%                                LCGPBDataType##NAME),
//%            @"Attempting to set field %@ of %@ which is of type %@ with "
//%            @"value of type TYPE.",
//%            [self class], field.name,
//%            TypeToString(LCGPBGetFieldDataType(field)));
//%#endif
//%  LCGPBOneofDescriptor *oneof = field->containingOneof_;
//%  if (oneof) {
//%    LCGPBMessageFieldDescription *fieldDesc = field->description_;
//%    LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
//%  }
//%#if defined(DEBUG) && DEBUG
//%  NSCAssert(self->messageStorage_ != NULL,
//%            @"%@: All messages should have storage (from init)",
//%            [self class]);
//%#endif
//%#if defined(__clang_analyzer__)
//%  if (self->messageStorage_ == NULL) return;
//%#endif
//%  uint8_t *storage = (uint8_t *)self->messageStorage_;
//%  TYPE *typePtr = (TYPE *)&storage[field->description_->offset];
//%  *typePtr = value;
//%  // proto2: any value counts as having been set; proto3, it
//%  // has to be a non zero value or be in a oneof.
//%  BOOL hasValue = ((syntax == LCGPBFileSyntaxProto2)
//%                   || (value != (TYPE)0)
//%                   || (field->containingOneof_ != NULL));
//%  LCGPBSetHasIvarField(self, field, hasValue);
//%  LCGPBBecomeVisibleToAutocreator(self);
//%}
//%
//%PDDM-DEFINE IVAR_ALIAS_DEFN_OBJECT(NAME, TYPE)
//%// Only exists for public api, no core code should use this.
//%TYPE *LCGPBGetMessage##NAME##Field(LCGPBMessage *self,
//% TYPE$S             NAME$S       LCGPBFieldDescriptor *field) {
//%#if defined(DEBUG) && DEBUG
//%  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
//%                                LCGPBDataType##NAME),
//%            @"Attempting to get value of TYPE from field %@ "
//%            @"of %@ which is of type %@.",
//%            [self class], field.name,
//%            TypeToString(LCGPBGetFieldDataType(field)));
//%#endif
//%  return (TYPE *)LCGPBGetObjectIvarWithField(self, field);
//%}
//%
//%// Only exists for public api, no core code should use this.
//%void LCGPBSetMessage##NAME##Field(LCGPBMessage *self,
//%                   NAME$S     LCGPBFieldDescriptor *field,
//%                   NAME$S     TYPE *value) {
//%#if defined(DEBUG) && DEBUG
//%  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
//%                                LCGPBDataType##NAME),
//%            @"Attempting to set field %@ of %@ which is of type %@ with "
//%            @"value of type TYPE.",
//%            [self class], field.name,
//%            TypeToString(LCGPBGetFieldDataType(field)));
//%#endif
//%  LCGPBSetObjectIvarWithField(self, field, (id)value);
//%}
//%
//%PDDM-DEFINE IVAR_ALIAS_DEFN_COPY_OBJECT(NAME, TYPE)
//%// Only exists for public api, no core code should use this.
//%TYPE *LCGPBGetMessage##NAME##Field(LCGPBMessage *self,
//% TYPE$S             NAME$S       LCGPBFieldDescriptor *field) {
//%#if defined(DEBUG) && DEBUG
//%  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
//%                                LCGPBDataType##NAME),
//%            @"Attempting to get value of TYPE from field %@ "
//%            @"of %@ which is of type %@.",
//%            [self class], field.name,
//%            TypeToString(LCGPBGetFieldDataType(field)));
//%#endif
//%  return (TYPE *)LCGPBGetObjectIvarWithField(self, field);
//%}
//%
//%// Only exists for public api, no core code should use this.
//%void LCGPBSetMessage##NAME##Field(LCGPBMessage *self,
//%                   NAME$S     LCGPBFieldDescriptor *field,
//%                   NAME$S     TYPE *value) {
//%#if defined(DEBUG) && DEBUG
//%  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
//%                                LCGPBDataType##NAME),
//%            @"Attempting to set field %@ of %@ which is of type %@ with "
//%            @"value of type TYPE.",
//%            [self class], field.name,
//%            TypeToString(LCGPBGetFieldDataType(field)));
//%#endif
//%  LCGPBSetCopyObjectIvarWithField(self, field, (id)value);
//%}
//%

// Object types are handled slightly differently, they need to be released
// and retained.

void LCGPBSetAutocreatedRetainedObjectIvarWithField(
    LCGPBMessage *self, LCGPBFieldDescriptor *field,
    id __attribute__((ns_consumed)) value) {
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  id *typePtr = (id *)&storage[field->description_->offset];
  NSCAssert(*typePtr == NULL, @"Can't set autocreated object more than once.");
  *typePtr = value;
}

void LCGPBClearAutocreatedMessageIvarWithField(LCGPBMessage *self,
                                             LCGPBFieldDescriptor *field) {
  if (LCGPBGetHasIvarField(self, field)) {
    return;
  }
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  id *typePtr = (id *)&storage[field->description_->offset];
  LCGPBMessage *oldValue = *typePtr;
  *typePtr = NULL;
  LCGPBClearMessageAutocreator(oldValue);
  [oldValue release];
}

// This exists only for briging some aliased types, nothing else should use it.
static void LCGPBSetObjectIvarWithField(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field, id value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, [value retain],
                                            syntax);
}

static void LCGPBSetCopyObjectIvarWithField(LCGPBMessage *self,
                                          LCGPBFieldDescriptor *field, id value);

// LCGPBSetCopyObjectIvarWithField is blocked from the analyzer because it flags
// a leak for the -copy even though LCGPBSetRetainedObjectIvarWithFieldInternal
// is marked as consuming the value. Note: For some reason this doesn't happen
// with the -retain in LCGPBSetObjectIvarWithField.
#if !defined(__clang_analyzer__)
// This exists only for briging some aliased types, nothing else should use it.
static void LCGPBSetCopyObjectIvarWithField(LCGPBMessage *self,
                                          LCGPBFieldDescriptor *field, id value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, [value copy],
                                            syntax);
}
#endif  // !defined(__clang_analyzer__)

void LCGPBSetObjectIvarWithFieldInternal(LCGPBMessage *self,
                                       LCGPBFieldDescriptor *field, id value,
                                       LCGPBFileSyntax syntax) {
  LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, [value retain],
                                            syntax);
}

void LCGPBSetRetainedObjectIvarWithFieldInternal(LCGPBMessage *self,
                                               LCGPBFieldDescriptor *field,
                                               id value, LCGPBFileSyntax syntax) {
  NSCAssert(self->messageStorage_ != NULL,
            @"%@: All messages should have storage (from init)",
            [self class]);
#if defined(__clang_analyzer__)
  if (self->messageStorage_ == NULL) return;
#endif
  LCGPBDataType fieldType = LCGPBGetFieldDataType(field);
  BOOL isMapOrArray = LCGPBFieldIsMapOrArray(field);
  BOOL fieldIsMessage = LCGPBDataTypeIsMessage(fieldType);
#if defined(DEBUG) && DEBUG
  if (value == nil && !isMapOrArray && !fieldIsMessage &&
      field.hasDefaultValue) {
    // Setting a message to nil is an obvious way to "clear" the value
    // as there is no way to set a non-empty default value for messages.
    //
    // For Strings and Bytes that have default values set it is not clear what
    // should be done when their value is set to nil. Is the intention just to
    // clear the set value and reset to default, or is the intention to set the
    // value to the empty string/data? Arguments can be made for both cases.
    // 'nil' has been abused as a replacement for an empty string/data in ObjC.
    // We decided to be consistent with all "object" types and clear the has
    // field, and fall back on the default value. The warning below will only
    // appear in debug, but the could should be changed so the intention is
    // clear.
    NSString *hasSel = NSStringFromSelector(field->hasOrCountSel_);
    NSString *propName = field.name;
    NSString *className = self.descriptor.name;
    NSLog(@"warning: '%@.%@ = nil;' is not clearly defined for fields with "
          @"default values. Please use '%@.%@ = %@' if you want to set it to "
          @"empty, or call '%@.%@ = NO' to reset it to it's default value of "
          @"'%@'. Defaulting to resetting default value.",
          className, propName, className, propName,
          (fieldType == LCGPBDataTypeString) ? @"@\"\"" : @"LCGPBEmptyNSData()",
          className, hasSel, field.defaultValue.valueString);
    // Note: valueString, depending on the type, it could easily be
    // valueData/valueMessage.
  }
#endif  // DEBUG
  if (!isMapOrArray) {
    // Non repeated/map can be in an oneof, clear any existing value from the
    // oneof.
    LCGPBOneofDescriptor *oneof = field->containingOneof_;
    if (oneof) {
      LCGPBMessageFieldDescription *fieldDesc = field->description_;
      LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
    }
    // Clear "has" if they are being set to nil.
    BOOL setHasValue = (value != nil);
    // Under proto3, Bytes & String fields get cleared by resetting them to
    // their default (empty) values, so if they are set to something of length
    // zero, they are being cleared.
    if ((syntax == LCGPBFileSyntaxProto3) && !fieldIsMessage &&
        ([value length] == 0)) {
      // Except, if the field was in a oneof, then it still gets recorded as
      // having been set so the state of the oneof can be serialized back out.
      if (!oneof) {
        setHasValue = NO;
      }
      if (setHasValue) {
        NSCAssert(value != nil, @"Should never be setting has for nil");
      } else {
        // The value passed in was retained, it must be released since we
        // aren't saving anything in the field.
        [value release];
        value = nil;
      }
    }
    LCGPBSetHasIvarField(self, field, setHasValue);
  }
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  id *typePtr = (id *)&storage[field->description_->offset];

  id oldValue = *typePtr;

  *typePtr = value;

  if (oldValue) {
    if (isMapOrArray) {
      if (field.fieldType == LCGPBFieldTypeRepeated) {
        // If the old array was autocreated by us, then clear it.
        if (LCGPBDataTypeIsObject(fieldType)) {
          if ([oldValue isKindOfClass:[LCGPBAutocreatedArray class]]) {
            LCGPBAutocreatedArray *autoArray = oldValue;
            if (autoArray->_autocreator == self) {
              autoArray->_autocreator = nil;
            }
          }
        } else {
          // Type doesn't matter, it is a LCGPB*Array.
          LCGPBInt32Array *gpbArray = oldValue;
          if (gpbArray->_autocreator == self) {
            gpbArray->_autocreator = nil;
          }
        }
      } else { // LCGPBFieldTypeMap
        // If the old map was autocreated by us, then clear it.
        if ((field.mapKeyDataType == LCGPBDataTypeString) &&
            LCGPBDataTypeIsObject(fieldType)) {
          if ([oldValue isKindOfClass:[LCGPBAutocreatedDictionary class]]) {
            LCGPBAutocreatedDictionary *autoDict = oldValue;
            if (autoDict->_autocreator == self) {
              autoDict->_autocreator = nil;
            }
          }
        } else {
          // Type doesn't matter, it is a LCGPB*Dictionary.
          LCGPBInt32Int32Dictionary *gpbDict = oldValue;
          if (gpbDict->_autocreator == self) {
            gpbDict->_autocreator = nil;
          }
        }
      }
    } else if (fieldIsMessage) {
      // If the old message value was autocreated by us, then clear it.
      LCGPBMessage *oldMessageValue = oldValue;
      if (LCGPBWasMessageAutocreatedBy(oldMessageValue, self)) {
        LCGPBClearMessageAutocreator(oldMessageValue);
      }
    }
    [oldValue release];
  }

  LCGPBBecomeVisibleToAutocreator(self);
}

id LCGPBGetObjectIvarWithFieldNoAutocreate(LCGPBMessage *self,
                                         LCGPBFieldDescriptor *field) {
  if (self->messageStorage_ == nil) {
    return nil;
  }
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  id *typePtr = (id *)&storage[field->description_->offset];
  return *typePtr;
}

// Only exists for public api, no core code should use this.
int32_t LCGPBGetMessageEnumField(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  return LCGPBGetEnumIvarWithFieldInternal(self, field, syntax);
}

int32_t LCGPBGetEnumIvarWithFieldInternal(LCGPBMessage *self,
                                        LCGPBFieldDescriptor *field,
                                        LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(LCGPBGetFieldDataType(field) == LCGPBDataTypeEnum,
            @"Attempting to get value of type Enum from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  int32_t result = LCGPBGetMessageInt32Field(self, field);
  // If this is presevering unknown enums, make sure the value is valid before
  // returning it.
  if (LCGPBHasPreservingUnknownEnumSemantics(syntax) &&
      ![field isValidEnumValue:result]) {
    result = kLCGPBUnrecognizedEnumeratorValue;
  }
  return result;
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageEnumField(LCGPBMessage *self, LCGPBFieldDescriptor *field,
                            int32_t value) {
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetInt32IvarWithFieldInternal(self, field, value, syntax);
}

void LCGPBSetEnumIvarWithFieldInternal(LCGPBMessage *self,
                                     LCGPBFieldDescriptor *field, int32_t value,
                                     LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(LCGPBGetFieldDataType(field) == LCGPBDataTypeEnum,
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type Enum.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  // Don't allow in unknown values.  Proto3 can use the Raw method.
  if (![field isValidEnumValue:value]) {
    [NSException raise:NSInvalidArgumentException
                format:@"%@.%@: Attempt to set an unknown enum value (%d)",
                       [self class], field.name, value];
  }
  LCGPBSetInt32IvarWithFieldInternal(self, field, value, syntax);
}

// Only exists for public api, no core code should use this.
int32_t LCGPBGetMessageRawEnumField(LCGPBMessage *self,
                                  LCGPBFieldDescriptor *field) {
  int32_t result = LCGPBGetMessageInt32Field(self, field);
  return result;
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageRawEnumField(LCGPBMessage *self, LCGPBFieldDescriptor *field,
                               int32_t value) {
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetInt32IvarWithFieldInternal(self, field, value, syntax);
}

BOOL LCGPBGetMessageBoolField(LCGPBMessage *self,
                            LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field), LCGPBDataTypeBool),
            @"Attempting to get value of type bool from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  if (LCGPBGetHasIvarField(self, field)) {
    // Bools are stored in the has bits to avoid needing explicit space in the
    // storage structure.
    // (the field number passed to the HasIvar helper doesn't really matter
    // since the offset is never negative)
    LCGPBMessageFieldDescription *fieldDesc = field->description_;
    return LCGPBGetHasIvar(self, (int32_t)(fieldDesc->offset), fieldDesc->number);
  } else {
    return field.defaultValue.valueBool;
  }
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageBoolField(LCGPBMessage *self,
                            LCGPBFieldDescriptor *field,
                            BOOL value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetBoolIvarWithFieldInternal(self, field, value, syntax);
}

void LCGPBSetBoolIvarWithFieldInternal(LCGPBMessage *self,
                                     LCGPBFieldDescriptor *field,
                                     BOOL value,
                                     LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field), LCGPBDataTypeBool),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type bool.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBMessageFieldDescription *fieldDesc = field->description_;
  LCGPBOneofDescriptor *oneof = field->containingOneof_;
  if (oneof) {
    LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
  }

  // Bools are stored in the has bits to avoid needing explicit space in the
  // storage structure.
  // (the field number passed to the HasIvar helper doesn't really matter since
  // the offset is never negative)
  LCGPBSetHasIvar(self, (int32_t)(fieldDesc->offset), fieldDesc->number, value);

  // proto2: any value counts as having been set; proto3, it
  // has to be a non zero value or be in a oneof.
  BOOL hasValue = ((syntax == LCGPBFileSyntaxProto2)
                   || (value != (BOOL)0)
                   || (field->containingOneof_ != NULL));
  LCGPBSetHasIvarField(self, field, hasValue);
  LCGPBBecomeVisibleToAutocreator(self);
}

//%PDDM-EXPAND IVAR_POD_ACCESSORS_DEFN(Int32, int32_t)
// This block of code is generated, do not edit it directly.

int32_t LCGPBGetMessageInt32Field(LCGPBMessage *self,
                                LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeInt32),
            @"Attempting to get value of int32_t from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  if (LCGPBGetHasIvarField(self, field)) {
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    int32_t *typePtr = (int32_t *)&storage[field->description_->offset];
    return *typePtr;
  } else {
    return field.defaultValue.valueInt32;
  }
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageInt32Field(LCGPBMessage *self,
                             LCGPBFieldDescriptor *field,
                             int32_t value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetInt32IvarWithFieldInternal(self, field, value, syntax);
}

void LCGPBSetInt32IvarWithFieldInternal(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field,
                                      int32_t value,
                                      LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeInt32),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type int32_t.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBOneofDescriptor *oneof = field->containingOneof_;
  if (oneof) {
    LCGPBMessageFieldDescription *fieldDesc = field->description_;
    LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
  }
#if defined(DEBUG) && DEBUG
  NSCAssert(self->messageStorage_ != NULL,
            @"%@: All messages should have storage (from init)",
            [self class]);
#endif
#if defined(__clang_analyzer__)
  if (self->messageStorage_ == NULL) return;
#endif
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  int32_t *typePtr = (int32_t *)&storage[field->description_->offset];
  *typePtr = value;
  // proto2: any value counts as having been set; proto3, it
  // has to be a non zero value or be in a oneof.
  BOOL hasValue = ((syntax == LCGPBFileSyntaxProto2)
                   || (value != (int32_t)0)
                   || (field->containingOneof_ != NULL));
  LCGPBSetHasIvarField(self, field, hasValue);
  LCGPBBecomeVisibleToAutocreator(self);
}

//%PDDM-EXPAND IVAR_POD_ACCESSORS_DEFN(UInt32, uint32_t)
// This block of code is generated, do not edit it directly.

uint32_t LCGPBGetMessageUInt32Field(LCGPBMessage *self,
                                  LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeUInt32),
            @"Attempting to get value of uint32_t from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  if (LCGPBGetHasIvarField(self, field)) {
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    uint32_t *typePtr = (uint32_t *)&storage[field->description_->offset];
    return *typePtr;
  } else {
    return field.defaultValue.valueUInt32;
  }
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageUInt32Field(LCGPBMessage *self,
                              LCGPBFieldDescriptor *field,
                              uint32_t value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetUInt32IvarWithFieldInternal(self, field, value, syntax);
}

void LCGPBSetUInt32IvarWithFieldInternal(LCGPBMessage *self,
                                       LCGPBFieldDescriptor *field,
                                       uint32_t value,
                                       LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeUInt32),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type uint32_t.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBOneofDescriptor *oneof = field->containingOneof_;
  if (oneof) {
    LCGPBMessageFieldDescription *fieldDesc = field->description_;
    LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
  }
#if defined(DEBUG) && DEBUG
  NSCAssert(self->messageStorage_ != NULL,
            @"%@: All messages should have storage (from init)",
            [self class]);
#endif
#if defined(__clang_analyzer__)
  if (self->messageStorage_ == NULL) return;
#endif
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  uint32_t *typePtr = (uint32_t *)&storage[field->description_->offset];
  *typePtr = value;
  // proto2: any value counts as having been set; proto3, it
  // has to be a non zero value or be in a oneof.
  BOOL hasValue = ((syntax == LCGPBFileSyntaxProto2)
                   || (value != (uint32_t)0)
                   || (field->containingOneof_ != NULL));
  LCGPBSetHasIvarField(self, field, hasValue);
  LCGPBBecomeVisibleToAutocreator(self);
}

//%PDDM-EXPAND IVAR_POD_ACCESSORS_DEFN(Int64, int64_t)
// This block of code is generated, do not edit it directly.

int64_t LCGPBGetMessageInt64Field(LCGPBMessage *self,
                                LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeInt64),
            @"Attempting to get value of int64_t from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  if (LCGPBGetHasIvarField(self, field)) {
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    int64_t *typePtr = (int64_t *)&storage[field->description_->offset];
    return *typePtr;
  } else {
    return field.defaultValue.valueInt64;
  }
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageInt64Field(LCGPBMessage *self,
                             LCGPBFieldDescriptor *field,
                             int64_t value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetInt64IvarWithFieldInternal(self, field, value, syntax);
}

void LCGPBSetInt64IvarWithFieldInternal(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field,
                                      int64_t value,
                                      LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeInt64),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type int64_t.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBOneofDescriptor *oneof = field->containingOneof_;
  if (oneof) {
    LCGPBMessageFieldDescription *fieldDesc = field->description_;
    LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
  }
#if defined(DEBUG) && DEBUG
  NSCAssert(self->messageStorage_ != NULL,
            @"%@: All messages should have storage (from init)",
            [self class]);
#endif
#if defined(__clang_analyzer__)
  if (self->messageStorage_ == NULL) return;
#endif
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  int64_t *typePtr = (int64_t *)&storage[field->description_->offset];
  *typePtr = value;
  // proto2: any value counts as having been set; proto3, it
  // has to be a non zero value or be in a oneof.
  BOOL hasValue = ((syntax == LCGPBFileSyntaxProto2)
                   || (value != (int64_t)0)
                   || (field->containingOneof_ != NULL));
  LCGPBSetHasIvarField(self, field, hasValue);
  LCGPBBecomeVisibleToAutocreator(self);
}

//%PDDM-EXPAND IVAR_POD_ACCESSORS_DEFN(UInt64, uint64_t)
// This block of code is generated, do not edit it directly.

uint64_t LCGPBGetMessageUInt64Field(LCGPBMessage *self,
                                  LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeUInt64),
            @"Attempting to get value of uint64_t from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  if (LCGPBGetHasIvarField(self, field)) {
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    uint64_t *typePtr = (uint64_t *)&storage[field->description_->offset];
    return *typePtr;
  } else {
    return field.defaultValue.valueUInt64;
  }
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageUInt64Field(LCGPBMessage *self,
                              LCGPBFieldDescriptor *field,
                              uint64_t value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetUInt64IvarWithFieldInternal(self, field, value, syntax);
}

void LCGPBSetUInt64IvarWithFieldInternal(LCGPBMessage *self,
                                       LCGPBFieldDescriptor *field,
                                       uint64_t value,
                                       LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeUInt64),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type uint64_t.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBOneofDescriptor *oneof = field->containingOneof_;
  if (oneof) {
    LCGPBMessageFieldDescription *fieldDesc = field->description_;
    LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
  }
#if defined(DEBUG) && DEBUG
  NSCAssert(self->messageStorage_ != NULL,
            @"%@: All messages should have storage (from init)",
            [self class]);
#endif
#if defined(__clang_analyzer__)
  if (self->messageStorage_ == NULL) return;
#endif
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  uint64_t *typePtr = (uint64_t *)&storage[field->description_->offset];
  *typePtr = value;
  // proto2: any value counts as having been set; proto3, it
  // has to be a non zero value or be in a oneof.
  BOOL hasValue = ((syntax == LCGPBFileSyntaxProto2)
                   || (value != (uint64_t)0)
                   || (field->containingOneof_ != NULL));
  LCGPBSetHasIvarField(self, field, hasValue);
  LCGPBBecomeVisibleToAutocreator(self);
}

//%PDDM-EXPAND IVAR_POD_ACCESSORS_DEFN(Float, float)
// This block of code is generated, do not edit it directly.

float LCGPBGetMessageFloatField(LCGPBMessage *self,
                              LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeFloat),
            @"Attempting to get value of float from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  if (LCGPBGetHasIvarField(self, field)) {
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    float *typePtr = (float *)&storage[field->description_->offset];
    return *typePtr;
  } else {
    return field.defaultValue.valueFloat;
  }
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageFloatField(LCGPBMessage *self,
                             LCGPBFieldDescriptor *field,
                             float value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetFloatIvarWithFieldInternal(self, field, value, syntax);
}

void LCGPBSetFloatIvarWithFieldInternal(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field,
                                      float value,
                                      LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeFloat),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type float.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBOneofDescriptor *oneof = field->containingOneof_;
  if (oneof) {
    LCGPBMessageFieldDescription *fieldDesc = field->description_;
    LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
  }
#if defined(DEBUG) && DEBUG
  NSCAssert(self->messageStorage_ != NULL,
            @"%@: All messages should have storage (from init)",
            [self class]);
#endif
#if defined(__clang_analyzer__)
  if (self->messageStorage_ == NULL) return;
#endif
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  float *typePtr = (float *)&storage[field->description_->offset];
  *typePtr = value;
  // proto2: any value counts as having been set; proto3, it
  // has to be a non zero value or be in a oneof.
  BOOL hasValue = ((syntax == LCGPBFileSyntaxProto2)
                   || (value != (float)0)
                   || (field->containingOneof_ != NULL));
  LCGPBSetHasIvarField(self, field, hasValue);
  LCGPBBecomeVisibleToAutocreator(self);
}

//%PDDM-EXPAND IVAR_POD_ACCESSORS_DEFN(Double, double)
// This block of code is generated, do not edit it directly.

double LCGPBGetMessageDoubleField(LCGPBMessage *self,
                                LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeDouble),
            @"Attempting to get value of double from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  if (LCGPBGetHasIvarField(self, field)) {
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    double *typePtr = (double *)&storage[field->description_->offset];
    return *typePtr;
  } else {
    return field.defaultValue.valueDouble;
  }
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageDoubleField(LCGPBMessage *self,
                              LCGPBFieldDescriptor *field,
                              double value) {
  if (self == nil || field == nil) return;
  LCGPBFileSyntax syntax = [self descriptor].file.syntax;
  LCGPBSetDoubleIvarWithFieldInternal(self, field, value, syntax);
}

void LCGPBSetDoubleIvarWithFieldInternal(LCGPBMessage *self,
                                       LCGPBFieldDescriptor *field,
                                       double value,
                                       LCGPBFileSyntax syntax) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeDouble),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type double.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBOneofDescriptor *oneof = field->containingOneof_;
  if (oneof) {
    LCGPBMessageFieldDescription *fieldDesc = field->description_;
    LCGPBMaybeClearOneof(self, oneof, fieldDesc->hasIndex, fieldDesc->number);
  }
#if defined(DEBUG) && DEBUG
  NSCAssert(self->messageStorage_ != NULL,
            @"%@: All messages should have storage (from init)",
            [self class]);
#endif
#if defined(__clang_analyzer__)
  if (self->messageStorage_ == NULL) return;
#endif
  uint8_t *storage = (uint8_t *)self->messageStorage_;
  double *typePtr = (double *)&storage[field->description_->offset];
  *typePtr = value;
  // proto2: any value counts as having been set; proto3, it
  // has to be a non zero value or be in a oneof.
  BOOL hasValue = ((syntax == LCGPBFileSyntaxProto2)
                   || (value != (double)0)
                   || (field->containingOneof_ != NULL));
  LCGPBSetHasIvarField(self, field, hasValue);
  LCGPBBecomeVisibleToAutocreator(self);
}

//%PDDM-EXPAND-END (6 expansions)

// Aliases are function calls that are virtually the same.

//%PDDM-EXPAND IVAR_ALIAS_DEFN_COPY_OBJECT(String, NSString)
// This block of code is generated, do not edit it directly.

// Only exists for public api, no core code should use this.
NSString *LCGPBGetMessageStringField(LCGPBMessage *self,
                                   LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeString),
            @"Attempting to get value of NSString from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  return (NSString *)LCGPBGetObjectIvarWithField(self, field);
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageStringField(LCGPBMessage *self,
                              LCGPBFieldDescriptor *field,
                              NSString *value) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeString),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type NSString.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBSetCopyObjectIvarWithField(self, field, (id)value);
}

//%PDDM-EXPAND IVAR_ALIAS_DEFN_COPY_OBJECT(Bytes, NSData)
// This block of code is generated, do not edit it directly.

// Only exists for public api, no core code should use this.
NSData *LCGPBGetMessageBytesField(LCGPBMessage *self,
                                LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeBytes),
            @"Attempting to get value of NSData from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  return (NSData *)LCGPBGetObjectIvarWithField(self, field);
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageBytesField(LCGPBMessage *self,
                             LCGPBFieldDescriptor *field,
                             NSData *value) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeBytes),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type NSData.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBSetCopyObjectIvarWithField(self, field, (id)value);
}

//%PDDM-EXPAND IVAR_ALIAS_DEFN_OBJECT(Message, LCGPBMessage)
// This block of code is generated, do not edit it directly.

// Only exists for public api, no core code should use this.
LCGPBMessage *LCGPBGetMessageMessageField(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeMessage),
            @"Attempting to get value of LCGPBMessage from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  return (LCGPBMessage *)LCGPBGetObjectIvarWithField(self, field);
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageMessageField(LCGPBMessage *self,
                               LCGPBFieldDescriptor *field,
                               LCGPBMessage *value) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeMessage),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type LCGPBMessage.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBSetObjectIvarWithField(self, field, (id)value);
}

//%PDDM-EXPAND IVAR_ALIAS_DEFN_OBJECT(Group, LCGPBMessage)
// This block of code is generated, do not edit it directly.

// Only exists for public api, no core code should use this.
LCGPBMessage *LCGPBGetMessageGroupField(LCGPBMessage *self,
                                    LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeGroup),
            @"Attempting to get value of LCGPBMessage from field %@ "
            @"of %@ which is of type %@.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  return (LCGPBMessage *)LCGPBGetObjectIvarWithField(self, field);
}

// Only exists for public api, no core code should use this.
void LCGPBSetMessageGroupField(LCGPBMessage *self,
                             LCGPBFieldDescriptor *field,
                             LCGPBMessage *value) {
#if defined(DEBUG) && DEBUG
  NSCAssert(DataTypesEquivalent(LCGPBGetFieldDataType(field),
                                LCGPBDataTypeGroup),
            @"Attempting to set field %@ of %@ which is of type %@ with "
            @"value of type LCGPBMessage.",
            [self class], field.name,
            TypeToString(LCGPBGetFieldDataType(field)));
#endif
  LCGPBSetObjectIvarWithField(self, field, (id)value);
}

//%PDDM-EXPAND-END (4 expansions)

// LCGPBGetMessageRepeatedField is defined in LCGPBMessage.m

// Only exists for public api, no core code should use this.
void LCGPBSetMessageRepeatedField(LCGPBMessage *self, LCGPBFieldDescriptor *field, id array) {
#if defined(DEBUG) && DEBUG
  if (field.fieldType != LCGPBFieldTypeRepeated) {
    [NSException raise:NSInvalidArgumentException
                format:@"%@.%@ is not a repeated field.",
                       [self class], field.name];
  }
  Class expectedClass = Nil;
  switch (LCGPBGetFieldDataType(field)) {
    case LCGPBDataTypeBool:
      expectedClass = [LCGPBBoolArray class];
      break;
    case LCGPBDataTypeSFixed32:
    case LCGPBDataTypeInt32:
    case LCGPBDataTypeSInt32:
      expectedClass = [LCGPBInt32Array class];
      break;
    case LCGPBDataTypeFixed32:
    case LCGPBDataTypeUInt32:
      expectedClass = [LCGPBUInt32Array class];
      break;
    case LCGPBDataTypeSFixed64:
    case LCGPBDataTypeInt64:
    case LCGPBDataTypeSInt64:
      expectedClass = [LCGPBInt64Array class];
      break;
    case LCGPBDataTypeFixed64:
    case LCGPBDataTypeUInt64:
      expectedClass = [LCGPBUInt64Array class];
      break;
    case LCGPBDataTypeFloat:
      expectedClass = [LCGPBFloatArray class];
      break;
    case LCGPBDataTypeDouble:
      expectedClass = [LCGPBDoubleArray class];
      break;
    case LCGPBDataTypeBytes:
    case LCGPBDataTypeString:
    case LCGPBDataTypeMessage:
    case LCGPBDataTypeGroup:
      expectedClass = [NSMutableArray class];
      break;
    case LCGPBDataTypeEnum:
      expectedClass = [LCGPBEnumArray class];
      break;
  }
  if (array && ![array isKindOfClass:expectedClass]) {
    [NSException raise:NSInvalidArgumentException
                format:@"%@.%@: Expected %@ object, got %@.",
                       [self class], field.name, expectedClass, [array class]];
  }
#endif
  LCGPBSetObjectIvarWithField(self, field, array);
}

static LCGPBDataType BaseDataType(LCGPBDataType type) {
  switch (type) {
    case LCGPBDataTypeSFixed32:
    case LCGPBDataTypeInt32:
    case LCGPBDataTypeSInt32:
    case LCGPBDataTypeEnum:
      return LCGPBDataTypeInt32;
    case LCGPBDataTypeFixed32:
    case LCGPBDataTypeUInt32:
      return LCGPBDataTypeUInt32;
    case LCGPBDataTypeSFixed64:
    case LCGPBDataTypeInt64:
    case LCGPBDataTypeSInt64:
      return LCGPBDataTypeInt64;
    case LCGPBDataTypeFixed64:
    case LCGPBDataTypeUInt64:
      return LCGPBDataTypeUInt64;
    case LCGPBDataTypeMessage:
    case LCGPBDataTypeGroup:
      return LCGPBDataTypeMessage;
    case LCGPBDataTypeBool:
    case LCGPBDataTypeFloat:
    case LCGPBDataTypeDouble:
    case LCGPBDataTypeBytes:
    case LCGPBDataTypeString:
      return type;
   }
}

static BOOL DataTypesEquivalent(LCGPBDataType type1, LCGPBDataType type2) {
  return BaseDataType(type1) == BaseDataType(type2);
}

static NSString *TypeToString(LCGPBDataType dataType) {
  switch (dataType) {
    case LCGPBDataTypeBool:
      return @"Bool";
    case LCGPBDataTypeSFixed32:
    case LCGPBDataTypeInt32:
    case LCGPBDataTypeSInt32:
      return @"Int32";
    case LCGPBDataTypeFixed32:
    case LCGPBDataTypeUInt32:
      return @"UInt32";
    case LCGPBDataTypeSFixed64:
    case LCGPBDataTypeInt64:
    case LCGPBDataTypeSInt64:
      return @"Int64";
    case LCGPBDataTypeFixed64:
    case LCGPBDataTypeUInt64:
      return @"UInt64";
    case LCGPBDataTypeFloat:
      return @"Float";
    case LCGPBDataTypeDouble:
      return @"Double";
    case LCGPBDataTypeBytes:
    case LCGPBDataTypeString:
    case LCGPBDataTypeMessage:
    case LCGPBDataTypeGroup:
      return @"Object";
    case LCGPBDataTypeEnum:
      return @"Enum";
  }
}

// LCGPBGetMessageMapField is defined in LCGPBMessage.m

// Only exists for public api, no core code should use this.
void LCGPBSetMessageMapField(LCGPBMessage *self, LCGPBFieldDescriptor *field,
                           id dictionary) {
#if defined(DEBUG) && DEBUG
  if (field.fieldType != LCGPBFieldTypeMap) {
    [NSException raise:NSInvalidArgumentException
                format:@"%@.%@ is not a map<> field.",
                       [self class], field.name];
  }
  if (dictionary) {
    LCGPBDataType keyDataType = field.mapKeyDataType;
    LCGPBDataType valueDataType = LCGPBGetFieldDataType(field);
    NSString *keyStr = TypeToString(keyDataType);
    NSString *valueStr = TypeToString(valueDataType);
    if (keyDataType == LCGPBDataTypeString) {
      keyStr = @"String";
    }
    Class expectedClass = Nil;
    if ((keyDataType == LCGPBDataTypeString) &&
        LCGPBDataTypeIsObject(valueDataType)) {
      expectedClass = [NSMutableDictionary class];
    } else {
      NSString *className =
          [NSString stringWithFormat:@"LCGPB%@%@Dictionary", keyStr, valueStr];
      expectedClass = NSClassFromString(className);
      NSCAssert(expectedClass, @"Missing a class (%@)?", expectedClass);
    }
    if (![dictionary isKindOfClass:expectedClass]) {
      [NSException raise:NSInvalidArgumentException
                  format:@"%@.%@: Expected %@ object, got %@.",
                         [self class], field.name, expectedClass,
                         [dictionary class]];
    }
  }
#endif
  LCGPBSetObjectIvarWithField(self, field, dictionary);
}

#pragma mark - Misc Dynamic Runtime Utils

const char *LCGPBMessageEncodingForSelector(SEL selector, BOOL instanceSel) {
  Protocol *protocol =
      objc_getProtocol(LCGPBStringifySymbol(LCGPBMessageSignatureProtocol));
  NSCAssert(protocol, @"Missing LCGPBMessageSignatureProtocol");
  struct objc_method_description description =
      protocol_getMethodDescription(protocol, selector, NO, instanceSel);
  NSCAssert(description.name != Nil && description.types != nil,
            @"Missing method for selector %@", NSStringFromSelector(selector));
  return description.types;
}

#pragma mark - Text Format Support

static void AppendStringEscaped(NSString *toPrint, NSMutableString *destStr) {
  [destStr appendString:@"\""];
  NSUInteger len = [toPrint length];
  for (NSUInteger i = 0; i < len; ++i) {
    unichar aChar = [toPrint characterAtIndex:i];
    switch (aChar) {
      case '\n': [destStr appendString:@"\\n"];  break;
      case '\r': [destStr appendString:@"\\r"];  break;
      case '\t': [destStr appendString:@"\\t"];  break;
      case '\"': [destStr appendString:@"\\\""]; break;
      case '\'': [destStr appendString:@"\\\'"]; break;
      case '\\': [destStr appendString:@"\\\\"]; break;
      default:
        // This differs slightly from the C++ code in that the C++ doesn't
        // generate UTF8; it looks at the string in UTF8, but escapes every
        // byte > 0x7E.
        if (aChar < 0x20) {
          [destStr appendFormat:@"\\%d%d%d",
                                (aChar / 64), ((aChar % 64) / 8), (aChar % 8)];
        } else {
          [destStr appendFormat:@"%C", aChar];
        }
        break;
    }
  }
  [destStr appendString:@"\""];
}

static void AppendBufferAsString(NSData *buffer, NSMutableString *destStr) {
  const char *src = (const char *)[buffer bytes];
  size_t srcLen = [buffer length];
  [destStr appendString:@"\""];
  for (const char *srcEnd = src + srcLen; src < srcEnd; src++) {
    switch (*src) {
      case '\n': [destStr appendString:@"\\n"];  break;
      case '\r': [destStr appendString:@"\\r"];  break;
      case '\t': [destStr appendString:@"\\t"];  break;
      case '\"': [destStr appendString:@"\\\""]; break;
      case '\'': [destStr appendString:@"\\\'"]; break;
      case '\\': [destStr appendString:@"\\\\"]; break;
      default:
        if (isprint(*src)) {
          [destStr appendFormat:@"%c", *src];
        } else {
          // NOTE: doing hex means you have to worry about the letter after
          // the hex being another hex char and forcing that to be escaped, so
          // use octal to keep it simple.
          [destStr appendFormat:@"\\%03o", (uint8_t)(*src)];
        }
        break;
    }
  }
  [destStr appendString:@"\""];
}

static void AppendTextFormatForMapMessageField(
    id map, LCGPBFieldDescriptor *field, NSMutableString *toStr,
    NSString *lineIndent, NSString *fieldName, NSString *lineEnding) {
  LCGPBDataType keyDataType = field.mapKeyDataType;
  LCGPBDataType valueDataType = LCGPBGetFieldDataType(field);
  BOOL isMessageValue = LCGPBDataTypeIsMessage(valueDataType);

  NSString *msgStartFirst =
      [NSString stringWithFormat:@"%@%@ {%@\n", lineIndent, fieldName, lineEnding];
  NSString *msgStart =
      [NSString stringWithFormat:@"%@%@ {\n", lineIndent, fieldName];
  NSString *msgEnd = [NSString stringWithFormat:@"%@}\n", lineIndent];

  NSString *keyLine = [NSString stringWithFormat:@"%@  key: ", lineIndent];
  NSString *valueLine = [NSString stringWithFormat:@"%@  value%s ", lineIndent,
                                                   (isMessageValue ? "" : ":")];

  __block BOOL isFirst = YES;

  if ((keyDataType == LCGPBDataTypeString) &&
      LCGPBDataTypeIsObject(valueDataType)) {
    // map is an NSDictionary.
    NSDictionary *dict = map;
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
      #pragma unused(stop)
      [toStr appendString:(isFirst ? msgStartFirst : msgStart)];
      isFirst = NO;

      [toStr appendString:keyLine];
      AppendStringEscaped(key, toStr);
      [toStr appendString:@"\n"];

      [toStr appendString:valueLine];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
      switch (valueDataType) {
        case LCGPBDataTypeString:
          AppendStringEscaped(value, toStr);
          break;

        case LCGPBDataTypeBytes:
          AppendBufferAsString(value, toStr);
          break;

        case LCGPBDataTypeMessage:
          [toStr appendString:@"{\n"];
          NSString *subIndent = [lineIndent stringByAppendingString:@"    "];
          AppendTextFormatForMessage(value, toStr, subIndent);
          [toStr appendFormat:@"%@  }", lineIndent];
          break;

        default:
          NSCAssert(NO, @"Can't happen");
          break;
      }
#pragma clang diagnostic pop
      [toStr appendString:@"\n"];

      [toStr appendString:msgEnd];
    }];
  } else {
    // map is one of the LCGPB*Dictionary classes, type doesn't matter.
    LCGPBInt32Int32Dictionary *dict = map;
    [dict enumerateForTextFormat:^(id keyObj, id valueObj) {
      [toStr appendString:(isFirst ? msgStartFirst : msgStart)];
      isFirst = NO;

      // Key always is a NSString.
      if (keyDataType == LCGPBDataTypeString) {
        [toStr appendString:keyLine];
        AppendStringEscaped(keyObj, toStr);
        [toStr appendString:@"\n"];
      } else {
        [toStr appendFormat:@"%@%@\n", keyLine, keyObj];
      }

      [toStr appendString:valueLine];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
      switch (valueDataType) {
        case LCGPBDataTypeString:
          AppendStringEscaped(valueObj, toStr);
          break;

        case LCGPBDataTypeBytes:
          AppendBufferAsString(valueObj, toStr);
          break;

        case LCGPBDataTypeMessage:
          [toStr appendString:@"{\n"];
          NSString *subIndent = [lineIndent stringByAppendingString:@"    "];
          AppendTextFormatForMessage(valueObj, toStr, subIndent);
          [toStr appendFormat:@"%@  }", lineIndent];
          break;

        case LCGPBDataTypeEnum: {
          int32_t enumValue = [valueObj intValue];
          NSString *valueStr = nil;
          LCGPBEnumDescriptor *descriptor = field.enumDescriptor;
          if (descriptor) {
            valueStr = [descriptor textFormatNameForValue:enumValue];
          }
          if (valueStr) {
            [toStr appendString:valueStr];
          } else {
            [toStr appendFormat:@"%d", enumValue];
          }
          break;
        }

        default:
          NSCAssert(valueDataType != LCGPBDataTypeGroup, @"Can't happen");
          // Everything else is a NSString.
          [toStr appendString:valueObj];
          break;
      }
#pragma clang diagnostic pop
      [toStr appendString:@"\n"];

      [toStr appendString:msgEnd];
    }];
  }
}

static void AppendTextFormatForMessageField(LCGPBMessage *message,
                                            LCGPBFieldDescriptor *field,
                                            NSMutableString *toStr,
                                            NSString *lineIndent) {
  id arrayOrMap;
  NSUInteger count;
  LCGPBFieldType fieldType = field.fieldType;
  switch (fieldType) {
    case LCGPBFieldTypeSingle:
      arrayOrMap = nil;
      count = (LCGPBGetHasIvarField(message, field) ? 1 : 0);
      break;

    case LCGPBFieldTypeRepeated:
      // Will be NSArray or LCGPB*Array, type doesn't matter, they both
      // implement count.
      arrayOrMap = LCGPBGetObjectIvarWithFieldNoAutocreate(message, field);
      count = [(NSArray *)arrayOrMap count];
      break;

    case LCGPBFieldTypeMap: {
      // Will be LCGPB*Dictionary or NSMutableDictionary, type doesn't matter,
      // they both implement count.
      arrayOrMap = LCGPBGetObjectIvarWithFieldNoAutocreate(message, field);
      count = [(NSDictionary *)arrayOrMap count];
      break;
    }
  }

  if (count == 0) {
    // Nothing to print, out of here.
    return;
  }

  NSString *lineEnding = @"";

  // If the name can't be reversed or support for extra info was turned off,
  // this can return nil.
  NSString *fieldName = [field textFormatName];
  if ([fieldName length] == 0) {
    fieldName = [NSString stringWithFormat:@"%u", LCGPBFieldNumber(field)];
    // If there is only one entry, put the objc name as a comment, other wise
    // add it before the repeated values.
    if (count > 1) {
      [toStr appendFormat:@"%@# %@\n", lineIndent, field.name];
    } else {
      lineEnding = [NSString stringWithFormat:@"  # %@", field.name];
    }
  }

  if (fieldType == LCGPBFieldTypeMap) {
    AppendTextFormatForMapMessageField(arrayOrMap, field, toStr, lineIndent,
                                       fieldName, lineEnding);
    return;
  }

  id array = arrayOrMap;
  const BOOL isRepeated = (array != nil);

  LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
  BOOL isMessageField = LCGPBDataTypeIsMessage(fieldDataType);
  for (NSUInteger j = 0; j < count; ++j) {
    // Start the line.
    [toStr appendFormat:@"%@%@%s ", lineIndent, fieldName,
                        (isMessageField ? "" : ":")];

    // The value.
    switch (fieldDataType) {
#define FIELD_CASE(LCGPBDATATYPE, CTYPE, REAL_TYPE, ...)                        \
  case LCGPBDataType##LCGPBDATATYPE: {                                            \
    CTYPE v = (isRepeated ? [(LCGPB##REAL_TYPE##Array *)array valueAtIndex:j]   \
                          : LCGPBGetMessage##REAL_TYPE##Field(message, field)); \
    [toStr appendFormat:__VA_ARGS__, v];                                      \
    break;                                                                    \
  }

      FIELD_CASE(Int32, int32_t, Int32, @"%d")
      FIELD_CASE(SInt32, int32_t, Int32, @"%d")
      FIELD_CASE(SFixed32, int32_t, Int32, @"%d")
      FIELD_CASE(UInt32, uint32_t, UInt32, @"%u")
      FIELD_CASE(Fixed32, uint32_t, UInt32, @"%u")
      FIELD_CASE(Int64, int64_t, Int64, @"%lld")
      FIELD_CASE(SInt64, int64_t, Int64, @"%lld")
      FIELD_CASE(SFixed64, int64_t, Int64, @"%lld")
      FIELD_CASE(UInt64, uint64_t, UInt64, @"%llu")
      FIELD_CASE(Fixed64, uint64_t, UInt64, @"%llu")
      FIELD_CASE(Float, float, Float, @"%.*g", FLT_DIG)
      FIELD_CASE(Double, double, Double, @"%.*lg", DBL_DIG)

#undef FIELD_CASE

      case LCGPBDataTypeEnum: {
        int32_t v = (isRepeated ? [(LCGPBEnumArray *)array rawValueAtIndex:j]
                                : LCGPBGetMessageInt32Field(message, field));
        NSString *valueStr = nil;
        LCGPBEnumDescriptor *descriptor = field.enumDescriptor;
        if (descriptor) {
          valueStr = [descriptor textFormatNameForValue:v];
        }
        if (valueStr) {
          [toStr appendString:valueStr];
        } else {
          [toStr appendFormat:@"%d", v];
        }
        break;
      }

      case LCGPBDataTypeBool: {
        BOOL v = (isRepeated ? [(LCGPBBoolArray *)array valueAtIndex:j]
                             : LCGPBGetMessageBoolField(message, field));
        [toStr appendString:(v ? @"true" : @"false")];
        break;
      }

      case LCGPBDataTypeString: {
        NSString *v = (isRepeated ? [(NSArray *)array objectAtIndex:j]
                                  : LCGPBGetMessageStringField(message, field));
        AppendStringEscaped(v, toStr);
        break;
      }

      case LCGPBDataTypeBytes: {
        NSData *v = (isRepeated ? [(NSArray *)array objectAtIndex:j]
                                : LCGPBGetMessageBytesField(message, field));
        AppendBufferAsString(v, toStr);
        break;
      }

      case LCGPBDataTypeGroup:
      case LCGPBDataTypeMessage: {
        LCGPBMessage *v =
            (isRepeated ? [(NSArray *)array objectAtIndex:j]
                        : LCGPBGetObjectIvarWithField(message, field));
        [toStr appendFormat:@"{%@\n", lineEnding];
        NSString *subIndent = [lineIndent stringByAppendingString:@"  "];
        AppendTextFormatForMessage(v, toStr, subIndent);
        [toStr appendFormat:@"%@}", lineIndent];
        lineEnding = @"";
        break;
      }

    }  // switch(fieldDataType)

    // End the line.
    [toStr appendFormat:@"%@\n", lineEnding];

  }  // for(count)
}

static void AppendTextFormatForMessageExtensionRange(LCGPBMessage *message,
                                                     NSArray *activeExtensions,
                                                     LCGPBExtensionRange range,
                                                     NSMutableString *toStr,
                                                     NSString *lineIndent) {
  uint32_t start = range.start;
  uint32_t end = range.end;
  for (LCGPBExtensionDescriptor *extension in activeExtensions) {
    uint32_t fieldNumber = extension.fieldNumber;
    if (fieldNumber < start) {
      // Not there yet.
      continue;
    }
    if (fieldNumber >= end) {
      // Done.
      break;
    }

    id rawExtValue = [message getExtension:extension];
    BOOL isRepeated = extension.isRepeated;

    NSUInteger numValues = 1;
    NSString *lineEnding = @"";
    if (isRepeated) {
      numValues = [(NSArray *)rawExtValue count];
    }

    NSString *singletonName = extension.singletonName;
    if (numValues == 1) {
      lineEnding = [NSString stringWithFormat:@"  # [%@]", singletonName];
    } else {
      [toStr appendFormat:@"%@# [%@]\n", lineIndent, singletonName];
    }

    LCGPBDataType extDataType = extension.dataType;
    for (NSUInteger j = 0; j < numValues; ++j) {
      id curValue = (isRepeated ? [rawExtValue objectAtIndex:j] : rawExtValue);

      // Start the line.
      [toStr appendFormat:@"%@%u%s ", lineIndent, fieldNumber,
                          (LCGPBDataTypeIsMessage(extDataType) ? "" : ":")];

      // The value.
      switch (extDataType) {
#define FIELD_CASE(LCGPBDATATYPE, CTYPE, NUMSELECTOR, ...) \
  case LCGPBDataType##LCGPBDATATYPE: {                       \
    CTYPE v = [(NSNumber *)curValue NUMSELECTOR];        \
    [toStr appendFormat:__VA_ARGS__, v];                 \
    break;                                               \
  }

        FIELD_CASE(Int32, int32_t, intValue, @"%d")
        FIELD_CASE(SInt32, int32_t, intValue, @"%d")
        FIELD_CASE(SFixed32, int32_t, unsignedIntValue, @"%d")
        FIELD_CASE(UInt32, uint32_t, unsignedIntValue, @"%u")
        FIELD_CASE(Fixed32, uint32_t, unsignedIntValue, @"%u")
        FIELD_CASE(Int64, int64_t, longLongValue, @"%lld")
        FIELD_CASE(SInt64, int64_t, longLongValue, @"%lld")
        FIELD_CASE(SFixed64, int64_t, longLongValue, @"%lld")
        FIELD_CASE(UInt64, uint64_t, unsignedLongLongValue, @"%llu")
        FIELD_CASE(Fixed64, uint64_t, unsignedLongLongValue, @"%llu")
        FIELD_CASE(Float, float, floatValue, @"%.*g", FLT_DIG)
        FIELD_CASE(Double, double, doubleValue, @"%.*lg", DBL_DIG)
        // TODO: Add a comment with the enum name from enum descriptors
        // (might not be real value, so leave it as a comment, ObjC compiler
        // name mangles differently).  Doesn't look like we actually generate
        // an enum descriptor reference like we do for normal fields, so this
        // will take a compiler change.
        FIELD_CASE(Enum, int32_t, intValue, @"%d")

#undef FIELD_CASE

        case LCGPBDataTypeBool:
          [toStr appendString:([(NSNumber *)curValue boolValue] ? @"true"
                                                                : @"false")];
          break;

        case LCGPBDataTypeString:
          AppendStringEscaped(curValue, toStr);
          break;

        case LCGPBDataTypeBytes:
          AppendBufferAsString((NSData *)curValue, toStr);
          break;

        case LCGPBDataTypeGroup:
        case LCGPBDataTypeMessage: {
          [toStr appendFormat:@"{%@\n", lineEnding];
          NSString *subIndent = [lineIndent stringByAppendingString:@"  "];
          AppendTextFormatForMessage(curValue, toStr, subIndent);
          [toStr appendFormat:@"%@}", lineIndent];
          lineEnding = @"";
          break;
        }

      }  // switch(extDataType)

      // End the line.
      [toStr appendFormat:@"%@\n", lineEnding];

    }  //  for(numValues)

  }  // for..in(activeExtensions)
}

static void AppendTextFormatForMessage(LCGPBMessage *message,
                                       NSMutableString *toStr,
                                       NSString *lineIndent) {
  LCGPBDescriptor *descriptor = [message descriptor];
  NSArray *fieldsArray = descriptor->fields_;
  NSUInteger fieldCount = fieldsArray.count;
  const LCGPBExtensionRange *extensionRanges = descriptor.extensionRanges;
  NSUInteger extensionRangesCount = descriptor.extensionRangesCount;
  NSArray *activeExtensions = [[message extensionsCurrentlySet]
      sortedArrayUsingSelector:@selector(compareByFieldNumber:)];
  for (NSUInteger i = 0, j = 0; i < fieldCount || j < extensionRangesCount;) {
    if (i == fieldCount) {
      AppendTextFormatForMessageExtensionRange(
          message, activeExtensions, extensionRanges[j++], toStr, lineIndent);
    } else if (j == extensionRangesCount ||
               LCGPBFieldNumber(fieldsArray[i]) < extensionRanges[j].start) {
      AppendTextFormatForMessageField(message, fieldsArray[i++], toStr,
                                      lineIndent);
    } else {
      AppendTextFormatForMessageExtensionRange(
          message, activeExtensions, extensionRanges[j++], toStr, lineIndent);
    }
  }

  NSString *unknownFieldsStr =
      LCGPBTextFormatForUnknownFieldSet(message.unknownFields, lineIndent);
  if ([unknownFieldsStr length] > 0) {
    [toStr appendFormat:@"%@# --- Unknown fields ---\n", lineIndent];
    [toStr appendString:unknownFieldsStr];
  }
}

NSString *LCGPBTextFormatForMessage(LCGPBMessage *message, NSString *lineIndent) {
  if (message == nil) return @"";
  if (lineIndent == nil) lineIndent = @"";

  NSMutableString *buildString = [NSMutableString string];
  AppendTextFormatForMessage(message, buildString, lineIndent);
  return buildString;
}

NSString *LCGPBTextFormatForUnknownFieldSet(LCGPBUnknownFieldSet *unknownSet,
                                          NSString *lineIndent) {
  if (unknownSet == nil) return @"";
  if (lineIndent == nil) lineIndent = @"";

  NSMutableString *result = [NSMutableString string];
  for (LCGPBUnknownField *field in [unknownSet sortedFields]) {
    int32_t fieldNumber = [field number];

#define PRINT_LOOP(PROPNAME, CTYPE, FORMAT)                                   \
  [field.PROPNAME                                                             \
      enumerateValuesWithBlock:^(CTYPE value, NSUInteger idx, BOOL * stop) {  \
    _Pragma("unused(idx, stop)");                                             \
    [result                                                                   \
        appendFormat:@"%@%d: " #FORMAT "\n", lineIndent, fieldNumber, value]; \
      }];

    PRINT_LOOP(varintList, uint64_t, %llu);
    PRINT_LOOP(fixed32List, uint32_t, 0x%X);
    PRINT_LOOP(fixed64List, uint64_t, 0x%llX);

#undef PRINT_LOOP

    // NOTE: C++ version of TextFormat tries to parse this as a message
    // and print that if it succeeds.
    for (NSData *data in field.lengthDelimitedList) {
      [result appendFormat:@"%@%d: ", lineIndent, fieldNumber];
      AppendBufferAsString(data, result);
      [result appendString:@"\n"];
    }

    for (LCGPBUnknownFieldSet *subUnknownSet in field.groupList) {
      [result appendFormat:@"%@%d: {\n", lineIndent, fieldNumber];
      NSString *subIndent = [lineIndent stringByAppendingString:@"  "];
      NSString *subUnknwonSetStr =
          LCGPBTextFormatForUnknownFieldSet(subUnknownSet, subIndent);
      [result appendString:subUnknwonSetStr];
      [result appendFormat:@"%@}\n", lineIndent];
    }
  }
  return result;
}

// Helpers to decode a varint. Not using LCGPBCodedInputStream version because
// that needs a state object, and we don't want to create an input stream out
// of the data.
LCGPB_INLINE int8_t ReadRawByteFromData(const uint8_t **data) {
  int8_t result = *((int8_t *)(*data));
  ++(*data);
  return result;
}

static int32_t ReadRawVarint32FromData(const uint8_t **data) {
  int8_t tmp = ReadRawByteFromData(data);
  if (tmp >= 0) {
    return tmp;
  }
  int32_t result = tmp & 0x7f;
  if ((tmp = ReadRawByteFromData(data)) >= 0) {
    result |= tmp << 7;
  } else {
    result |= (tmp & 0x7f) << 7;
    if ((tmp = ReadRawByteFromData(data)) >= 0) {
      result |= tmp << 14;
    } else {
      result |= (tmp & 0x7f) << 14;
      if ((tmp = ReadRawByteFromData(data)) >= 0) {
        result |= tmp << 21;
      } else {
        result |= (tmp & 0x7f) << 21;
        result |= (tmp = ReadRawByteFromData(data)) << 28;
        if (tmp < 0) {
          // Discard upper 32 bits.
          for (int i = 0; i < 5; i++) {
            if (ReadRawByteFromData(data) >= 0) {
              return result;
            }
          }
          [NSException raise:NSParseErrorException
                      format:@"Unable to read varint32"];
        }
      }
    }
  }
  return result;
}

NSString *LCGPBDecodeTextFormatName(const uint8_t *decodeData, int32_t key,
                                  NSString *inputStr) {
  // decodData form:
  //  varint32: num entries
  //  for each entry:
  //    varint32: key
  //    bytes*: decode data
  //
  // decode data one of two forms:
  //  1: a \0 followed by the string followed by an \0
  //  2: bytecodes to transform an input into the right thing, ending with \0
  //
  // the bytes codes are of the form:
  //  0xabbccccc
  //  0x0 (all zeros), end.
  //  a - if set, add an underscore
  //  bb - 00 ccccc bytes as is
  //  bb - 10 ccccc upper first, as is on rest, ccccc byte total
  //  bb - 01 ccccc lower first, as is on rest, ccccc byte total
  //  bb - 11 ccccc all upper, ccccc byte total

  if (!decodeData || !inputStr) {
    return nil;
  }

  // Find key
  const uint8_t *scan = decodeData;
  int32_t numEntries = ReadRawVarint32FromData(&scan);
  BOOL foundKey = NO;
  while (!foundKey && (numEntries > 0)) {
    --numEntries;
    int32_t dataKey = ReadRawVarint32FromData(&scan);
    if (dataKey == key) {
      foundKey = YES;
    } else {
      // If it is a inlined string, it will start with \0; if it is bytecode it
      // will start with a code. So advance one (skipping the inline string
      // marker), and then loop until reaching the end marker (\0).
      ++scan;
      while (*scan != 0) ++scan;
      // Now move past the end marker.
      ++scan;
    }
  }

  if (!foundKey) {
    return nil;
  }

  // Decode

  if (*scan == 0) {
    // Inline string. Move over the marker, and NSString can take it as
    // UTF8.
    ++scan;
    NSString *result = [NSString stringWithUTF8String:(const char *)scan];
    return result;
  }

  NSMutableString *result =
      [NSMutableString stringWithCapacity:[inputStr length]];

  const uint8_t kAddUnderscore  = 0b10000000;
  const uint8_t kOpMask         = 0b01100000;
  // const uint8_t kOpAsIs        = 0b00000000;
  const uint8_t kOpFirstUpper     = 0b01000000;
  const uint8_t kOpFirstLower     = 0b00100000;
  const uint8_t kOpAllUpper       = 0b01100000;
  const uint8_t kSegmentLenMask = 0b00011111;

  NSInteger i = 0;
  for (; *scan != 0; ++scan) {
    if (*scan & kAddUnderscore) {
      [result appendString:@"_"];
    }
    int segmentLen = *scan & kSegmentLenMask;
    uint8_t decodeOp = *scan & kOpMask;

    // Do op specific handling of the first character.
    if (decodeOp == kOpFirstUpper) {
      unichar c = [inputStr characterAtIndex:i];
      [result appendFormat:@"%c", toupper((char)c)];
      ++i;
      --segmentLen;
    } else if (decodeOp == kOpFirstLower) {
      unichar c = [inputStr characterAtIndex:i];
      [result appendFormat:@"%c", tolower((char)c)];
      ++i;
      --segmentLen;
    }
    // else op == kOpAsIs || op == kOpAllUpper

    // Now pull over the rest of the length for this segment.
    for (int x = 0; x < segmentLen; ++x) {
      unichar c = [inputStr characterAtIndex:(i + x)];
      if (decodeOp == kOpAllUpper) {
        [result appendFormat:@"%c", toupper((char)c)];
      } else {
        [result appendFormat:@"%C", c];
      }
    }
    i += segmentLen;
  }

  return result;
}

#pragma clang diagnostic pop

BOOL LCGPBClassHasSel(Class aClass, SEL sel) {
  // NOTE: We have to use class_copyMethodList, all other runtime method
  // lookups actually also resolve the method implementation and this
  // is called from within those methods.

  BOOL result = NO;
  unsigned int methodCount = 0;
  Method *methodList = class_copyMethodList(aClass, &methodCount);
  for (unsigned int i = 0; i < methodCount; ++i) {
    SEL methodSelector = method_getName(methodList[i]);
    if (methodSelector == sel) {
      result = YES;
      break;
    }
  }
  free(methodList);
  return result;
}
