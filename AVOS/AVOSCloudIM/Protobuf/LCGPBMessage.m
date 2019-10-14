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

#import "LCGPBMessage_PackagePrivate.h"

#import <objc/runtime.h>
#import <objc/message.h>
#import <stdatomic.h>

#import "LCGPBArray_PackagePrivate.h"
#import "LCGPBCodedInputStream_PackagePrivate.h"
#import "LCGPBCodedOutputStream_PackagePrivate.h"
#import "LCGPBDescriptor_PackagePrivate.h"
#import "LCGPBDictionary_PackagePrivate.h"
#import "LCGPBExtensionInternals.h"
#import "LCGPBExtensionRegistry.h"
#import "LCGPBRootObject_PackagePrivate.h"
#import "LCGPBUnknownFieldSet_PackagePrivate.h"
#import "LCGPBUtilities_PackagePrivate.h"

// Direct access is use for speed, to avoid even internally declaring things
// read/write, etc. The warning is enabled in the project to ensure code calling
// protos can turn on -Wdirect-ivar-access without issues.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

NSString *const LCGPBMessageErrorDomain =
    LCGPBNSStringifySymbol(LCGPBMessageErrorDomain);

NSString *const LCGPBErrorReasonKey = @"Reason";

static NSString *const kLCGPBDataCoderKey = @"LCGPBData";

//
// PLEASE REMEMBER:
//
// This is the base class for *all* messages generated, so any selector defined,
// *public* or *private* could end up colliding with a proto message field. So
// avoid using selectors that could match a property, use C functions to hide
// them, etc.
//

@interface LCGPBMessage () {
 @package
  LCGPBUnknownFieldSet *unknownFields_;
  NSMutableDictionary *extensionMap_;
  NSMutableDictionary *autocreatedExtensionMap_;

  // If the object was autocreated, we remember the creator so that if we get
  // mutated, we can inform the creator to make our field visible.
  LCGPBMessage *autocreator_;
  LCGPBFieldDescriptor *autocreatorField_;
  LCGPBExtensionDescriptor *autocreatorExtension_;

  // A lock to provide mutual exclusion from internal data that can be modified
  // by *read* operations such as getters (autocreation of message fields and
  // message extensions, not setting of values). Used to guarantee thread safety
  // for concurrent reads on the message.
  // NOTE: OSSpinLock may seem like a good fit here but Apple engineers have
  // pointed out that they are vulnerable to live locking on iOS in cases of
  // priority inversion:
  //   http://mjtsai.com/blog/2015/12/16/osspinlock-is-unsafe/
  //   https://lists.swift.org/pipermail/swift-dev/Week-of-Mon-20151214/000372.html
  // Use of readOnlySemaphore_ must be prefaced by a call to
  // LCGPBPrepareReadOnlySemaphore to ensure it has been created. This allows
  // readOnlySemaphore_ to be only created when actually needed.
  _Atomic(dispatch_semaphore_t) readOnlySemaphore_;
}
@end

static id CreateArrayForField(LCGPBFieldDescriptor *field,
                              LCGPBMessage *autocreator)
    __attribute__((ns_returns_retained));
static id GetOrCreateArrayIvarWithField(LCGPBMessage *self,
                                        LCGPBFieldDescriptor *field,
                                        LCGPBFileSyntax syntax);
static id GetArrayIvarWithField(LCGPBMessage *self, LCGPBFieldDescriptor *field);
static id CreateMapForField(LCGPBFieldDescriptor *field,
                            LCGPBMessage *autocreator)
    __attribute__((ns_returns_retained));
static id GetOrCreateMapIvarWithField(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field,
                                      LCGPBFileSyntax syntax);
static id GetMapIvarWithField(LCGPBMessage *self, LCGPBFieldDescriptor *field);
static NSMutableDictionary *CloneExtensionMap(NSDictionary *extensionMap,
                                              NSZone *zone)
    __attribute__((ns_returns_retained));

#ifdef DEBUG
static NSError *MessageError(NSInteger code, NSDictionary *userInfo) {
  return [NSError errorWithDomain:LCGPBMessageErrorDomain
                             code:code
                         userInfo:userInfo];
}
#endif

static NSError *ErrorFromException(NSException *exception) {
  NSError *error = nil;

  if ([exception.name isEqual:LCGPBCodedInputStreamException]) {
    NSDictionary *exceptionInfo = exception.userInfo;
    error = exceptionInfo[LCGPBCodedInputStreamUnderlyingErrorKey];
  }

  if (!error) {
    NSString *reason = exception.reason;
    NSDictionary *userInfo = nil;
    if ([reason length]) {
      userInfo = @{ LCGPBErrorReasonKey : reason };
    }

    error = [NSError errorWithDomain:LCGPBMessageErrorDomain
                                code:LCGPBMessageErrorCodeOther
                            userInfo:userInfo];
  }
  return error;
}

static void CheckExtension(LCGPBMessage *self,
                           LCGPBExtensionDescriptor *extension) {
  if (![self isKindOfClass:extension.containingMessageClass]) {
    [NSException
         raise:NSInvalidArgumentException
        format:@"Extension %@ used on wrong class (%@ instead of %@)",
               extension.singletonName,
               [self class], extension.containingMessageClass];
  }
}

static NSMutableDictionary *CloneExtensionMap(NSDictionary *extensionMap,
                                              NSZone *zone) {
  if (extensionMap.count == 0) {
    return nil;
  }
  NSMutableDictionary *result = [[NSMutableDictionary allocWithZone:zone]
      initWithCapacity:extensionMap.count];

  for (LCGPBExtensionDescriptor *extension in extensionMap) {
    id value = [extensionMap objectForKey:extension];
    BOOL isMessageExtension = LCGPBExtensionIsMessage(extension);

    if (extension.repeated) {
      if (isMessageExtension) {
        NSMutableArray *list =
            [[NSMutableArray alloc] initWithCapacity:[value count]];
        for (LCGPBMessage *listValue in value) {
          LCGPBMessage *copiedValue = [listValue copyWithZone:zone];
          [list addObject:copiedValue];
          [copiedValue release];
        }
        [result setObject:list forKey:extension];
        [list release];
      } else {
        NSMutableArray *copiedValue = [value mutableCopyWithZone:zone];
        [result setObject:copiedValue forKey:extension];
        [copiedValue release];
      }
    } else {
      if (isMessageExtension) {
        LCGPBMessage *copiedValue = [value copyWithZone:zone];
        [result setObject:copiedValue forKey:extension];
        [copiedValue release];
      } else {
        [result setObject:value forKey:extension];
      }
    }
  }

  return result;
}

static id CreateArrayForField(LCGPBFieldDescriptor *field,
                              LCGPBMessage *autocreator) {
  id result;
  LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
  switch (fieldDataType) {
    case LCGPBDataTypeBool:
      result = [[LCGPBBoolArray alloc] init];
      break;
    case LCGPBDataTypeFixed32:
    case LCGPBDataTypeUInt32:
      result = [[LCGPBUInt32Array alloc] init];
      break;
    case LCGPBDataTypeInt32:
    case LCGPBDataTypeSFixed32:
    case LCGPBDataTypeSInt32:
      result = [[LCGPBInt32Array alloc] init];
      break;
    case LCGPBDataTypeFixed64:
    case LCGPBDataTypeUInt64:
      result = [[LCGPBUInt64Array alloc] init];
      break;
    case LCGPBDataTypeInt64:
    case LCGPBDataTypeSFixed64:
    case LCGPBDataTypeSInt64:
      result = [[LCGPBInt64Array alloc] init];
      break;
    case LCGPBDataTypeFloat:
      result = [[LCGPBFloatArray alloc] init];
      break;
    case LCGPBDataTypeDouble:
      result = [[LCGPBDoubleArray alloc] init];
      break;

    case LCGPBDataTypeEnum:
      result = [[LCGPBEnumArray alloc]
                  initWithValidationFunction:field.enumDescriptor.enumVerifier];
      break;

    case LCGPBDataTypeBytes:
    case LCGPBDataTypeGroup:
    case LCGPBDataTypeMessage:
    case LCGPBDataTypeString:
      if (autocreator) {
        result = [[LCGPBAutocreatedArray alloc] init];
      } else {
        result = [[NSMutableArray alloc] init];
      }
      break;
  }

  if (autocreator) {
    if (LCGPBDataTypeIsObject(fieldDataType)) {
      LCGPBAutocreatedArray *autoArray = result;
      autoArray->_autocreator =  autocreator;
    } else {
      LCGPBInt32Array *gpbArray = result;
      gpbArray->_autocreator = autocreator;
    }
  }

  return result;
}

static id CreateMapForField(LCGPBFieldDescriptor *field,
                            LCGPBMessage *autocreator) {
  id result;
  LCGPBDataType keyDataType = field.mapKeyDataType;
  LCGPBDataType valueDataType = LCGPBGetFieldDataType(field);
  switch (keyDataType) {
    case LCGPBDataTypeBool:
      switch (valueDataType) {
        case LCGPBDataTypeBool:
          result = [[LCGPBBoolBoolDictionary alloc] init];
          break;
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
          result = [[LCGPBBoolUInt32Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeSInt32:
          result = [[LCGPBBoolInt32Dictionary alloc] init];
          break;
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
          result = [[LCGPBBoolUInt64Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeSInt64:
          result = [[LCGPBBoolInt64Dictionary alloc] init];
          break;
        case LCGPBDataTypeFloat:
          result = [[LCGPBBoolFloatDictionary alloc] init];
          break;
        case LCGPBDataTypeDouble:
          result = [[LCGPBBoolDoubleDictionary alloc] init];
          break;
        case LCGPBDataTypeEnum:
          result = [[LCGPBBoolEnumDictionary alloc]
              initWithValidationFunction:field.enumDescriptor.enumVerifier];
          break;
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeMessage:
        case LCGPBDataTypeString:
          result = [[LCGPBBoolObjectDictionary alloc] init];
          break;
        case LCGPBDataTypeGroup:
          NSCAssert(NO, @"shouldn't happen");
          return nil;
      }
      break;
    case LCGPBDataTypeFixed32:
    case LCGPBDataTypeUInt32:
      switch (valueDataType) {
        case LCGPBDataTypeBool:
          result = [[LCGPBUInt32BoolDictionary alloc] init];
          break;
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
          result = [[LCGPBUInt32UInt32Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeSInt32:
          result = [[LCGPBUInt32Int32Dictionary alloc] init];
          break;
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
          result = [[LCGPBUInt32UInt64Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeSInt64:
          result = [[LCGPBUInt32Int64Dictionary alloc] init];
          break;
        case LCGPBDataTypeFloat:
          result = [[LCGPBUInt32FloatDictionary alloc] init];
          break;
        case LCGPBDataTypeDouble:
          result = [[LCGPBUInt32DoubleDictionary alloc] init];
          break;
        case LCGPBDataTypeEnum:
          result = [[LCGPBUInt32EnumDictionary alloc]
              initWithValidationFunction:field.enumDescriptor.enumVerifier];
          break;
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeMessage:
        case LCGPBDataTypeString:
          result = [[LCGPBUInt32ObjectDictionary alloc] init];
          break;
        case LCGPBDataTypeGroup:
          NSCAssert(NO, @"shouldn't happen");
          return nil;
      }
      break;
    case LCGPBDataTypeInt32:
    case LCGPBDataTypeSFixed32:
    case LCGPBDataTypeSInt32:
      switch (valueDataType) {
        case LCGPBDataTypeBool:
          result = [[LCGPBInt32BoolDictionary alloc] init];
          break;
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
          result = [[LCGPBInt32UInt32Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeSInt32:
          result = [[LCGPBInt32Int32Dictionary alloc] init];
          break;
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
          result = [[LCGPBInt32UInt64Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeSInt64:
          result = [[LCGPBInt32Int64Dictionary alloc] init];
          break;
        case LCGPBDataTypeFloat:
          result = [[LCGPBInt32FloatDictionary alloc] init];
          break;
        case LCGPBDataTypeDouble:
          result = [[LCGPBInt32DoubleDictionary alloc] init];
          break;
        case LCGPBDataTypeEnum:
          result = [[LCGPBInt32EnumDictionary alloc]
              initWithValidationFunction:field.enumDescriptor.enumVerifier];
          break;
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeMessage:
        case LCGPBDataTypeString:
          result = [[LCGPBInt32ObjectDictionary alloc] init];
          break;
        case LCGPBDataTypeGroup:
          NSCAssert(NO, @"shouldn't happen");
          return nil;
      }
      break;
    case LCGPBDataTypeFixed64:
    case LCGPBDataTypeUInt64:
      switch (valueDataType) {
        case LCGPBDataTypeBool:
          result = [[LCGPBUInt64BoolDictionary alloc] init];
          break;
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
          result = [[LCGPBUInt64UInt32Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeSInt32:
          result = [[LCGPBUInt64Int32Dictionary alloc] init];
          break;
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
          result = [[LCGPBUInt64UInt64Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeSInt64:
          result = [[LCGPBUInt64Int64Dictionary alloc] init];
          break;
        case LCGPBDataTypeFloat:
          result = [[LCGPBUInt64FloatDictionary alloc] init];
          break;
        case LCGPBDataTypeDouble:
          result = [[LCGPBUInt64DoubleDictionary alloc] init];
          break;
        case LCGPBDataTypeEnum:
          result = [[LCGPBUInt64EnumDictionary alloc]
              initWithValidationFunction:field.enumDescriptor.enumVerifier];
          break;
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeMessage:
        case LCGPBDataTypeString:
          result = [[LCGPBUInt64ObjectDictionary alloc] init];
          break;
        case LCGPBDataTypeGroup:
          NSCAssert(NO, @"shouldn't happen");
          return nil;
      }
      break;
    case LCGPBDataTypeInt64:
    case LCGPBDataTypeSFixed64:
    case LCGPBDataTypeSInt64:
      switch (valueDataType) {
        case LCGPBDataTypeBool:
          result = [[LCGPBInt64BoolDictionary alloc] init];
          break;
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
          result = [[LCGPBInt64UInt32Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeSInt32:
          result = [[LCGPBInt64Int32Dictionary alloc] init];
          break;
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
          result = [[LCGPBInt64UInt64Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeSInt64:
          result = [[LCGPBInt64Int64Dictionary alloc] init];
          break;
        case LCGPBDataTypeFloat:
          result = [[LCGPBInt64FloatDictionary alloc] init];
          break;
        case LCGPBDataTypeDouble:
          result = [[LCGPBInt64DoubleDictionary alloc] init];
          break;
        case LCGPBDataTypeEnum:
          result = [[LCGPBInt64EnumDictionary alloc]
              initWithValidationFunction:field.enumDescriptor.enumVerifier];
          break;
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeMessage:
        case LCGPBDataTypeString:
          result = [[LCGPBInt64ObjectDictionary alloc] init];
          break;
        case LCGPBDataTypeGroup:
          NSCAssert(NO, @"shouldn't happen");
          return nil;
      }
      break;
    case LCGPBDataTypeString:
      switch (valueDataType) {
        case LCGPBDataTypeBool:
          result = [[LCGPBStringBoolDictionary alloc] init];
          break;
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
          result = [[LCGPBStringUInt32Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeSInt32:
          result = [[LCGPBStringInt32Dictionary alloc] init];
          break;
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
          result = [[LCGPBStringUInt64Dictionary alloc] init];
          break;
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeSInt64:
          result = [[LCGPBStringInt64Dictionary alloc] init];
          break;
        case LCGPBDataTypeFloat:
          result = [[LCGPBStringFloatDictionary alloc] init];
          break;
        case LCGPBDataTypeDouble:
          result = [[LCGPBStringDoubleDictionary alloc] init];
          break;
        case LCGPBDataTypeEnum:
          result = [[LCGPBStringEnumDictionary alloc]
              initWithValidationFunction:field.enumDescriptor.enumVerifier];
          break;
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeMessage:
        case LCGPBDataTypeString:
          if (autocreator) {
            result = [[LCGPBAutocreatedDictionary alloc] init];
          } else {
            result = [[NSMutableDictionary alloc] init];
          }
          break;
        case LCGPBDataTypeGroup:
          NSCAssert(NO, @"shouldn't happen");
          return nil;
      }
      break;

    case LCGPBDataTypeFloat:
    case LCGPBDataTypeDouble:
    case LCGPBDataTypeEnum:
    case LCGPBDataTypeBytes:
    case LCGPBDataTypeGroup:
    case LCGPBDataTypeMessage:
      NSCAssert(NO, @"shouldn't happen");
      return nil;
  }

  if (autocreator) {
    if ((keyDataType == LCGPBDataTypeString) &&
        LCGPBDataTypeIsObject(valueDataType)) {
      LCGPBAutocreatedDictionary *autoDict = result;
      autoDict->_autocreator =  autocreator;
    } else {
      LCGPBInt32Int32Dictionary *gpbDict = result;
      gpbDict->_autocreator = autocreator;
    }
  }

  return result;
}

#if !defined(__clang_analyzer__)
// These functions are blocked from the analyzer because the analyzer sees the
// LCGPBSetRetainedObjectIvarWithFieldInternal() call as consuming the array/map,
// so use of the array/map after the call returns is flagged as a use after
// free.
// But LCGPBSetRetainedObjectIvarWithFieldInternal() is "consuming" the retain
// count be holding onto the object (it is transfering it), the object is
// still valid after returning from the call.  The other way to avoid this
// would be to add a -retain/-autorelease, but that would force every
// repeated/map field parsed into the autorelease pool which is both a memory
// and performance hit.

static id GetOrCreateArrayIvarWithField(LCGPBMessage *self,
                                        LCGPBFieldDescriptor *field,
                                        LCGPBFileSyntax syntax) {
  id array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
  if (!array) {
    // No lock needed, this is called from places expecting to mutate
    // so no threading protection is needed.
    array = CreateArrayForField(field, nil);
    LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, array, syntax);
  }
  return array;
}

// This is like LCGPBGetObjectIvarWithField(), but for arrays, it should
// only be used to wire the method into the class.
static id GetArrayIvarWithField(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
  id array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
  if (!array) {
    // Check again after getting the lock.
    LCGPBPrepareReadOnlySemaphore(self);
    dispatch_semaphore_wait(self->readOnlySemaphore_, DISPATCH_TIME_FOREVER);
    array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
    if (!array) {
      array = CreateArrayForField(field, self);
      LCGPBSetAutocreatedRetainedObjectIvarWithField(self, field, array);
    }
    dispatch_semaphore_signal(self->readOnlySemaphore_);
  }
  return array;
}

static id GetOrCreateMapIvarWithField(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field,
                                      LCGPBFileSyntax syntax) {
  id dict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
  if (!dict) {
    // No lock needed, this is called from places expecting to mutate
    // so no threading protection is needed.
    dict = CreateMapForField(field, nil);
    LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, dict, syntax);
  }
  return dict;
}

// This is like LCGPBGetObjectIvarWithField(), but for maps, it should
// only be used to wire the method into the class.
static id GetMapIvarWithField(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
  id dict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
  if (!dict) {
    // Check again after getting the lock.
    LCGPBPrepareReadOnlySemaphore(self);
    dispatch_semaphore_wait(self->readOnlySemaphore_, DISPATCH_TIME_FOREVER);
    dict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
    if (!dict) {
      dict = CreateMapForField(field, self);
      LCGPBSetAutocreatedRetainedObjectIvarWithField(self, field, dict);
    }
    dispatch_semaphore_signal(self->readOnlySemaphore_);
  }
  return dict;
}

#endif  // !defined(__clang_analyzer__)

LCGPBMessage *LCGPBCreateMessageWithAutocreator(Class msgClass,
                                            LCGPBMessage *autocreator,
                                            LCGPBFieldDescriptor *field) {
  LCGPBMessage *message = [[msgClass alloc] init];
  message->autocreator_ = autocreator;
  message->autocreatorField_ = [field retain];
  return message;
}

static LCGPBMessage *CreateMessageWithAutocreatorForExtension(
    Class msgClass, LCGPBMessage *autocreator, LCGPBExtensionDescriptor *extension)
    __attribute__((ns_returns_retained));

static LCGPBMessage *CreateMessageWithAutocreatorForExtension(
    Class msgClass, LCGPBMessage *autocreator,
    LCGPBExtensionDescriptor *extension) {
  LCGPBMessage *message = [[msgClass alloc] init];
  message->autocreator_ = autocreator;
  message->autocreatorExtension_ = [extension retain];
  return message;
}

BOOL LCGPBWasMessageAutocreatedBy(LCGPBMessage *message, LCGPBMessage *parent) {
  return (message->autocreator_ == parent);
}

void LCGPBBecomeVisibleToAutocreator(LCGPBMessage *self) {
  // Message objects that are implicitly created by accessing a message field
  // are initially not visible via the hasX selector. This method makes them
  // visible.
  if (self->autocreator_) {
    // This will recursively make all parent messages visible until it reaches a
    // super-creator that's visible.
    if (self->autocreatorField_) {
      LCGPBFileSyntax syntax = [self->autocreator_ descriptor].file.syntax;
      LCGPBSetObjectIvarWithFieldInternal(self->autocreator_,
                                        self->autocreatorField_, self, syntax);
    } else {
      [self->autocreator_ setExtension:self->autocreatorExtension_ value:self];
    }
  }
}

void LCGPBAutocreatedArrayModified(LCGPBMessage *self, id array) {
  // When one of our autocreated arrays adds elements, make it visible.
  LCGPBDescriptor *descriptor = [[self class] descriptor];
  for (LCGPBFieldDescriptor *field in descriptor->fields_) {
    if (field.fieldType == LCGPBFieldTypeRepeated) {
      id curArray = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
      if (curArray == array) {
        if (LCGPBFieldDataTypeIsObject(field)) {
          LCGPBAutocreatedArray *autoArray = array;
          autoArray->_autocreator = nil;
        } else {
          LCGPBInt32Array *gpbArray = array;
          gpbArray->_autocreator = nil;
        }
        LCGPBBecomeVisibleToAutocreator(self);
        return;
      }
    }
  }
  NSCAssert(NO, @"Unknown autocreated %@ for %@.", [array class], self);
}

void LCGPBAutocreatedDictionaryModified(LCGPBMessage *self, id dictionary) {
  // When one of our autocreated dicts adds elements, make it visible.
  LCGPBDescriptor *descriptor = [[self class] descriptor];
  for (LCGPBFieldDescriptor *field in descriptor->fields_) {
    if (field.fieldType == LCGPBFieldTypeMap) {
      id curDict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
      if (curDict == dictionary) {
        if ((field.mapKeyDataType == LCGPBDataTypeString) &&
            LCGPBFieldDataTypeIsObject(field)) {
          LCGPBAutocreatedDictionary *autoDict = dictionary;
          autoDict->_autocreator = nil;
        } else {
          LCGPBInt32Int32Dictionary *gpbDict = dictionary;
          gpbDict->_autocreator = nil;
        }
        LCGPBBecomeVisibleToAutocreator(self);
        return;
      }
    }
  }
  NSCAssert(NO, @"Unknown autocreated %@ for %@.", [dictionary class], self);
}

void LCGPBClearMessageAutocreator(LCGPBMessage *self) {
  if ((self == nil) || !self->autocreator_) {
    return;
  }

#if defined(DEBUG) && DEBUG && !defined(NS_BLOCK_ASSERTIONS)
  // Either the autocreator must have its "has" flag set to YES, or it must be
  // NO and not equal to ourselves.
  BOOL autocreatorHas =
      (self->autocreatorField_
           ? LCGPBGetHasIvarField(self->autocreator_, self->autocreatorField_)
           : [self->autocreator_ hasExtension:self->autocreatorExtension_]);
  LCGPBMessage *autocreatorFieldValue =
      (self->autocreatorField_
           ? LCGPBGetObjectIvarWithFieldNoAutocreate(self->autocreator_,
                                                   self->autocreatorField_)
           : [self->autocreator_->autocreatedExtensionMap_
                 objectForKey:self->autocreatorExtension_]);
  NSCAssert(autocreatorHas || autocreatorFieldValue != self,
            @"Cannot clear autocreator because it still refers to self, self: %@.",
            self);

#endif  // DEBUG && !defined(NS_BLOCK_ASSERTIONS)

  self->autocreator_ = nil;
  [self->autocreatorField_ release];
  self->autocreatorField_ = nil;
  [self->autocreatorExtension_ release];
  self->autocreatorExtension_ = nil;
}

// Call this before using the readOnlySemaphore_. This ensures it is created only once.
void LCGPBPrepareReadOnlySemaphore(LCGPBMessage *self) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

  // Create the semaphore on demand (rather than init) as developers might not cause them
  // to be needed, and the heap usage can add up.  The atomic swap is used to avoid needing
  // another lock around creating it.
  if (self->readOnlySemaphore_ == nil) {
    dispatch_semaphore_t worker = dispatch_semaphore_create(1);
    dispatch_semaphore_t expected = nil;
    if (!atomic_compare_exchange_strong(&self->readOnlySemaphore_, &expected, worker)) {
      dispatch_release(worker);
    }
#if defined(__clang_analyzer__)
    // The Xcode 9.2 (and 9.3 beta) static analyzer thinks worker is leaked
    // (doesn't seem to know about atomic_compare_exchange_strong); so just
    // for the analyzer, let it think worker is also released in this case.
    else { dispatch_release(worker); }
#endif
  }

#pragma clang diagnostic pop
}

static LCGPBUnknownFieldSet *GetOrMakeUnknownFields(LCGPBMessage *self) {
  if (!self->unknownFields_) {
    self->unknownFields_ = [[LCGPBUnknownFieldSet alloc] init];
    LCGPBBecomeVisibleToAutocreator(self);
  }
  return self->unknownFields_;
}

@implementation LCGPBMessage

+ (void)initialize {
  Class pbMessageClass = [LCGPBMessage class];
  if ([self class] == pbMessageClass) {
    // This is here to start up the "base" class descriptor.
    [self descriptor];
    // Message shares extension method resolving with LCGPBRootObject so insure
    // it is started up at the same time.
    (void)[LCGPBRootObject class];
  } else if ([self superclass] == pbMessageClass) {
    // This is here to start up all the "message" subclasses. Just needs to be
    // done for the messages, not any of the subclasses.
    // This must be done in initialize to enforce thread safety of start up of
    // the protocol buffer library.
    // Note: The generated code for -descriptor calls
    // +[LCGPBDescriptor allocDescriptorForClass:...], passing the LCGPBRootObject
    // subclass for the file.  That call chain is what ensures that *Root class
    // is started up to support extension resolution off the message class
    // (+resolveClassMethod: below) in a thread safe manner.
    [self descriptor];
  }
}

+ (instancetype)allocWithZone:(NSZone *)zone {
  // Override alloc to allocate our classes with the additional storage
  // required for the instance variables.
  LCGPBDescriptor *descriptor = [self descriptor];
  return NSAllocateObject(self, descriptor->storageSize_, zone);
}

+ (instancetype)alloc {
  return [self allocWithZone:nil];
}

+ (LCGPBDescriptor *)descriptor {
  // This is thread safe because it is called from +initialize.
  static LCGPBDescriptor *descriptor = NULL;
  static LCGPBFileDescriptor *fileDescriptor = NULL;
  if (!descriptor) {
    // Use a dummy file that marks it as proto2 syntax so when used generically
    // it supports unknowns/etc.
    fileDescriptor =
        [[LCGPBFileDescriptor alloc] initWithPackage:@"internal"
                                            syntax:LCGPBFileSyntaxProto2];

    descriptor = [LCGPBDescriptor allocDescriptorForClass:[LCGPBMessage class]
                                              rootClass:Nil
                                                   file:fileDescriptor
                                                 fields:NULL
                                             fieldCount:0
                                            storageSize:0
                                                  flags:0];
  }
  return descriptor;
}

+ (instancetype)message {
  return [[[self alloc] init] autorelease];
}

- (instancetype)init {
  if ((self = [super init])) {
    messageStorage_ = (LCGPBMessage_StoragePtr)(
        ((uint8_t *)self) + class_getInstanceSize([self class]));
  }

  return self;
}

- (instancetype)initWithData:(NSData *)data error:(NSError **)errorPtr {
  return [self initWithData:data extensionRegistry:nil error:errorPtr];
}

- (instancetype)initWithData:(NSData *)data
           extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry
                       error:(NSError **)errorPtr {
  if ((self = [self init])) {
    @try {
      [self mergeFromData:data extensionRegistry:extensionRegistry];
      if (errorPtr) {
        *errorPtr = nil;
      }
    }
    @catch (NSException *exception) {
      [self release];
      self = nil;
      if (errorPtr) {
        *errorPtr = ErrorFromException(exception);
      }
    }
#ifdef DEBUG
    if (self && !self.initialized) {
      [self release];
      self = nil;
      if (errorPtr) {
        *errorPtr = MessageError(LCGPBMessageErrorCodeMissingRequiredField, nil);
      }
    }
#endif
  }
  return self;
}

- (instancetype)initWithCodedInputStream:(LCGPBCodedInputStream *)input
                       extensionRegistry:
                           (LCGPBExtensionRegistry *)extensionRegistry
                                   error:(NSError **)errorPtr {
  if ((self = [self init])) {
    @try {
      [self mergeFromCodedInputStream:input extensionRegistry:extensionRegistry];
      if (errorPtr) {
        *errorPtr = nil;
      }
    }
    @catch (NSException *exception) {
      [self release];
      self = nil;
      if (errorPtr) {
        *errorPtr = ErrorFromException(exception);
      }
    }
#ifdef DEBUG
    if (self && !self.initialized) {
      [self release];
      self = nil;
      if (errorPtr) {
        *errorPtr = MessageError(LCGPBMessageErrorCodeMissingRequiredField, nil);
      }
    }
#endif
  }
  return self;
}

- (void)dealloc {
  [self internalClear:NO];
  NSCAssert(!autocreator_, @"Autocreator was not cleared before dealloc.");
  if (readOnlySemaphore_) {
    dispatch_release(readOnlySemaphore_);
  }
  [super dealloc];
}

- (void)copyFieldsInto:(LCGPBMessage *)message
                  zone:(NSZone *)zone
            descriptor:(LCGPBDescriptor *)descriptor {
  // Copy all the storage...
  memcpy(message->messageStorage_, messageStorage_, descriptor->storageSize_);

  LCGPBFileSyntax syntax = descriptor.file.syntax;

  // Loop over the fields doing fixup...
  for (LCGPBFieldDescriptor *field in descriptor->fields_) {
    if (LCGPBFieldIsMapOrArray(field)) {
      id value = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
      if (value) {
        // We need to copy the array/map, but the catch is for message fields,
        // we also need to ensure all the messages as those need copying also.
        id newValue;
        if (LCGPBFieldDataTypeIsMessage(field)) {
          if (field.fieldType == LCGPBFieldTypeRepeated) {
            NSArray *existingArray = (NSArray *)value;
            NSMutableArray *newArray =
                [[NSMutableArray alloc] initWithCapacity:existingArray.count];
            newValue = newArray;
            for (LCGPBMessage *msg in existingArray) {
              LCGPBMessage *copiedMsg = [msg copyWithZone:zone];
              [newArray addObject:copiedMsg];
              [copiedMsg release];
            }
          } else {
            if (field.mapKeyDataType == LCGPBDataTypeString) {
              // Map is an NSDictionary.
              NSDictionary *existingDict = value;
              NSMutableDictionary *newDict = [[NSMutableDictionary alloc]
                  initWithCapacity:existingDict.count];
              newValue = newDict;
              [existingDict enumerateKeysAndObjectsUsingBlock:^(NSString *key,
                                                                LCGPBMessage *msg,
                                                                BOOL *stop) {
#pragma unused(stop)
                LCGPBMessage *copiedMsg = [msg copyWithZone:zone];
                [newDict setObject:copiedMsg forKey:key];
                [copiedMsg release];
              }];
            } else {
              // Is one of the LCGPB*ObjectDictionary classes.  Type doesn't
              // matter, just need one to invoke the selector.
              LCGPBInt32ObjectDictionary *existingDict = value;
              newValue = [existingDict deepCopyWithZone:zone];
            }
          }
        } else {
          // Not messages (but is a map/array)...
          if (field.fieldType == LCGPBFieldTypeRepeated) {
            if (LCGPBFieldDataTypeIsObject(field)) {
              // NSArray
              newValue = [value mutableCopyWithZone:zone];
            } else {
              // LCGPB*Array
              newValue = [value copyWithZone:zone];
            }
          } else {
            if ((field.mapKeyDataType == LCGPBDataTypeString) &&
                LCGPBFieldDataTypeIsObject(field)) {
              // NSDictionary
              newValue = [value mutableCopyWithZone:zone];
            } else {
              // Is one of the LCGPB*Dictionary classes.  Type doesn't matter,
              // just need one to invoke the selector.
              LCGPBInt32Int32Dictionary *existingDict = value;
              newValue = [existingDict copyWithZone:zone];
            }
          }
        }
        // We retain here because the memcpy picked up the pointer value and
        // the next call to SetRetainedObject... will release the current value.
        [value retain];
        LCGPBSetRetainedObjectIvarWithFieldInternal(message, field, newValue,
                                                  syntax);
      }
    } else if (LCGPBFieldDataTypeIsMessage(field)) {
      // For object types, if we have a value, copy it.  If we don't,
      // zero it to remove the pointer to something that was autocreated
      // (and the ptr just got memcpyed).
      if (LCGPBGetHasIvarField(self, field)) {
        LCGPBMessage *value = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        LCGPBMessage *newValue = [value copyWithZone:zone];
        // We retain here because the memcpy picked up the pointer value and
        // the next call to SetRetainedObject... will release the current value.
        [value retain];
        LCGPBSetRetainedObjectIvarWithFieldInternal(message, field, newValue,
                                                  syntax);
      } else {
        uint8_t *storage = (uint8_t *)message->messageStorage_;
        id *typePtr = (id *)&storage[field->description_->offset];
        *typePtr = NULL;
      }
    } else if (LCGPBFieldDataTypeIsObject(field) &&
               LCGPBGetHasIvarField(self, field)) {
      // A set string/data value (message picked off above), copy it.
      id value = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
      id newValue = [value copyWithZone:zone];
      // We retain here because the memcpy picked up the pointer value and
      // the next call to SetRetainedObject... will release the current value.
      [value retain];
      LCGPBSetRetainedObjectIvarWithFieldInternal(message, field, newValue,
                                                syntax);
    } else {
      // memcpy took care of the rest of the primitive fields if they were set.
    }
  }  // for (field in descriptor->fields_)
}

- (id)copyWithZone:(NSZone *)zone {
  LCGPBDescriptor *descriptor = [self descriptor];
  LCGPBMessage *result = [[descriptor.messageClass allocWithZone:zone] init];

  [self copyFieldsInto:result zone:zone descriptor:descriptor];
  // Make immutable copies of the extra bits.
  result->unknownFields_ = [unknownFields_ copyWithZone:zone];
  result->extensionMap_ = CloneExtensionMap(extensionMap_, zone);
  return result;
}

- (void)clear {
  [self internalClear:YES];
}

- (void)internalClear:(BOOL)zeroStorage {
  LCGPBDescriptor *descriptor = [self descriptor];
  for (LCGPBFieldDescriptor *field in descriptor->fields_) {
    if (LCGPBFieldIsMapOrArray(field)) {
      id arrayOrMap = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
      if (arrayOrMap) {
        if (field.fieldType == LCGPBFieldTypeRepeated) {
          if (LCGPBFieldDataTypeIsObject(field)) {
            if ([arrayOrMap isKindOfClass:[LCGPBAutocreatedArray class]]) {
              LCGPBAutocreatedArray *autoArray = arrayOrMap;
              if (autoArray->_autocreator == self) {
                autoArray->_autocreator = nil;
              }
            }
          } else {
            // Type doesn't matter, it is a LCGPB*Array.
            LCGPBInt32Array *gpbArray = arrayOrMap;
            if (gpbArray->_autocreator == self) {
              gpbArray->_autocreator = nil;
            }
          }
        } else {
          if ((field.mapKeyDataType == LCGPBDataTypeString) &&
              LCGPBFieldDataTypeIsObject(field)) {
            if ([arrayOrMap isKindOfClass:[LCGPBAutocreatedDictionary class]]) {
              LCGPBAutocreatedDictionary *autoDict = arrayOrMap;
              if (autoDict->_autocreator == self) {
                autoDict->_autocreator = nil;
              }
            }
          } else {
            // Type doesn't matter, it is a LCGPB*Dictionary.
            LCGPBInt32Int32Dictionary *gpbDict = arrayOrMap;
            if (gpbDict->_autocreator == self) {
              gpbDict->_autocreator = nil;
            }
          }
        }
        [arrayOrMap release];
      }
    } else if (LCGPBFieldDataTypeIsMessage(field)) {
      LCGPBClearAutocreatedMessageIvarWithField(self, field);
      LCGPBMessage *value = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
      [value release];
    } else if (LCGPBFieldDataTypeIsObject(field) &&
               LCGPBGetHasIvarField(self, field)) {
      id value = LCGPBGetObjectIvarWithField(self, field);
      [value release];
    }
  }

  // LCGPBClearMessageAutocreator() expects that its caller has already been
  // removed from autocreatedExtensionMap_ so we set to nil first.
  NSArray *autocreatedValues = [autocreatedExtensionMap_ allValues];
  [autocreatedExtensionMap_ release];
  autocreatedExtensionMap_ = nil;

  // Since we're clearing all of our extensions, make sure that we clear the
  // autocreator on any that we've created so they no longer refer to us.
  for (LCGPBMessage *value in autocreatedValues) {
    NSCAssert(LCGPBWasMessageAutocreatedBy(value, self),
              @"Autocreated extension does not refer back to self.");
    LCGPBClearMessageAutocreator(value);
  }

  [extensionMap_ release];
  extensionMap_ = nil;
  [unknownFields_ release];
  unknownFields_ = nil;

  // Note that clearing does not affect autocreator_. If we are being cleared
  // because of a dealloc, then autocreator_ should be nil anyway. If we are
  // being cleared because someone explicitly clears us, we don't want to
  // sever our relationship with our autocreator.

  if (zeroStorage) {
    memset(messageStorage_, 0, descriptor->storageSize_);
  }
}

- (BOOL)isInitialized {
  LCGPBDescriptor *descriptor = [self descriptor];
  for (LCGPBFieldDescriptor *field in descriptor->fields_) {
    if (field.isRequired) {
      if (!LCGPBGetHasIvarField(self, field)) {
        return NO;
      }
    }
    if (LCGPBFieldDataTypeIsMessage(field)) {
      LCGPBFieldType fieldType = field.fieldType;
      if (fieldType == LCGPBFieldTypeSingle) {
        if (field.isRequired) {
          LCGPBMessage *message = LCGPBGetMessageMessageField(self, field);
          if (!message.initialized) {
            return NO;
          }
        } else {
          NSAssert(field.isOptional,
                   @"%@: Single message field %@ not required or optional?",
                   [self class], field.name);
          if (LCGPBGetHasIvarField(self, field)) {
            LCGPBMessage *message = LCGPBGetMessageMessageField(self, field);
            if (!message.initialized) {
              return NO;
            }
          }
        }
      } else if (fieldType == LCGPBFieldTypeRepeated) {
        NSArray *array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        for (LCGPBMessage *message in array) {
          if (!message.initialized) {
            return NO;
          }
        }
      } else {  // fieldType == LCGPBFieldTypeMap
        if (field.mapKeyDataType == LCGPBDataTypeString) {
          NSDictionary *map =
              LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
          if (map && !LCGPBDictionaryIsInitializedInternalHelper(map, field)) {
            return NO;
          }
        } else {
          // Real type is LCGPB*ObjectDictionary, exact type doesn't matter.
          LCGPBInt32ObjectDictionary *map =
              LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
          if (map && ![map isInitialized]) {
            return NO;
          }
        }
      }
    }
  }

  __block BOOL result = YES;
  [extensionMap_
      enumerateKeysAndObjectsUsingBlock:^(LCGPBExtensionDescriptor *extension,
                                          id obj,
                                          BOOL *stop) {
        if (LCGPBExtensionIsMessage(extension)) {
          if (extension.isRepeated) {
            for (LCGPBMessage *msg in obj) {
              if (!msg.initialized) {
                result = NO;
                *stop = YES;
                break;
              }
            }
          } else {
            LCGPBMessage *asMsg = obj;
            if (!asMsg.initialized) {
              result = NO;
              *stop = YES;
            }
          }
        }
      }];
  return result;
}

- (LCGPBDescriptor *)descriptor {
  return [[self class] descriptor];
}

- (NSData *)data {
#ifdef DEBUG
  if (!self.initialized) {
    return nil;
  }
#endif
  NSMutableData *data = [NSMutableData dataWithLength:[self serializedSize]];
  LCGPBCodedOutputStream *stream =
      [[LCGPBCodedOutputStream alloc] initWithData:data];
  @try {
    [self writeToCodedOutputStream:stream];
  }
  @catch (NSException *exception) {
    // This really shouldn't happen. The only way writeToCodedOutputStream:
    // could throw is if something in the library has a bug and the
    // serializedSize was wrong.
#ifdef DEBUG
    NSLog(@"%@: Internal exception while building message data: %@",
          [self class], exception);
#endif
    data = nil;
  }
  [stream release];
  return data;
}

- (NSData *)delimitedData {
  size_t serializedSize = [self serializedSize];
  size_t varintSize = LCGPBComputeRawVarint32SizeForInteger(serializedSize);
  NSMutableData *data =
      [NSMutableData dataWithLength:(serializedSize + varintSize)];
  LCGPBCodedOutputStream *stream =
      [[LCGPBCodedOutputStream alloc] initWithData:data];
  @try {
    [self writeDelimitedToCodedOutputStream:stream];
  }
  @catch (NSException *exception) {
    // This really shouldn't happen.  The only way writeToCodedOutputStream:
    // could throw is if something in the library has a bug and the
    // serializedSize was wrong.
#ifdef DEBUG
    NSLog(@"%@: Internal exception while building message delimitedData: %@",
          [self class], exception);
#endif
    // If it happens, truncate.
    data.length = 0;
  }
  [stream release];
  return data;
}

- (void)writeToOutputStream:(NSOutputStream *)output {
  LCGPBCodedOutputStream *stream =
      [[LCGPBCodedOutputStream alloc] initWithOutputStream:output];
  [self writeToCodedOutputStream:stream];
  [stream release];
}

- (void)writeToCodedOutputStream:(LCGPBCodedOutputStream *)output {
  LCGPBDescriptor *descriptor = [self descriptor];
  NSArray *fieldsArray = descriptor->fields_;
  NSUInteger fieldCount = fieldsArray.count;
  const LCGPBExtensionRange *extensionRanges = descriptor.extensionRanges;
  NSUInteger extensionRangesCount = descriptor.extensionRangesCount;
  NSArray *sortedExtensions =
      [[extensionMap_ allKeys] sortedArrayUsingSelector:@selector(compareByFieldNumber:)];
  for (NSUInteger i = 0, j = 0; i < fieldCount || j < extensionRangesCount;) {
    if (i == fieldCount) {
      [self writeExtensionsToCodedOutputStream:output
                                         range:extensionRanges[j++]
                              sortedExtensions:sortedExtensions];
    } else if (j == extensionRangesCount ||
               LCGPBFieldNumber(fieldsArray[i]) < extensionRanges[j].start) {
      [self writeField:fieldsArray[i++] toCodedOutputStream:output];
    } else {
      [self writeExtensionsToCodedOutputStream:output
                                         range:extensionRanges[j++]
                              sortedExtensions:sortedExtensions];
    }
  }
  if (descriptor.isWireFormat) {
    [unknownFields_ writeAsMessageSetTo:output];
  } else {
    [unknownFields_ writeToCodedOutputStream:output];
  }
}

- (void)writeDelimitedToOutputStream:(NSOutputStream *)output {
  LCGPBCodedOutputStream *codedOutput =
      [[LCGPBCodedOutputStream alloc] initWithOutputStream:output];
  [self writeDelimitedToCodedOutputStream:codedOutput];
  [codedOutput release];
}

- (void)writeDelimitedToCodedOutputStream:(LCGPBCodedOutputStream *)output {
  [output writeRawVarintSizeTAs32:[self serializedSize]];
  [self writeToCodedOutputStream:output];
}

- (void)writeField:(LCGPBFieldDescriptor *)field
    toCodedOutputStream:(LCGPBCodedOutputStream *)output {
  LCGPBFieldType fieldType = field.fieldType;
  if (fieldType == LCGPBFieldTypeSingle) {
    BOOL has = LCGPBGetHasIvarField(self, field);
    if (!has) {
      return;
    }
  }
  uint32_t fieldNumber = LCGPBFieldNumber(field);

//%PDDM-DEFINE FIELD_CASE(TYPE, REAL_TYPE)
//%FIELD_CASE_FULL(TYPE, REAL_TYPE, REAL_TYPE)
//%PDDM-DEFINE FIELD_CASE_FULL(TYPE, REAL_TYPE, ARRAY_TYPE)
//%    case LCGPBDataType##TYPE:
//%      if (fieldType == LCGPBFieldTypeRepeated) {
//%        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
//%        LCGPB##ARRAY_TYPE##Array *array =
//%            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
//%        [output write##TYPE##Array:fieldNumber values:array tag:tag];
//%      } else if (fieldType == LCGPBFieldTypeSingle) {
//%        [output write##TYPE:fieldNumber
//%              TYPE$S  value:LCGPBGetMessage##REAL_TYPE##Field(self, field)];
//%      } else {  // fieldType == LCGPBFieldTypeMap
//%        // Exact type here doesn't matter.
//%        LCGPBInt32##ARRAY_TYPE##Dictionary *dict =
//%            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
//%        [dict writeToCodedOutputStream:output asField:field];
//%      }
//%      break;
//%
//%PDDM-DEFINE FIELD_CASE2(TYPE)
//%    case LCGPBDataType##TYPE:
//%      if (fieldType == LCGPBFieldTypeRepeated) {
//%        NSArray *array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
//%        [output write##TYPE##Array:fieldNumber values:array];
//%      } else if (fieldType == LCGPBFieldTypeSingle) {
//%        // LCGPBGetObjectIvarWithFieldNoAutocreate() avoids doing the has check
//%        // again.
//%        [output write##TYPE:fieldNumber
//%              TYPE$S  value:LCGPBGetObjectIvarWithFieldNoAutocreate(self, field)];
//%      } else {  // fieldType == LCGPBFieldTypeMap
//%        // Exact type here doesn't matter.
//%        id dict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
//%        LCGPBDataType mapKeyDataType = field.mapKeyDataType;
//%        if (mapKeyDataType == LCGPBDataTypeString) {
//%          LCGPBDictionaryWriteToStreamInternalHelper(output, dict, field);
//%        } else {
//%          [dict writeToCodedOutputStream:output asField:field];
//%        }
//%      }
//%      break;
//%

  switch (LCGPBGetFieldDataType(field)) {

//%PDDM-EXPAND FIELD_CASE(Bool, Bool)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeBool:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBBoolArray *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeBoolArray:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeBool:fieldNumber
                    value:LCGPBGetMessageBoolField(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32BoolDictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(Fixed32, UInt32)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeFixed32:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBUInt32Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeFixed32Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeFixed32:fieldNumber
                       value:LCGPBGetMessageUInt32Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32UInt32Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(SFixed32, Int32)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeSFixed32:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBInt32Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeSFixed32Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeSFixed32:fieldNumber
                        value:LCGPBGetMessageInt32Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32Int32Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(Float, Float)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeFloat:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBFloatArray *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeFloatArray:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeFloat:fieldNumber
                     value:LCGPBGetMessageFloatField(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32FloatDictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(Fixed64, UInt64)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeFixed64:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBUInt64Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeFixed64Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeFixed64:fieldNumber
                       value:LCGPBGetMessageUInt64Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32UInt64Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(SFixed64, Int64)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeSFixed64:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBInt64Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeSFixed64Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeSFixed64:fieldNumber
                        value:LCGPBGetMessageInt64Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32Int64Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(Double, Double)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeDouble:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBDoubleArray *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeDoubleArray:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeDouble:fieldNumber
                      value:LCGPBGetMessageDoubleField(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32DoubleDictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(Int32, Int32)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeInt32:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBInt32Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeInt32Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeInt32:fieldNumber
                     value:LCGPBGetMessageInt32Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32Int32Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(Int64, Int64)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeInt64:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBInt64Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeInt64Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeInt64:fieldNumber
                     value:LCGPBGetMessageInt64Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32Int64Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(SInt32, Int32)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeSInt32:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBInt32Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeSInt32Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeSInt32:fieldNumber
                      value:LCGPBGetMessageInt32Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32Int32Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(SInt64, Int64)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeSInt64:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBInt64Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeSInt64Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeSInt64:fieldNumber
                      value:LCGPBGetMessageInt64Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32Int64Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(UInt32, UInt32)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeUInt32:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBUInt32Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeUInt32Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeUInt32:fieldNumber
                      value:LCGPBGetMessageUInt32Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32UInt32Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE(UInt64, UInt64)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeUInt64:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBUInt64Array *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeUInt64Array:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeUInt64:fieldNumber
                      value:LCGPBGetMessageUInt64Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32UInt64Dictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE_FULL(Enum, Int32, Enum)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeEnum:
      if (fieldType == LCGPBFieldTypeRepeated) {
        uint32_t tag = field.isPackable ? LCGPBFieldTag(field) : 0;
        LCGPBEnumArray *array =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeEnumArray:fieldNumber values:array tag:tag];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        [output writeEnum:fieldNumber
                    value:LCGPBGetMessageInt32Field(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        LCGPBInt32EnumDictionary *dict =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [dict writeToCodedOutputStream:output asField:field];
      }
      break;

//%PDDM-EXPAND FIELD_CASE2(Bytes)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeBytes:
      if (fieldType == LCGPBFieldTypeRepeated) {
        NSArray *array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeBytesArray:fieldNumber values:array];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        // LCGPBGetObjectIvarWithFieldNoAutocreate() avoids doing the has check
        // again.
        [output writeBytes:fieldNumber
                     value:LCGPBGetObjectIvarWithFieldNoAutocreate(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        id dict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        LCGPBDataType mapKeyDataType = field.mapKeyDataType;
        if (mapKeyDataType == LCGPBDataTypeString) {
          LCGPBDictionaryWriteToStreamInternalHelper(output, dict, field);
        } else {
          [dict writeToCodedOutputStream:output asField:field];
        }
      }
      break;

//%PDDM-EXPAND FIELD_CASE2(String)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeString:
      if (fieldType == LCGPBFieldTypeRepeated) {
        NSArray *array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeStringArray:fieldNumber values:array];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        // LCGPBGetObjectIvarWithFieldNoAutocreate() avoids doing the has check
        // again.
        [output writeString:fieldNumber
                      value:LCGPBGetObjectIvarWithFieldNoAutocreate(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        id dict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        LCGPBDataType mapKeyDataType = field.mapKeyDataType;
        if (mapKeyDataType == LCGPBDataTypeString) {
          LCGPBDictionaryWriteToStreamInternalHelper(output, dict, field);
        } else {
          [dict writeToCodedOutputStream:output asField:field];
        }
      }
      break;

//%PDDM-EXPAND FIELD_CASE2(Message)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeMessage:
      if (fieldType == LCGPBFieldTypeRepeated) {
        NSArray *array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeMessageArray:fieldNumber values:array];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        // LCGPBGetObjectIvarWithFieldNoAutocreate() avoids doing the has check
        // again.
        [output writeMessage:fieldNumber
                       value:LCGPBGetObjectIvarWithFieldNoAutocreate(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        id dict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        LCGPBDataType mapKeyDataType = field.mapKeyDataType;
        if (mapKeyDataType == LCGPBDataTypeString) {
          LCGPBDictionaryWriteToStreamInternalHelper(output, dict, field);
        } else {
          [dict writeToCodedOutputStream:output asField:field];
        }
      }
      break;

//%PDDM-EXPAND FIELD_CASE2(Group)
// This block of code is generated, do not edit it directly.

    case LCGPBDataTypeGroup:
      if (fieldType == LCGPBFieldTypeRepeated) {
        NSArray *array = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [output writeGroupArray:fieldNumber values:array];
      } else if (fieldType == LCGPBFieldTypeSingle) {
        // LCGPBGetObjectIvarWithFieldNoAutocreate() avoids doing the has check
        // again.
        [output writeGroup:fieldNumber
                     value:LCGPBGetObjectIvarWithFieldNoAutocreate(self, field)];
      } else {  // fieldType == LCGPBFieldTypeMap
        // Exact type here doesn't matter.
        id dict = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        LCGPBDataType mapKeyDataType = field.mapKeyDataType;
        if (mapKeyDataType == LCGPBDataTypeString) {
          LCGPBDictionaryWriteToStreamInternalHelper(output, dict, field);
        } else {
          [dict writeToCodedOutputStream:output asField:field];
        }
      }
      break;

//%PDDM-EXPAND-END (18 expansions)
  }
}

#pragma mark - Extensions

- (id)getExtension:(LCGPBExtensionDescriptor *)extension {
  CheckExtension(self, extension);
  id value = [extensionMap_ objectForKey:extension];
  if (value != nil) {
    return value;
  }

  // No default for repeated.
  if (extension.isRepeated) {
    return nil;
  }
  // Non messages get their default.
  if (!LCGPBExtensionIsMessage(extension)) {
    return extension.defaultValue;
  }

  // Check for an autocreated value.
  LCGPBPrepareReadOnlySemaphore(self);
  dispatch_semaphore_wait(readOnlySemaphore_, DISPATCH_TIME_FOREVER);
  value = [autocreatedExtensionMap_ objectForKey:extension];
  if (!value) {
    // Auto create the message extensions to match normal fields.
    value = CreateMessageWithAutocreatorForExtension(extension.msgClass, self,
                                                     extension);

    if (autocreatedExtensionMap_ == nil) {
      autocreatedExtensionMap_ = [[NSMutableDictionary alloc] init];
    }

    // We can't simply call setExtension here because that would clear the new
    // value's autocreator.
    [autocreatedExtensionMap_ setObject:value forKey:extension];
    [value release];
  }

  dispatch_semaphore_signal(readOnlySemaphore_);
  return value;
}

- (id)getExistingExtension:(LCGPBExtensionDescriptor *)extension {
  // This is an internal method so we don't need to call CheckExtension().
  return [extensionMap_ objectForKey:extension];
}

- (BOOL)hasExtension:(LCGPBExtensionDescriptor *)extension {
#if defined(DEBUG) && DEBUG
  CheckExtension(self, extension);
#endif  // DEBUG
  return nil != [extensionMap_ objectForKey:extension];
}

- (NSArray *)extensionsCurrentlySet {
  return [extensionMap_ allKeys];
}

- (void)writeExtensionsToCodedOutputStream:(LCGPBCodedOutputStream *)output
                                     range:(LCGPBExtensionRange)range
                          sortedExtensions:(NSArray *)sortedExtensions {
  uint32_t start = range.start;
  uint32_t end = range.end;
  for (LCGPBExtensionDescriptor *extension in sortedExtensions) {
    uint32_t fieldNumber = extension.fieldNumber;
    if (fieldNumber < start) {
      continue;
    }
    if (fieldNumber >= end) {
      break;
    }
    id value = [extensionMap_ objectForKey:extension];
    LCGPBWriteExtensionValueToOutputStream(extension, value, output);
  }
}

- (void)setExtension:(LCGPBExtensionDescriptor *)extension value:(id)value {
  if (!value) {
    [self clearExtension:extension];
    return;
  }

  CheckExtension(self, extension);

  if (extension.repeated) {
    [NSException raise:NSInvalidArgumentException
                format:@"Must call addExtension() for repeated types."];
  }

  if (extensionMap_ == nil) {
    extensionMap_ = [[NSMutableDictionary alloc] init];
  }

  // This pointless cast is for CLANG_WARN_NULLABLE_TO_NONNULL_CONVERSION.
  // Without it, the compiler complains we're passing an id nullable when
  // setObject:forKey: requires a id nonnull for the value. The check for
  // !value at the start of the method ensures it isn't nil, but the check
  // isn't smart enough to realize that.
  [extensionMap_ setObject:(id)value forKey:extension];

  LCGPBExtensionDescriptor *descriptor = extension;

  if (LCGPBExtensionIsMessage(descriptor) && !descriptor.isRepeated) {
    LCGPBMessage *autocreatedValue =
        [[autocreatedExtensionMap_ objectForKey:extension] retain];
    // Must remove from the map before calling LCGPBClearMessageAutocreator() so
    // that LCGPBClearMessageAutocreator() knows its safe to clear.
    [autocreatedExtensionMap_ removeObjectForKey:extension];
    LCGPBClearMessageAutocreator(autocreatedValue);
    [autocreatedValue release];
  }

  LCGPBBecomeVisibleToAutocreator(self);
}

- (void)addExtension:(LCGPBExtensionDescriptor *)extension value:(id)value {
  CheckExtension(self, extension);

  if (!extension.repeated) {
    [NSException raise:NSInvalidArgumentException
                format:@"Must call setExtension() for singular types."];
  }

  if (extensionMap_ == nil) {
    extensionMap_ = [[NSMutableDictionary alloc] init];
  }
  NSMutableArray *list = [extensionMap_ objectForKey:extension];
  if (list == nil) {
    list = [NSMutableArray array];
    [extensionMap_ setObject:list forKey:extension];
  }

  [list addObject:value];
  LCGPBBecomeVisibleToAutocreator(self);
}

- (void)setExtension:(LCGPBExtensionDescriptor *)extension
               index:(NSUInteger)idx
               value:(id)value {
  CheckExtension(self, extension);

  if (!extension.repeated) {
    [NSException raise:NSInvalidArgumentException
                format:@"Must call setExtension() for singular types."];
  }

  if (extensionMap_ == nil) {
    extensionMap_ = [[NSMutableDictionary alloc] init];
  }

  NSMutableArray *list = [extensionMap_ objectForKey:extension];

  [list replaceObjectAtIndex:idx withObject:value];
  LCGPBBecomeVisibleToAutocreator(self);
}

- (void)clearExtension:(LCGPBExtensionDescriptor *)extension {
  CheckExtension(self, extension);

  // Only become visible if there was actually a value to clear.
  if ([extensionMap_ objectForKey:extension]) {
    [extensionMap_ removeObjectForKey:extension];
    LCGPBBecomeVisibleToAutocreator(self);
  }
}

#pragma mark - mergeFrom

- (void)mergeFromData:(NSData *)data
    extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry {
  LCGPBCodedInputStream *input = [[LCGPBCodedInputStream alloc] initWithData:data];
  [self mergeFromCodedInputStream:input extensionRegistry:extensionRegistry];
  [input checkLastTagWas:0];
  [input release];
}

#pragma mark - mergeDelimitedFrom

- (void)mergeDelimitedFromCodedInputStream:(LCGPBCodedInputStream *)input
                         extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry {
  LCGPBCodedInputStreamState *state = &input->state_;
  if (LCGPBCodedInputStreamIsAtEnd(state)) {
    return;
  }
  NSData *data = LCGPBCodedInputStreamReadRetainedBytesNoCopy(state);
  if (data == nil) {
    return;
  }
  [self mergeFromData:data extensionRegistry:extensionRegistry];
  [data release];
}

#pragma mark - Parse From Data Support

+ (instancetype)parseFromData:(NSData *)data error:(NSError **)errorPtr {
  return [self parseFromData:data extensionRegistry:nil error:errorPtr];
}

+ (instancetype)parseFromData:(NSData *)data
            extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry
                        error:(NSError **)errorPtr {
  return [[[self alloc] initWithData:data
                   extensionRegistry:extensionRegistry
                               error:errorPtr] autorelease];
}

+ (instancetype)parseFromCodedInputStream:(LCGPBCodedInputStream *)input
                        extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry
                                    error:(NSError **)errorPtr {
  return
      [[[self alloc] initWithCodedInputStream:input
                            extensionRegistry:extensionRegistry
                                        error:errorPtr] autorelease];
}

#pragma mark - Parse Delimited From Data Support

+ (instancetype)parseDelimitedFromCodedInputStream:(LCGPBCodedInputStream *)input
                                 extensionRegistry:
                                     (LCGPBExtensionRegistry *)extensionRegistry
                                             error:(NSError **)errorPtr {
  LCGPBMessage *message = [[[self alloc] init] autorelease];
  @try {
    [message mergeDelimitedFromCodedInputStream:input
                              extensionRegistry:extensionRegistry];
    if (errorPtr) {
      *errorPtr = nil;
    }
  }
  @catch (NSException *exception) {
    message = nil;
    if (errorPtr) {
      *errorPtr = ErrorFromException(exception);
    }
  }
#ifdef DEBUG
  if (message && !message.initialized) {
    message = nil;
    if (errorPtr) {
      *errorPtr = MessageError(LCGPBMessageErrorCodeMissingRequiredField, nil);
    }
  }
#endif
  return message;
}

#pragma mark - Unknown Field Support

- (LCGPBUnknownFieldSet *)unknownFields {
  return unknownFields_;
}

- (void)setUnknownFields:(LCGPBUnknownFieldSet *)unknownFields {
  if (unknownFields != unknownFields_) {
    [unknownFields_ release];
    unknownFields_ = [unknownFields copy];
    LCGPBBecomeVisibleToAutocreator(self);
  }
}

- (void)parseMessageSet:(LCGPBCodedInputStream *)input
      extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry {
  uint32_t typeId = 0;
  NSData *rawBytes = nil;
  LCGPBExtensionDescriptor *extension = nil;
  LCGPBCodedInputStreamState *state = &input->state_;
  while (true) {
    uint32_t tag = LCGPBCodedInputStreamReadTag(state);
    if (tag == 0) {
      break;
    }

    if (tag == LCGPBWireFormatMessageSetTypeIdTag) {
      typeId = LCGPBCodedInputStreamReadUInt32(state);
      if (typeId != 0) {
        extension = [extensionRegistry extensionForDescriptor:[self descriptor]
                                                  fieldNumber:typeId];
      }
    } else if (tag == LCGPBWireFormatMessageSetMessageTag) {
      rawBytes =
          [LCGPBCodedInputStreamReadRetainedBytesNoCopy(state) autorelease];
    } else {
      if (![input skipField:tag]) {
        break;
      }
    }
  }

  [input checkLastTagWas:LCGPBWireFormatMessageSetItemEndTag];

  if (rawBytes != nil && typeId != 0) {
    if (extension != nil) {
      LCGPBCodedInputStream *newInput =
          [[LCGPBCodedInputStream alloc] initWithData:rawBytes];
      LCGPBExtensionMergeFromInputStream(extension,
                                       extension.packable,
                                       newInput,
                                       extensionRegistry,
                                       self);
      [newInput release];
    } else {
      LCGPBUnknownFieldSet *unknownFields = GetOrMakeUnknownFields(self);
      // rawBytes was created via a NoCopy, so it can be reusing a
      // subrange of another NSData that might go out of scope as things
      // unwind, so a copy is needed to ensure what is saved in the
      // unknown fields stays valid.
      NSData *cloned = [NSData dataWithData:rawBytes];
      [unknownFields mergeMessageSetMessage:typeId data:cloned];
    }
  }
}

- (BOOL)parseUnknownField:(LCGPBCodedInputStream *)input
        extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry
                      tag:(uint32_t)tag {
  LCGPBWireFormat wireType = LCGPBWireFormatGetTagWireType(tag);
  int32_t fieldNumber = LCGPBWireFormatGetTagFieldNumber(tag);

  LCGPBDescriptor *descriptor = [self descriptor];
  LCGPBExtensionDescriptor *extension =
      [extensionRegistry extensionForDescriptor:descriptor
                                    fieldNumber:fieldNumber];
  if (extension == nil) {
    if (descriptor.wireFormat && LCGPBWireFormatMessageSetItemTag == tag) {
      [self parseMessageSet:input extensionRegistry:extensionRegistry];
      return YES;
    }
  } else {
    if (extension.wireType == wireType) {
      LCGPBExtensionMergeFromInputStream(extension,
                                       extension.packable,
                                       input,
                                       extensionRegistry,
                                       self);
      return YES;
    }
    // Primitive, repeated types can be packed on unpacked on the wire, and are
    // parsed either way.
    if ([extension isRepeated] &&
        !LCGPBDataTypeIsObject(extension->description_->dataType) &&
        (extension.alternateWireType == wireType)) {
      LCGPBExtensionMergeFromInputStream(extension,
                                       !extension.packable,
                                       input,
                                       extensionRegistry,
                                       self);
      return YES;
    }
  }
  if ([LCGPBUnknownFieldSet isFieldTag:tag]) {
    LCGPBUnknownFieldSet *unknownFields = GetOrMakeUnknownFields(self);
    return [unknownFields mergeFieldFrom:tag input:input];
  } else {
    return NO;
  }
}

- (void)addUnknownMapEntry:(int32_t)fieldNum value:(NSData *)data {
  LCGPBUnknownFieldSet *unknownFields = GetOrMakeUnknownFields(self);
  [unknownFields addUnknownMapEntry:fieldNum value:data];
}

#pragma mark - MergeFromCodedInputStream Support

static void MergeSingleFieldFromCodedInputStream(
    LCGPBMessage *self, LCGPBFieldDescriptor *field, LCGPBFileSyntax syntax,
    LCGPBCodedInputStream *input, LCGPBExtensionRegistry *extensionRegistry) {
  LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
  switch (fieldDataType) {
#define CASE_SINGLE_POD(NAME, TYPE, FUNC_TYPE)                             \
    case LCGPBDataType##NAME: {                                              \
      TYPE val = LCGPBCodedInputStreamRead##NAME(&input->state_);            \
      LCGPBSet##FUNC_TYPE##IvarWithFieldInternal(self, field, val, syntax);  \
      break;                                                               \
            }
#define CASE_SINGLE_OBJECT(NAME)                                           \
    case LCGPBDataType##NAME: {                                              \
      id val = LCGPBCodedInputStreamReadRetained##NAME(&input->state_);      \
      LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, val, syntax); \
      break;                                                               \
    }
      CASE_SINGLE_POD(Bool, BOOL, Bool)
      CASE_SINGLE_POD(Fixed32, uint32_t, UInt32)
      CASE_SINGLE_POD(SFixed32, int32_t, Int32)
      CASE_SINGLE_POD(Float, float, Float)
      CASE_SINGLE_POD(Fixed64, uint64_t, UInt64)
      CASE_SINGLE_POD(SFixed64, int64_t, Int64)
      CASE_SINGLE_POD(Double, double, Double)
      CASE_SINGLE_POD(Int32, int32_t, Int32)
      CASE_SINGLE_POD(Int64, int64_t, Int64)
      CASE_SINGLE_POD(SInt32, int32_t, Int32)
      CASE_SINGLE_POD(SInt64, int64_t, Int64)
      CASE_SINGLE_POD(UInt32, uint32_t, UInt32)
      CASE_SINGLE_POD(UInt64, uint64_t, UInt64)
      CASE_SINGLE_OBJECT(Bytes)
      CASE_SINGLE_OBJECT(String)
#undef CASE_SINGLE_POD
#undef CASE_SINGLE_OBJECT

    case LCGPBDataTypeMessage: {
      if (LCGPBGetHasIvarField(self, field)) {
        // LCGPBGetObjectIvarWithFieldNoAutocreate() avoids doing the has
        // check again.
        LCGPBMessage *message =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [input readMessage:message extensionRegistry:extensionRegistry];
      } else {
        LCGPBMessage *message = [[field.msgClass alloc] init];
        [input readMessage:message extensionRegistry:extensionRegistry];
        LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, message, syntax);
      }
      break;
    }

    case LCGPBDataTypeGroup: {
      if (LCGPBGetHasIvarField(self, field)) {
        // LCGPBGetObjectIvarWithFieldNoAutocreate() avoids doing the has
        // check again.
        LCGPBMessage *message =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
        [input readGroup:LCGPBFieldNumber(field)
                      message:message
            extensionRegistry:extensionRegistry];
      } else {
        LCGPBMessage *message = [[field.msgClass alloc] init];
        [input readGroup:LCGPBFieldNumber(field)
                      message:message
            extensionRegistry:extensionRegistry];
        LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, message, syntax);
      }
      break;
    }

    case LCGPBDataTypeEnum: {
      int32_t val = LCGPBCodedInputStreamReadEnum(&input->state_);
      if (LCGPBHasPreservingUnknownEnumSemantics(syntax) ||
          [field isValidEnumValue:val]) {
        LCGPBSetInt32IvarWithFieldInternal(self, field, val, syntax);
      } else {
        LCGPBUnknownFieldSet *unknownFields = GetOrMakeUnknownFields(self);
        [unknownFields mergeVarintField:LCGPBFieldNumber(field) value:val];
      }
    }
  }  // switch
}

static void MergeRepeatedPackedFieldFromCodedInputStream(
    LCGPBMessage *self, LCGPBFieldDescriptor *field, LCGPBFileSyntax syntax,
    LCGPBCodedInputStream *input) {
  LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
  LCGPBCodedInputStreamState *state = &input->state_;
  id genericArray = GetOrCreateArrayIvarWithField(self, field, syntax);
  int32_t length = LCGPBCodedInputStreamReadInt32(state);
  size_t limit = LCGPBCodedInputStreamPushLimit(state, length);
  while (LCGPBCodedInputStreamBytesUntilLimit(state) > 0) {
    switch (fieldDataType) {
#define CASE_REPEATED_PACKED_POD(NAME, TYPE, ARRAY_TYPE)      \
     case LCGPBDataType##NAME: {                                \
       TYPE val = LCGPBCodedInputStreamRead##NAME(state);       \
       [(LCGPB##ARRAY_TYPE##Array *)genericArray addValue:val]; \
       break;                                                 \
     }
        CASE_REPEATED_PACKED_POD(Bool, BOOL, Bool)
        CASE_REPEATED_PACKED_POD(Fixed32, uint32_t, UInt32)
        CASE_REPEATED_PACKED_POD(SFixed32, int32_t, Int32)
        CASE_REPEATED_PACKED_POD(Float, float, Float)
        CASE_REPEATED_PACKED_POD(Fixed64, uint64_t, UInt64)
        CASE_REPEATED_PACKED_POD(SFixed64, int64_t, Int64)
        CASE_REPEATED_PACKED_POD(Double, double, Double)
        CASE_REPEATED_PACKED_POD(Int32, int32_t, Int32)
        CASE_REPEATED_PACKED_POD(Int64, int64_t, Int64)
        CASE_REPEATED_PACKED_POD(SInt32, int32_t, Int32)
        CASE_REPEATED_PACKED_POD(SInt64, int64_t, Int64)
        CASE_REPEATED_PACKED_POD(UInt32, uint32_t, UInt32)
        CASE_REPEATED_PACKED_POD(UInt64, uint64_t, UInt64)
#undef CASE_REPEATED_PACKED_POD

      case LCGPBDataTypeBytes:
      case LCGPBDataTypeString:
      case LCGPBDataTypeMessage:
      case LCGPBDataTypeGroup:
        NSCAssert(NO, @"Non primitive types can't be packed");
        break;

      case LCGPBDataTypeEnum: {
        int32_t val = LCGPBCodedInputStreamReadEnum(state);
        if (LCGPBHasPreservingUnknownEnumSemantics(syntax) ||
            [field isValidEnumValue:val]) {
          [(LCGPBEnumArray*)genericArray addRawValue:val];
        } else {
          LCGPBUnknownFieldSet *unknownFields = GetOrMakeUnknownFields(self);
          [unknownFields mergeVarintField:LCGPBFieldNumber(field) value:val];
        }
        break;
      }
    }  // switch
  }  // while(BytesUntilLimit() > 0)
  LCGPBCodedInputStreamPopLimit(state, limit);
}

static void MergeRepeatedNotPackedFieldFromCodedInputStream(
    LCGPBMessage *self, LCGPBFieldDescriptor *field, LCGPBFileSyntax syntax,
    LCGPBCodedInputStream *input, LCGPBExtensionRegistry *extensionRegistry) {
  LCGPBCodedInputStreamState *state = &input->state_;
  id genericArray = GetOrCreateArrayIvarWithField(self, field, syntax);
  switch (LCGPBGetFieldDataType(field)) {
#define CASE_REPEATED_NOT_PACKED_POD(NAME, TYPE, ARRAY_TYPE) \
   case LCGPBDataType##NAME: {                                 \
     TYPE val = LCGPBCodedInputStreamRead##NAME(state);        \
     [(LCGPB##ARRAY_TYPE##Array *)genericArray addValue:val];  \
     break;                                                  \
   }
#define CASE_REPEATED_NOT_PACKED_OBJECT(NAME)                \
   case LCGPBDataType##NAME: {                                 \
     id val = LCGPBCodedInputStreamReadRetained##NAME(state);  \
     [(NSMutableArray*)genericArray addObject:val];          \
     [val release];                                          \
     break;                                                  \
   }
      CASE_REPEATED_NOT_PACKED_POD(Bool, BOOL, Bool)
      CASE_REPEATED_NOT_PACKED_POD(Fixed32, uint32_t, UInt32)
      CASE_REPEATED_NOT_PACKED_POD(SFixed32, int32_t, Int32)
      CASE_REPEATED_NOT_PACKED_POD(Float, float, Float)
      CASE_REPEATED_NOT_PACKED_POD(Fixed64, uint64_t, UInt64)
      CASE_REPEATED_NOT_PACKED_POD(SFixed64, int64_t, Int64)
      CASE_REPEATED_NOT_PACKED_POD(Double, double, Double)
      CASE_REPEATED_NOT_PACKED_POD(Int32, int32_t, Int32)
      CASE_REPEATED_NOT_PACKED_POD(Int64, int64_t, Int64)
      CASE_REPEATED_NOT_PACKED_POD(SInt32, int32_t, Int32)
      CASE_REPEATED_NOT_PACKED_POD(SInt64, int64_t, Int64)
      CASE_REPEATED_NOT_PACKED_POD(UInt32, uint32_t, UInt32)
      CASE_REPEATED_NOT_PACKED_POD(UInt64, uint64_t, UInt64)
      CASE_REPEATED_NOT_PACKED_OBJECT(Bytes)
      CASE_REPEATED_NOT_PACKED_OBJECT(String)
#undef CASE_REPEATED_NOT_PACKED_POD
#undef CASE_NOT_PACKED_OBJECT
    case LCGPBDataTypeMessage: {
      LCGPBMessage *message = [[field.msgClass alloc] init];
      [input readMessage:message extensionRegistry:extensionRegistry];
      [(NSMutableArray*)genericArray addObject:message];
      [message release];
      break;
    }
    case LCGPBDataTypeGroup: {
      LCGPBMessage *message = [[field.msgClass alloc] init];
      [input readGroup:LCGPBFieldNumber(field)
                    message:message
          extensionRegistry:extensionRegistry];
      [(NSMutableArray*)genericArray addObject:message];
      [message release];
      break;
    }
    case LCGPBDataTypeEnum: {
      int32_t val = LCGPBCodedInputStreamReadEnum(state);
      if (LCGPBHasPreservingUnknownEnumSemantics(syntax) ||
          [field isValidEnumValue:val]) {
        [(LCGPBEnumArray*)genericArray addRawValue:val];
      } else {
        LCGPBUnknownFieldSet *unknownFields = GetOrMakeUnknownFields(self);
        [unknownFields mergeVarintField:LCGPBFieldNumber(field) value:val];
      }
      break;
    }
  }  // switch
}

- (void)mergeFromCodedInputStream:(LCGPBCodedInputStream *)input
                extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry {
  LCGPBDescriptor *descriptor = [self descriptor];
  LCGPBFileSyntax syntax = descriptor.file.syntax;
  LCGPBCodedInputStreamState *state = &input->state_;
  uint32_t tag = 0;
  NSUInteger startingIndex = 0;
  NSArray *fields = descriptor->fields_;
  NSUInteger numFields = fields.count;
  while (YES) {
    BOOL merged = NO;
    tag = LCGPBCodedInputStreamReadTag(state);
    if (tag == 0) {
      break;  // Reached end.
    }
    for (NSUInteger i = 0; i < numFields; ++i) {
      if (startingIndex >= numFields) startingIndex = 0;
      LCGPBFieldDescriptor *fieldDescriptor = fields[startingIndex];
      if (LCGPBFieldTag(fieldDescriptor) == tag) {
        LCGPBFieldType fieldType = fieldDescriptor.fieldType;
        if (fieldType == LCGPBFieldTypeSingle) {
          MergeSingleFieldFromCodedInputStream(self, fieldDescriptor, syntax,
                                               input, extensionRegistry);
          // Well formed protos will only have a single field once, advance
          // the starting index to the next field.
          startingIndex += 1;
        } else if (fieldType == LCGPBFieldTypeRepeated) {
          if (fieldDescriptor.isPackable) {
            MergeRepeatedPackedFieldFromCodedInputStream(
                self, fieldDescriptor, syntax, input);
            // Well formed protos will only have a repeated field that is
            // packed once, advance the starting index to the next field.
            startingIndex += 1;
          } else {
            MergeRepeatedNotPackedFieldFromCodedInputStream(
                self, fieldDescriptor, syntax, input, extensionRegistry);
          }
        } else {  // fieldType == LCGPBFieldTypeMap
          // LCGPB*Dictionary or NSDictionary, exact type doesn't matter at this
          // point.
          id map = GetOrCreateMapIvarWithField(self, fieldDescriptor, syntax);
          [input readMapEntry:map
            extensionRegistry:extensionRegistry
                        field:fieldDescriptor
                parentMessage:self];
        }
        merged = YES;
        break;
      } else {
        startingIndex += 1;
      }
    }  // for(i < numFields)

    if (!merged && (tag != 0)) {
      // Primitive, repeated types can be packed on unpacked on the wire, and
      // are parsed either way.  The above loop covered tag in the preferred
      // for, so this need to check the alternate form.
      for (NSUInteger i = 0; i < numFields; ++i) {
        if (startingIndex >= numFields) startingIndex = 0;
        LCGPBFieldDescriptor *fieldDescriptor = fields[startingIndex];
        if ((fieldDescriptor.fieldType == LCGPBFieldTypeRepeated) &&
            !LCGPBFieldDataTypeIsObject(fieldDescriptor) &&
            (LCGPBFieldAlternateTag(fieldDescriptor) == tag)) {
          BOOL alternateIsPacked = !fieldDescriptor.isPackable;
          if (alternateIsPacked) {
            MergeRepeatedPackedFieldFromCodedInputStream(
                self, fieldDescriptor, syntax, input);
            // Well formed protos will only have a repeated field that is
            // packed once, advance the starting index to the next field.
            startingIndex += 1;
          } else {
            MergeRepeatedNotPackedFieldFromCodedInputStream(
                self, fieldDescriptor, syntax, input, extensionRegistry);
          }
          merged = YES;
          break;
        } else {
          startingIndex += 1;
        }
      }
    }

    if (!merged) {
      if (tag == 0) {
        // zero signals EOF / limit reached
        return;
      } else {
        if (![self parseUnknownField:input
                   extensionRegistry:extensionRegistry
                                 tag:tag]) {
          // it's an endgroup tag
          return;
        }
      }
    }  // if(!merged)

  }  // while(YES)
}

#pragma mark - MergeFrom Support

- (void)mergeFrom:(LCGPBMessage *)other {
  Class selfClass = [self class];
  Class otherClass = [other class];
  if (!([selfClass isSubclassOfClass:otherClass] ||
        [otherClass isSubclassOfClass:selfClass])) {
    [NSException raise:NSInvalidArgumentException
                format:@"Classes must match %@ != %@", selfClass, otherClass];
  }

  // We assume something will be done and become visible.
  LCGPBBecomeVisibleToAutocreator(self);

  LCGPBDescriptor *descriptor = [[self class] descriptor];
  LCGPBFileSyntax syntax = descriptor.file.syntax;

  for (LCGPBFieldDescriptor *field in descriptor->fields_) {
    LCGPBFieldType fieldType = field.fieldType;
    if (fieldType == LCGPBFieldTypeSingle) {
      int32_t hasIndex = LCGPBFieldHasIndex(field);
      uint32_t fieldNumber = LCGPBFieldNumber(field);
      if (!LCGPBGetHasIvar(other, hasIndex, fieldNumber)) {
        // Other doesn't have the field set, on to the next.
        continue;
      }
      LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
      switch (fieldDataType) {
        case LCGPBDataTypeBool:
          LCGPBSetBoolIvarWithFieldInternal(
              self, field, LCGPBGetMessageBoolField(other, field), syntax);
          break;
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeEnum:
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSInt32:
          LCGPBSetInt32IvarWithFieldInternal(
              self, field, LCGPBGetMessageInt32Field(other, field), syntax);
          break;
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
          LCGPBSetUInt32IvarWithFieldInternal(
              self, field, LCGPBGetMessageUInt32Field(other, field), syntax);
          break;
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSInt64:
          LCGPBSetInt64IvarWithFieldInternal(
              self, field, LCGPBGetMessageInt64Field(other, field), syntax);
          break;
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
          LCGPBSetUInt64IvarWithFieldInternal(
              self, field, LCGPBGetMessageUInt64Field(other, field), syntax);
          break;
        case LCGPBDataTypeFloat:
          LCGPBSetFloatIvarWithFieldInternal(
              self, field, LCGPBGetMessageFloatField(other, field), syntax);
          break;
        case LCGPBDataTypeDouble:
          LCGPBSetDoubleIvarWithFieldInternal(
              self, field, LCGPBGetMessageDoubleField(other, field), syntax);
          break;
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeString: {
          id otherVal = LCGPBGetObjectIvarWithFieldNoAutocreate(other, field);
          LCGPBSetObjectIvarWithFieldInternal(self, field, otherVal, syntax);
          break;
        }
        case LCGPBDataTypeMessage:
        case LCGPBDataTypeGroup: {
          id otherVal = LCGPBGetObjectIvarWithFieldNoAutocreate(other, field);
          if (LCGPBGetHasIvar(self, hasIndex, fieldNumber)) {
            LCGPBMessage *message =
                LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
            [message mergeFrom:otherVal];
          } else {
            LCGPBMessage *message = [otherVal copy];
            LCGPBSetRetainedObjectIvarWithFieldInternal(self, field, message,
                                                      syntax);
          }
          break;
        }
      } // switch()
    } else if (fieldType == LCGPBFieldTypeRepeated) {
      // In the case of a list, they need to be appended, and there is no
      // _hasIvar to worry about setting.
      id otherArray =
          LCGPBGetObjectIvarWithFieldNoAutocreate(other, field);
      if (otherArray) {
        LCGPBDataType fieldDataType = field->description_->dataType;
        if (LCGPBDataTypeIsObject(fieldDataType)) {
          NSMutableArray *resultArray =
              GetOrCreateArrayIvarWithField(self, field, syntax);
          [resultArray addObjectsFromArray:otherArray];
        } else if (fieldDataType == LCGPBDataTypeEnum) {
          LCGPBEnumArray *resultArray =
              GetOrCreateArrayIvarWithField(self, field, syntax);
          [resultArray addRawValuesFromArray:otherArray];
        } else {
          // The array type doesn't matter, that all implment
          // -addValuesFromArray:.
          LCGPBInt32Array *resultArray =
              GetOrCreateArrayIvarWithField(self, field, syntax);
          [resultArray addValuesFromArray:otherArray];
        }
      }
    } else {  // fieldType = LCGPBFieldTypeMap
      // In the case of a map, they need to be merged, and there is no
      // _hasIvar to worry about setting.
      id otherDict = LCGPBGetObjectIvarWithFieldNoAutocreate(other, field);
      if (otherDict) {
        LCGPBDataType keyDataType = field.mapKeyDataType;
        LCGPBDataType valueDataType = field->description_->dataType;
        if (LCGPBDataTypeIsObject(keyDataType) &&
            LCGPBDataTypeIsObject(valueDataType)) {
          NSMutableDictionary *resultDict =
              GetOrCreateMapIvarWithField(self, field, syntax);
          [resultDict addEntriesFromDictionary:otherDict];
        } else if (valueDataType == LCGPBDataTypeEnum) {
          // The exact type doesn't matter, just need to know it is a
          // LCGPB*EnumDictionary.
          LCGPBInt32EnumDictionary *resultDict =
              GetOrCreateMapIvarWithField(self, field, syntax);
          [resultDict addRawEntriesFromDictionary:otherDict];
        } else {
          // The exact type doesn't matter, they all implement
          // -addEntriesFromDictionary:.
          LCGPBInt32Int32Dictionary *resultDict =
              GetOrCreateMapIvarWithField(self, field, syntax);
          [resultDict addEntriesFromDictionary:otherDict];
        }
      }
    }  // if (fieldType)..else if...else
  }  // for(fields)

  // Unknown fields.
  if (!unknownFields_) {
    [self setUnknownFields:other.unknownFields];
  } else {
    [unknownFields_ mergeUnknownFields:other.unknownFields];
  }

  // Extensions

  if (other->extensionMap_.count == 0) {
    return;
  }

  if (extensionMap_ == nil) {
    extensionMap_ =
        CloneExtensionMap(other->extensionMap_, NSZoneFromPointer(self));
  } else {
    for (LCGPBExtensionDescriptor *extension in other->extensionMap_) {
      id otherValue = [other->extensionMap_ objectForKey:extension];
      id value = [extensionMap_ objectForKey:extension];
      BOOL isMessageExtension = LCGPBExtensionIsMessage(extension);

      if (extension.repeated) {
        NSMutableArray *list = value;
        if (list == nil) {
          list = [[NSMutableArray alloc] init];
          [extensionMap_ setObject:list forKey:extension];
          [list release];
        }
        if (isMessageExtension) {
          for (LCGPBMessage *otherListValue in otherValue) {
            LCGPBMessage *copiedValue = [otherListValue copy];
            [list addObject:copiedValue];
            [copiedValue release];
          }
        } else {
          [list addObjectsFromArray:otherValue];
        }
      } else {
        if (isMessageExtension) {
          if (value) {
            [(LCGPBMessage *)value mergeFrom:(LCGPBMessage *)otherValue];
          } else {
            LCGPBMessage *copiedValue = [otherValue copy];
            [extensionMap_ setObject:copiedValue forKey:extension];
            [copiedValue release];
          }
        } else {
          [extensionMap_ setObject:otherValue forKey:extension];
        }
      }

      if (isMessageExtension && !extension.isRepeated) {
        LCGPBMessage *autocreatedValue =
            [[autocreatedExtensionMap_ objectForKey:extension] retain];
        // Must remove from the map before calling LCGPBClearMessageAutocreator()
        // so that LCGPBClearMessageAutocreator() knows its safe to clear.
        [autocreatedExtensionMap_ removeObjectForKey:extension];
        LCGPBClearMessageAutocreator(autocreatedValue);
        [autocreatedValue release];
      }
    }
  }
}

#pragma mark - isEqual: & hash Support

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[LCGPBMessage class]]) {
    return NO;
  }
  LCGPBMessage *otherMsg = other;
  LCGPBDescriptor *descriptor = [[self class] descriptor];
  if ([[otherMsg class] descriptor] != descriptor) {
    return NO;
  }
  uint8_t *selfStorage = (uint8_t *)messageStorage_;
  uint8_t *otherStorage = (uint8_t *)otherMsg->messageStorage_;

  for (LCGPBFieldDescriptor *field in descriptor->fields_) {
    if (LCGPBFieldIsMapOrArray(field)) {
      // In the case of a list or map, there is no _hasIvar to worry about.
      // NOTE: These are NSArray/LCGPB*Array or NSDictionary/LCGPB*Dictionary, but
      // the type doesn't really matter as the objects all support -count and
      // -isEqual:.
      NSArray *resultMapOrArray =
          LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
      NSArray *otherMapOrArray =
          LCGPBGetObjectIvarWithFieldNoAutocreate(other, field);
      // nil and empty are equal
      if (resultMapOrArray.count != 0 || otherMapOrArray.count != 0) {
        if (![resultMapOrArray isEqual:otherMapOrArray]) {
          return NO;
        }
      }
    } else {  // Single field
      int32_t hasIndex = LCGPBFieldHasIndex(field);
      uint32_t fieldNum = LCGPBFieldNumber(field);
      BOOL selfHas = LCGPBGetHasIvar(self, hasIndex, fieldNum);
      BOOL otherHas = LCGPBGetHasIvar(other, hasIndex, fieldNum);
      if (selfHas != otherHas) {
        return NO;  // Differing has values, not equal.
      }
      if (!selfHas) {
        // Same has values, was no, nothing else to check for this field.
        continue;
      }
      // Now compare the values.
      LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
      size_t fieldOffset = field->description_->offset;
      switch (fieldDataType) {
        case LCGPBDataTypeBool: {
          // Bools are stored in has_bits to avoid needing explicit space in
          // the storage structure.
          // (the field number passed to the HasIvar helper doesn't really
          // matter since the offset is never negative)
          BOOL selfValue = LCGPBGetHasIvar(self, (int32_t)(fieldOffset), 0);
          BOOL otherValue = LCGPBGetHasIvar(other, (int32_t)(fieldOffset), 0);
          if (selfValue != otherValue) {
            return NO;
          }
          break;
        }
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSInt32:
        case LCGPBDataTypeEnum:
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
        case LCGPBDataTypeFloat: {
          LCGPBInternalCompileAssert(sizeof(float) == sizeof(uint32_t), float_not_32_bits);
          // These are all 32bit, signed/unsigned doesn't matter for equality.
          uint32_t *selfValPtr = (uint32_t *)&selfStorage[fieldOffset];
          uint32_t *otherValPtr = (uint32_t *)&otherStorage[fieldOffset];
          if (*selfValPtr != *otherValPtr) {
            return NO;
          }
          break;
        }
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSInt64:
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
        case LCGPBDataTypeDouble: {
          LCGPBInternalCompileAssert(sizeof(double) == sizeof(uint64_t), double_not_64_bits);
          // These are all 64bit, signed/unsigned doesn't matter for equality.
          uint64_t *selfValPtr = (uint64_t *)&selfStorage[fieldOffset];
          uint64_t *otherValPtr = (uint64_t *)&otherStorage[fieldOffset];
          if (*selfValPtr != *otherValPtr) {
            return NO;
          }
          break;
        }
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeString:
        case LCGPBDataTypeMessage:
        case LCGPBDataTypeGroup: {
          // Type doesn't matter here, they all implement -isEqual:.
          id *selfValPtr = (id *)&selfStorage[fieldOffset];
          id *otherValPtr = (id *)&otherStorage[fieldOffset];
          if (![*selfValPtr isEqual:*otherValPtr]) {
            return NO;
          }
          break;
        }
      } // switch()
    }   // if(mapOrArray)...else
  }  // for(fields)

  // nil and empty are equal
  if (extensionMap_.count != 0 || otherMsg->extensionMap_.count != 0) {
    if (![extensionMap_ isEqual:otherMsg->extensionMap_]) {
      return NO;
    }
  }

  // nil and empty are equal
  LCGPBUnknownFieldSet *otherUnknowns = otherMsg->unknownFields_;
  if ([unknownFields_ countOfFields] != 0 ||
      [otherUnknowns countOfFields] != 0) {
    if (![unknownFields_ isEqual:otherUnknowns]) {
      return NO;
    }
  }

  return YES;
}

// It is very difficult to implement a generic hash for ProtoBuf messages that
// will perform well. If you need hashing on your ProtoBufs (eg you are using
// them as dictionary keys) you will probably want to implement a ProtoBuf
// message specific hash as a category on your protobuf class. Do not make it a
// category on LCGPBMessage as you will conflict with this hash, and will possibly
// override hash for all generated protobufs. A good implementation of hash will
// be really fast, so we would recommend only hashing protobufs that have an
// identifier field of some kind that you can easily hash. If you implement
// hash, we would strongly recommend overriding isEqual: in your category as
// well, as the default implementation of isEqual: is extremely slow, and may
// drastically affect performance in large sets.
- (NSUInteger)hash {
  LCGPBDescriptor *descriptor = [[self class] descriptor];
  const NSUInteger prime = 19;
  uint8_t *storage = (uint8_t *)messageStorage_;

  // Start with the descriptor and then mix it with some instance info.
  // Hopefully that will give a spread based on classes and what fields are set.
  NSUInteger result = (NSUInteger)descriptor;

  for (LCGPBFieldDescriptor *field in descriptor->fields_) {
    if (LCGPBFieldIsMapOrArray(field)) {
      // Exact type doesn't matter, just check if there are any elements.
      NSArray *mapOrArray = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
      NSUInteger count = mapOrArray.count;
      if (count) {
        // NSArray/NSDictionary use count, use the field number and the count.
        result = prime * result + LCGPBFieldNumber(field);
        result = prime * result + count;
      }
    } else if (LCGPBGetHasIvarField(self, field)) {
      // Just using the field number seemed simple/fast, but then a small
      // message class where all the same fields are always set (to different
      // things would end up all with the same hash, so pull in some data).
      LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
      size_t fieldOffset = field->description_->offset;
      switch (fieldDataType) {
        case LCGPBDataTypeBool: {
          // Bools are stored in has_bits to avoid needing explicit space in
          // the storage structure.
          // (the field number passed to the HasIvar helper doesn't really
          // matter since the offset is never negative)
          BOOL value = LCGPBGetHasIvar(self, (int32_t)(fieldOffset), 0);
          result = prime * result + value;
          break;
        }
        case LCGPBDataTypeSFixed32:
        case LCGPBDataTypeInt32:
        case LCGPBDataTypeSInt32:
        case LCGPBDataTypeEnum:
        case LCGPBDataTypeFixed32:
        case LCGPBDataTypeUInt32:
        case LCGPBDataTypeFloat: {
          LCGPBInternalCompileAssert(sizeof(float) == sizeof(uint32_t), float_not_32_bits);
          // These are all 32bit, just mix it in.
          uint32_t *valPtr = (uint32_t *)&storage[fieldOffset];
          result = prime * result + *valPtr;
          break;
        }
        case LCGPBDataTypeSFixed64:
        case LCGPBDataTypeInt64:
        case LCGPBDataTypeSInt64:
        case LCGPBDataTypeFixed64:
        case LCGPBDataTypeUInt64:
        case LCGPBDataTypeDouble: {
          LCGPBInternalCompileAssert(sizeof(double) == sizeof(uint64_t), double_not_64_bits);
          // These are all 64bit, just mix what fits into an NSUInteger in.
          uint64_t *valPtr = (uint64_t *)&storage[fieldOffset];
          result = prime * result + (NSUInteger)(*valPtr);
          break;
        }
        case LCGPBDataTypeBytes:
        case LCGPBDataTypeString: {
          // Type doesn't matter here, they both implement -hash:.
          id *valPtr = (id *)&storage[fieldOffset];
          result = prime * result + [*valPtr hash];
          break;
        }

        case LCGPBDataTypeMessage:
        case LCGPBDataTypeGroup: {
          LCGPBMessage **valPtr = (LCGPBMessage **)&storage[fieldOffset];
          // Could call -hash on the sub message, but that could recurse pretty
          // deep; follow the lead of NSArray/NSDictionary and don't really
          // recurse for hash, instead use the field number and the descriptor
          // of the sub message.  Yes, this could suck for a bunch of messages
          // where they all only differ in the sub messages, but if you are
          // using a message with sub messages for something that needs -hash,
          // odds are you are also copying them as keys, and that deep copy
          // will also suck.
          result = prime * result + LCGPBFieldNumber(field);
          result = prime * result + (NSUInteger)[[*valPtr class] descriptor];
          break;
        }
      } // switch()
    }
  }

  // Unknowns and extensions are not included.

  return result;
}

#pragma mark - Description Support

- (NSString *)description {
  NSString *textFormat = LCGPBTextFormatForMessage(self, @"    ");
  NSString *description = [NSString
      stringWithFormat:@"<%@ %p>: {\n%@}", [self class], self, textFormat];
  return description;
}

#if defined(DEBUG) && DEBUG

// Xcode 5.1 added support for custom quick look info.
// https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/CustomClassDisplay_in_QuickLook/CH01-quick_look_for_custom_objects/CH01-quick_look_for_custom_objects.html#//apple_ref/doc/uid/TP40014001-CH2-SW1
- (id)debugQuickLookObject {
  return LCGPBTextFormatForMessage(self, nil);
}

#endif  // DEBUG

#pragma mark - SerializedSize

- (size_t)serializedSize {
  LCGPBDescriptor *descriptor = [[self class] descriptor];
  size_t result = 0;

  // Has check is done explicitly, so LCGPBGetObjectIvarWithFieldNoAutocreate()
  // avoids doing the has check again.

  // Fields.
  for (LCGPBFieldDescriptor *fieldDescriptor in descriptor->fields_) {
    LCGPBFieldType fieldType = fieldDescriptor.fieldType;
    LCGPBDataType fieldDataType = LCGPBGetFieldDataType(fieldDescriptor);

    // Single Fields
    if (fieldType == LCGPBFieldTypeSingle) {
      BOOL selfHas = LCGPBGetHasIvarField(self, fieldDescriptor);
      if (!selfHas) {
        continue;  // Nothing to do.
      }

      uint32_t fieldNumber = LCGPBFieldNumber(fieldDescriptor);

      switch (fieldDataType) {
#define CASE_SINGLE_POD(NAME, TYPE, FUNC_TYPE)                                \
        case LCGPBDataType##NAME: {                                             \
          TYPE fieldVal = LCGPBGetMessage##FUNC_TYPE##Field(self, fieldDescriptor); \
          result += LCGPBCompute##NAME##Size(fieldNumber, fieldVal);            \
          break;                                                              \
        }
#define CASE_SINGLE_OBJECT(NAME)                                              \
        case LCGPBDataType##NAME: {                                             \
          id fieldVal = LCGPBGetObjectIvarWithFieldNoAutocreate(self, fieldDescriptor); \
          result += LCGPBCompute##NAME##Size(fieldNumber, fieldVal);            \
          break;                                                              \
        }
          CASE_SINGLE_POD(Bool, BOOL, Bool)
          CASE_SINGLE_POD(Fixed32, uint32_t, UInt32)
          CASE_SINGLE_POD(SFixed32, int32_t, Int32)
          CASE_SINGLE_POD(Float, float, Float)
          CASE_SINGLE_POD(Fixed64, uint64_t, UInt64)
          CASE_SINGLE_POD(SFixed64, int64_t, Int64)
          CASE_SINGLE_POD(Double, double, Double)
          CASE_SINGLE_POD(Int32, int32_t, Int32)
          CASE_SINGLE_POD(Int64, int64_t, Int64)
          CASE_SINGLE_POD(SInt32, int32_t, Int32)
          CASE_SINGLE_POD(SInt64, int64_t, Int64)
          CASE_SINGLE_POD(UInt32, uint32_t, UInt32)
          CASE_SINGLE_POD(UInt64, uint64_t, UInt64)
          CASE_SINGLE_OBJECT(Bytes)
          CASE_SINGLE_OBJECT(String)
          CASE_SINGLE_OBJECT(Message)
          CASE_SINGLE_OBJECT(Group)
          CASE_SINGLE_POD(Enum, int32_t, Int32)
#undef CASE_SINGLE_POD
#undef CASE_SINGLE_OBJECT
      }

    // Repeated Fields
    } else if (fieldType == LCGPBFieldTypeRepeated) {
      id genericArray =
          LCGPBGetObjectIvarWithFieldNoAutocreate(self, fieldDescriptor);
      NSUInteger count = [genericArray count];
      if (count == 0) {
        continue;  // Nothing to add.
      }
      __block size_t dataSize = 0;

      switch (fieldDataType) {
#define CASE_REPEATED_POD(NAME, TYPE, ARRAY_TYPE)                             \
    CASE_REPEATED_POD_EXTRA(NAME, TYPE, ARRAY_TYPE, )
#define CASE_REPEATED_POD_EXTRA(NAME, TYPE, ARRAY_TYPE, ARRAY_ACCESSOR_NAME)  \
        case LCGPBDataType##NAME: {                                             \
          LCGPB##ARRAY_TYPE##Array *array = genericArray;                       \
          [array enumerate##ARRAY_ACCESSOR_NAME##ValuesWithBlock:^(TYPE value, NSUInteger idx, BOOL *stop) { \
            _Pragma("unused(idx, stop)");                                     \
            dataSize += LCGPBCompute##NAME##SizeNoTag(value);                   \
          }];                                                                 \
          break;                                                              \
        }
#define CASE_REPEATED_OBJECT(NAME)                                            \
        case LCGPBDataType##NAME: {                                             \
          for (id value in genericArray) {                                    \
            dataSize += LCGPBCompute##NAME##SizeNoTag(value);                   \
          }                                                                   \
          break;                                                              \
        }
          CASE_REPEATED_POD(Bool, BOOL, Bool)
          CASE_REPEATED_POD(Fixed32, uint32_t, UInt32)
          CASE_REPEATED_POD(SFixed32, int32_t, Int32)
          CASE_REPEATED_POD(Float, float, Float)
          CASE_REPEATED_POD(Fixed64, uint64_t, UInt64)
          CASE_REPEATED_POD(SFixed64, int64_t, Int64)
          CASE_REPEATED_POD(Double, double, Double)
          CASE_REPEATED_POD(Int32, int32_t, Int32)
          CASE_REPEATED_POD(Int64, int64_t, Int64)
          CASE_REPEATED_POD(SInt32, int32_t, Int32)
          CASE_REPEATED_POD(SInt64, int64_t, Int64)
          CASE_REPEATED_POD(UInt32, uint32_t, UInt32)
          CASE_REPEATED_POD(UInt64, uint64_t, UInt64)
          CASE_REPEATED_OBJECT(Bytes)
          CASE_REPEATED_OBJECT(String)
          CASE_REPEATED_OBJECT(Message)
          CASE_REPEATED_OBJECT(Group)
          CASE_REPEATED_POD_EXTRA(Enum, int32_t, Enum, Raw)
#undef CASE_REPEATED_POD
#undef CASE_REPEATED_POD_EXTRA
#undef CASE_REPEATED_OBJECT
      }  // switch
      result += dataSize;
      size_t tagSize = LCGPBComputeTagSize(LCGPBFieldNumber(fieldDescriptor));
      if (fieldDataType == LCGPBDataTypeGroup) {
        // Groups have both a start and an end tag.
        tagSize *= 2;
      }
      if (fieldDescriptor.isPackable) {
        result += tagSize;
        result += LCGPBComputeSizeTSizeAsInt32NoTag(dataSize);
      } else {
        result += count * tagSize;
      }

    // Map<> Fields
    } else {  // fieldType == LCGPBFieldTypeMap
      if (LCGPBDataTypeIsObject(fieldDataType) &&
          (fieldDescriptor.mapKeyDataType == LCGPBDataTypeString)) {
        // If key type was string, then the map is an NSDictionary.
        NSDictionary *map =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, fieldDescriptor);
        if (map) {
          result += LCGPBDictionaryComputeSizeInternalHelper(map, fieldDescriptor);
        }
      } else {
        // Type will be LCGPB*GroupDictionary, exact type doesn't matter.
        LCGPBInt32Int32Dictionary *map =
            LCGPBGetObjectIvarWithFieldNoAutocreate(self, fieldDescriptor);
        result += [map computeSerializedSizeAsField:fieldDescriptor];
      }
    }
  }  // for(fields)

  // Add any unknown fields.
  if (descriptor.wireFormat) {
    result += [unknownFields_ serializedSizeAsMessageSet];
  } else {
    result += [unknownFields_ serializedSize];
  }

  // Add any extensions.
  for (LCGPBExtensionDescriptor *extension in extensionMap_) {
    id value = [extensionMap_ objectForKey:extension];
    result += LCGPBComputeExtensionSerializedSizeIncludingTag(extension, value);
  }

  return result;
}

#pragma mark - Resolve Methods Support

typedef struct ResolveIvarAccessorMethodResult {
  IMP impToAdd;
  SEL encodingSelector;
} ResolveIvarAccessorMethodResult;

// |field| can be __unsafe_unretained because they are created at startup
// and are essentially global. No need to pay for retain/release when
// they are captured in blocks.
static void ResolveIvarGet(__unsafe_unretained LCGPBFieldDescriptor *field,
                           ResolveIvarAccessorMethodResult *result) {
  LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
  switch (fieldDataType) {
#define CASE_GET(NAME, TYPE, TRUE_NAME)                          \
    case LCGPBDataType##NAME: {                                    \
      result->impToAdd = imp_implementationWithBlock(^(id obj) { \
        return LCGPBGetMessage##TRUE_NAME##Field(obj, field);      \
       });                                                       \
      result->encodingSelector = @selector(get##NAME);           \
      break;                                                     \
    }
#define CASE_GET_OBJECT(NAME, TYPE, TRUE_NAME)                   \
    case LCGPBDataType##NAME: {                                    \
      result->impToAdd = imp_implementationWithBlock(^(id obj) { \
        return LCGPBGetObjectIvarWithField(obj, field);            \
       });                                                       \
      result->encodingSelector = @selector(get##NAME);           \
      break;                                                     \
    }
      CASE_GET(Bool, BOOL, Bool)
      CASE_GET(Fixed32, uint32_t, UInt32)
      CASE_GET(SFixed32, int32_t, Int32)
      CASE_GET(Float, float, Float)
      CASE_GET(Fixed64, uint64_t, UInt64)
      CASE_GET(SFixed64, int64_t, Int64)
      CASE_GET(Double, double, Double)
      CASE_GET(Int32, int32_t, Int32)
      CASE_GET(Int64, int64_t, Int64)
      CASE_GET(SInt32, int32_t, Int32)
      CASE_GET(SInt64, int64_t, Int64)
      CASE_GET(UInt32, uint32_t, UInt32)
      CASE_GET(UInt64, uint64_t, UInt64)
      CASE_GET_OBJECT(Bytes, id, Object)
      CASE_GET_OBJECT(String, id, Object)
      CASE_GET_OBJECT(Message, id, Object)
      CASE_GET_OBJECT(Group, id, Object)
      CASE_GET(Enum, int32_t, Enum)
#undef CASE_GET
  }
}

// See comment about __unsafe_unretained on ResolveIvarGet.
static void ResolveIvarSet(__unsafe_unretained LCGPBFieldDescriptor *field,
                           LCGPBFileSyntax syntax,
                           ResolveIvarAccessorMethodResult *result) {
  LCGPBDataType fieldDataType = LCGPBGetFieldDataType(field);
  switch (fieldDataType) {
#define CASE_SET(NAME, TYPE, TRUE_NAME)                                       \
    case LCGPBDataType##NAME: {                                                 \
      result->impToAdd = imp_implementationWithBlock(^(id obj, TYPE value) {  \
        return LCGPBSet##TRUE_NAME##IvarWithFieldInternal(obj, field, value, syntax); \
      });                                                                     \
      result->encodingSelector = @selector(set##NAME:);                       \
      break;                                                                  \
    }
#define CASE_SET_COPY(NAME)                                                   \
    case LCGPBDataType##NAME: {                                                 \
      result->impToAdd = imp_implementationWithBlock(^(id obj, id value) {    \
        return LCGPBSetRetainedObjectIvarWithFieldInternal(obj, field, [value copy], syntax); \
      });                                                                     \
      result->encodingSelector = @selector(set##NAME:);                       \
      break;                                                                  \
    }
      CASE_SET(Bool, BOOL, Bool)
      CASE_SET(Fixed32, uint32_t, UInt32)
      CASE_SET(SFixed32, int32_t, Int32)
      CASE_SET(Float, float, Float)
      CASE_SET(Fixed64, uint64_t, UInt64)
      CASE_SET(SFixed64, int64_t, Int64)
      CASE_SET(Double, double, Double)
      CASE_SET(Int32, int32_t, Int32)
      CASE_SET(Int64, int64_t, Int64)
      CASE_SET(SInt32, int32_t, Int32)
      CASE_SET(SInt64, int64_t, Int64)
      CASE_SET(UInt32, uint32_t, UInt32)
      CASE_SET(UInt64, uint64_t, UInt64)
      CASE_SET_COPY(Bytes)
      CASE_SET_COPY(String)
      CASE_SET(Message, id, Object)
      CASE_SET(Group, id, Object)
      CASE_SET(Enum, int32_t, Enum)
#undef CASE_SET
  }
}

+ (BOOL)resolveInstanceMethod:(SEL)sel {
  const LCGPBDescriptor *descriptor = [self descriptor];
  if (!descriptor) {
    return [super resolveInstanceMethod:sel];
  }

  // NOTE: hasOrCountSel_/setHasSel_ will be NULL if the field for the given
  // message should not have has support (done in LCGPBDescriptor.m), so there is
  // no need for checks here to see if has*/setHas* are allowed.
  ResolveIvarAccessorMethodResult result = {NULL, NULL};

  // See comment about __unsafe_unretained on ResolveIvarGet.
  for (__unsafe_unretained LCGPBFieldDescriptor *field in descriptor->fields_) {
    BOOL isMapOrArray = LCGPBFieldIsMapOrArray(field);
    if (!isMapOrArray) {
      // Single fields.
      if (sel == field->getSel_) {
        ResolveIvarGet(field, &result);
        break;
      } else if (sel == field->setSel_) {
        ResolveIvarSet(field, descriptor.file.syntax, &result);
        break;
      } else if (sel == field->hasOrCountSel_) {
        int32_t index = LCGPBFieldHasIndex(field);
        uint32_t fieldNum = LCGPBFieldNumber(field);
        result.impToAdd = imp_implementationWithBlock(^(id obj) {
          return LCGPBGetHasIvar(obj, index, fieldNum);
        });
        result.encodingSelector = @selector(getBool);
        break;
      } else if (sel == field->setHasSel_) {
        result.impToAdd = imp_implementationWithBlock(^(id obj, BOOL value) {
          if (value) {
            [NSException raise:NSInvalidArgumentException
                        format:@"%@: %@ can only be set to NO (to clear field).",
                               [obj class],
                               NSStringFromSelector(field->setHasSel_)];
          }
          LCGPBClearMessageField(obj, field);
        });
        result.encodingSelector = @selector(setBool:);
        break;
      } else {
        LCGPBOneofDescriptor *oneof = field->containingOneof_;
        if (oneof && (sel == oneof->caseSel_)) {
          int32_t index = LCGPBFieldHasIndex(field);
          result.impToAdd = imp_implementationWithBlock(^(id obj) {
            return LCGPBGetHasOneof(obj, index);
          });
          result.encodingSelector = @selector(getEnum);
          break;
        }
      }
    } else {
      // map<>/repeated fields.
      if (sel == field->getSel_) {
        if (field.fieldType == LCGPBFieldTypeRepeated) {
          result.impToAdd = imp_implementationWithBlock(^(id obj) {
            return GetArrayIvarWithField(obj, field);
          });
        } else {
          result.impToAdd = imp_implementationWithBlock(^(id obj) {
            return GetMapIvarWithField(obj, field);
          });
        }
        result.encodingSelector = @selector(getArray);
        break;
      } else if (sel == field->setSel_) {
        // Local for syntax so the block can directly capture it and not the
        // full lookup.
        const LCGPBFileSyntax syntax = descriptor.file.syntax;
        result.impToAdd = imp_implementationWithBlock(^(id obj, id value) {
          LCGPBSetObjectIvarWithFieldInternal(obj, field, value, syntax);
        });
        result.encodingSelector = @selector(setArray:);
        break;
      } else if (sel == field->hasOrCountSel_) {
        result.impToAdd = imp_implementationWithBlock(^(id obj) {
          // Type doesn't matter, all *Array and *Dictionary types support
          // -count.
          NSArray *arrayOrMap =
              LCGPBGetObjectIvarWithFieldNoAutocreate(obj, field);
          return [arrayOrMap count];
        });
        result.encodingSelector = @selector(getArrayCount);
        break;
      }
    }
  }
  if (result.impToAdd) {
    const char *encoding =
        LCGPBMessageEncodingForSelector(result.encodingSelector, YES);
    Class msgClass = descriptor.messageClass;
    BOOL methodAdded = class_addMethod(msgClass, sel, result.impToAdd, encoding);
    // class_addMethod() is documented as also failing if the method was already
    // added; so we check if the method is already there and return success so
    // the method dispatch will still happen.  Why would it already be added?
    // Two threads could cause the same method to be bound at the same time,
    // but only one will actually bind it; the other still needs to return true
    // so things will dispatch.
    if (!methodAdded) {
      methodAdded = LCGPBClassHasSel(msgClass, sel);
    }
    return methodAdded;
  }
  return [super resolveInstanceMethod:sel];
}

+ (BOOL)resolveClassMethod:(SEL)sel {
  // Extensions scoped to a Message and looked up via class methods.
  if (LCGPBResolveExtensionClassMethod([self descriptor].messageClass, sel)) {
    return YES;
  }
  return [super resolveClassMethod:sel];
}

#pragma mark - NSCoding Support

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [self init];
  if (self) {
    NSData *data =
        [aDecoder decodeObjectOfClass:[NSData class] forKey:kLCGPBDataCoderKey];
    if (data.length) {
      [self mergeFromData:data extensionRegistry:nil];
    }
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
#if defined(DEBUG) && DEBUG
  if (extensionMap_.count) {
    // Hint to go along with the docs on LCGPBMessage about this.
    //
    // Note: This is incomplete, in that it only checked the "root" message,
    // if a sub message in a field has extensions, the issue still exists. A
    // recursive check could be done here (like the work in
    // LCGPBMessageDropUnknownFieldsRecursively()), but that has the potential to
    // be expensive and could slow down serialization in DEBUG enought to cause
    // developers other problems.
    NSLog(@"Warning: writing out a LCGPBMessage (%@) via NSCoding and it"
          @" has %ld extensions; when read back in, those fields will be"
          @" in the unknownFields property instead.",
          [self class], (long)extensionMap_.count);
  }
#endif
  NSData *data = [self data];
  if (data.length) {
    [aCoder encodeObject:data forKey:kLCGPBDataCoderKey];
  }
}

#pragma mark - KVC Support

+ (BOOL)accessInstanceVariablesDirectly {
  // Make sure KVC doesn't use instance variables.
  return NO;
}

@end

#pragma mark - Messages from LCGPBUtilities.h but defined here for access to helpers.

// Only exists for public api, no core code should use this.
id LCGPBGetMessageRepeatedField(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  if (field.fieldType != LCGPBFieldTypeRepeated) {
    [NSException raise:NSInvalidArgumentException
                format:@"%@.%@ is not a repeated field.",
     [self class], field.name];
  }
#endif
  LCGPBDescriptor *descriptor = [[self class] descriptor];
  LCGPBFileSyntax syntax = descriptor.file.syntax;
  return GetOrCreateArrayIvarWithField(self, field, syntax);
}

// Only exists for public api, no core code should use this.
id LCGPBGetMessageMapField(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
#if defined(DEBUG) && DEBUG
  if (field.fieldType != LCGPBFieldTypeMap) {
    [NSException raise:NSInvalidArgumentException
                format:@"%@.%@ is not a map<> field.",
     [self class], field.name];
  }
#endif
  LCGPBDescriptor *descriptor = [[self class] descriptor];
  LCGPBFileSyntax syntax = descriptor.file.syntax;
  return GetOrCreateMapIvarWithField(self, field, syntax);
}

id LCGPBGetObjectIvarWithField(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
  NSCAssert(!LCGPBFieldIsMapOrArray(field), @"Shouldn't get here");
  if (LCGPBGetHasIvarField(self, field)) {
    uint8_t *storage = (uint8_t *)self->messageStorage_;
    id *typePtr = (id *)&storage[field->description_->offset];
    return *typePtr;
  }
  // Not set...

  // Non messages (string/data), get their default.
  if (!LCGPBFieldDataTypeIsMessage(field)) {
    return field.defaultValue.valueMessage;
  }

  LCGPBPrepareReadOnlySemaphore(self);
  dispatch_semaphore_wait(self->readOnlySemaphore_, DISPATCH_TIME_FOREVER);
  LCGPBMessage *result = LCGPBGetObjectIvarWithFieldNoAutocreate(self, field);
  if (!result) {
    // For non repeated messages, create the object, set it and return it.
    // This object will not initially be visible via LCGPBGetHasIvar, so
    // we save its creator so it can become visible if it's mutated later.
    result = LCGPBCreateMessageWithAutocreator(field.msgClass, self, field);
    LCGPBSetAutocreatedRetainedObjectIvarWithField(self, field, result);
  }
  dispatch_semaphore_signal(self->readOnlySemaphore_);
  return result;
}

#pragma clang diagnostic pop
