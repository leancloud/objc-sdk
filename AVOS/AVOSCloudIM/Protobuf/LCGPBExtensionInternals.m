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

#import "LCGPBExtensionInternals.h"

#import <objc/runtime.h>

#import "LCGPBCodedInputStream_PackagePrivate.h"
#import "LCGPBCodedOutputStream_PackagePrivate.h"
#import "LCGPBDescriptor_PackagePrivate.h"
#import "LCGPBMessage_PackagePrivate.h"
#import "LCGPBUtilities_PackagePrivate.h"

static id NewSingleValueFromInputStream(LCGPBExtensionDescriptor *extension,
                                        LCGPBCodedInputStream *input,
                                        LCGPBExtensionRegistry *extensionRegistry,
                                        LCGPBMessage *existingValue)
    __attribute__((ns_returns_retained));

LCGPB_INLINE size_t DataTypeSize(LCGPBDataType dataType) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
  switch (dataType) {
    case LCGPBDataTypeBool:
      return 1;
    case LCGPBDataTypeFixed32:
    case LCGPBDataTypeSFixed32:
    case LCGPBDataTypeFloat:
      return 4;
    case LCGPBDataTypeFixed64:
    case LCGPBDataTypeSFixed64:
    case LCGPBDataTypeDouble:
      return 8;
    default:
      return 0;
  }
#pragma clang diagnostic pop
}

static size_t ComputePBSerializedSizeNoTagOfObject(LCGPBDataType dataType, id object) {
#define FIELD_CASE(TYPE, ACCESSOR)                                     \
  case LCGPBDataType##TYPE:                                              \
    return LCGPBCompute##TYPE##SizeNoTag([(NSNumber *)object ACCESSOR]);
#define FIELD_CASE2(TYPE)                                              \
  case LCGPBDataType##TYPE:                                              \
    return LCGPBCompute##TYPE##SizeNoTag(object);
  switch (dataType) {
    FIELD_CASE(Bool, boolValue)
    FIELD_CASE(Float, floatValue)
    FIELD_CASE(Double, doubleValue)
    FIELD_CASE(Int32, intValue)
    FIELD_CASE(SFixed32, intValue)
    FIELD_CASE(SInt32, intValue)
    FIELD_CASE(Enum, intValue)
    FIELD_CASE(Int64, longLongValue)
    FIELD_CASE(SInt64, longLongValue)
    FIELD_CASE(SFixed64, longLongValue)
    FIELD_CASE(UInt32, unsignedIntValue)
    FIELD_CASE(Fixed32, unsignedIntValue)
    FIELD_CASE(UInt64, unsignedLongLongValue)
    FIELD_CASE(Fixed64, unsignedLongLongValue)
    FIELD_CASE2(Bytes)
    FIELD_CASE2(String)
    FIELD_CASE2(Message)
    FIELD_CASE2(Group)
  }
#undef FIELD_CASE
#undef FIELD_CASE2
}

static size_t ComputeSerializedSizeIncludingTagOfObject(
    LCGPBExtensionDescription *description, id object) {
#define FIELD_CASE(TYPE, ACCESSOR)                                   \
  case LCGPBDataType##TYPE:                                            \
    return LCGPBCompute##TYPE##Size(description->fieldNumber,          \
                                  [(NSNumber *)object ACCESSOR]);
#define FIELD_CASE2(TYPE)                                            \
  case LCGPBDataType##TYPE:                                            \
    return LCGPBCompute##TYPE##Size(description->fieldNumber, object);
  switch (description->dataType) {
    FIELD_CASE(Bool, boolValue)
    FIELD_CASE(Float, floatValue)
    FIELD_CASE(Double, doubleValue)
    FIELD_CASE(Int32, intValue)
    FIELD_CASE(SFixed32, intValue)
    FIELD_CASE(SInt32, intValue)
    FIELD_CASE(Enum, intValue)
    FIELD_CASE(Int64, longLongValue)
    FIELD_CASE(SInt64, longLongValue)
    FIELD_CASE(SFixed64, longLongValue)
    FIELD_CASE(UInt32, unsignedIntValue)
    FIELD_CASE(Fixed32, unsignedIntValue)
    FIELD_CASE(UInt64, unsignedLongLongValue)
    FIELD_CASE(Fixed64, unsignedLongLongValue)
    FIELD_CASE2(Bytes)
    FIELD_CASE2(String)
    FIELD_CASE2(Group)
    case LCGPBDataTypeMessage:
      if (LCGPBExtensionIsWireFormat(description)) {
        return LCGPBComputeMessageSetExtensionSize(description->fieldNumber,
                                                 object);
      } else {
        return LCGPBComputeMessageSize(description->fieldNumber, object);
      }
  }
#undef FIELD_CASE
#undef FIELD_CASE2
}

static size_t ComputeSerializedSizeIncludingTagOfArray(
    LCGPBExtensionDescription *description, NSArray *values) {
  if (LCGPBExtensionIsPacked(description)) {
    size_t size = 0;
    size_t typeSize = DataTypeSize(description->dataType);
    if (typeSize != 0) {
      size = values.count * typeSize;
    } else {
      for (id value in values) {
        size +=
            ComputePBSerializedSizeNoTagOfObject(description->dataType, value);
      }
    }
    return size + LCGPBComputeTagSize(description->fieldNumber) +
           LCGPBComputeRawVarint32SizeForInteger(size);
  } else {
    size_t size = 0;
    for (id value in values) {
      size += ComputeSerializedSizeIncludingTagOfObject(description, value);
    }
    return size;
  }
}

static void WriteObjectIncludingTagToCodedOutputStream(
    id object, LCGPBExtensionDescription *description,
    LCGPBCodedOutputStream *output) {
#define FIELD_CASE(TYPE, ACCESSOR)                      \
  case LCGPBDataType##TYPE:                               \
    [output write##TYPE:description->fieldNumber        \
                  value:[(NSNumber *)object ACCESSOR]]; \
    return;
#define FIELD_CASE2(TYPE)                                       \
  case LCGPBDataType##TYPE:                                       \
    [output write##TYPE:description->fieldNumber value:object]; \
    return;
  switch (description->dataType) {
    FIELD_CASE(Bool, boolValue)
    FIELD_CASE(Float, floatValue)
    FIELD_CASE(Double, doubleValue)
    FIELD_CASE(Int32, intValue)
    FIELD_CASE(SFixed32, intValue)
    FIELD_CASE(SInt32, intValue)
    FIELD_CASE(Enum, intValue)
    FIELD_CASE(Int64, longLongValue)
    FIELD_CASE(SInt64, longLongValue)
    FIELD_CASE(SFixed64, longLongValue)
    FIELD_CASE(UInt32, unsignedIntValue)
    FIELD_CASE(Fixed32, unsignedIntValue)
    FIELD_CASE(UInt64, unsignedLongLongValue)
    FIELD_CASE(Fixed64, unsignedLongLongValue)
    FIELD_CASE2(Bytes)
    FIELD_CASE2(String)
    FIELD_CASE2(Group)
    case LCGPBDataTypeMessage:
      if (LCGPBExtensionIsWireFormat(description)) {
        [output writeMessageSetExtension:description->fieldNumber value:object];
      } else {
        [output writeMessage:description->fieldNumber value:object];
      }
      return;
  }
#undef FIELD_CASE
#undef FIELD_CASE2
}

static void WriteObjectNoTagToCodedOutputStream(
    id object, LCGPBExtensionDescription *description,
    LCGPBCodedOutputStream *output) {
#define FIELD_CASE(TYPE, ACCESSOR)                             \
  case LCGPBDataType##TYPE:                                      \
    [output write##TYPE##NoTag:[(NSNumber *)object ACCESSOR]]; \
    return;
#define FIELD_CASE2(TYPE)               \
  case LCGPBDataType##TYPE:               \
    [output write##TYPE##NoTag:object]; \
    return;
  switch (description->dataType) {
    FIELD_CASE(Bool, boolValue)
    FIELD_CASE(Float, floatValue)
    FIELD_CASE(Double, doubleValue)
    FIELD_CASE(Int32, intValue)
    FIELD_CASE(SFixed32, intValue)
    FIELD_CASE(SInt32, intValue)
    FIELD_CASE(Enum, intValue)
    FIELD_CASE(Int64, longLongValue)
    FIELD_CASE(SInt64, longLongValue)
    FIELD_CASE(SFixed64, longLongValue)
    FIELD_CASE(UInt32, unsignedIntValue)
    FIELD_CASE(Fixed32, unsignedIntValue)
    FIELD_CASE(UInt64, unsignedLongLongValue)
    FIELD_CASE(Fixed64, unsignedLongLongValue)
    FIELD_CASE2(Bytes)
    FIELD_CASE2(String)
    FIELD_CASE2(Message)
    case LCGPBDataTypeGroup:
      [output writeGroupNoTag:description->fieldNumber value:object];
      return;
  }
#undef FIELD_CASE
#undef FIELD_CASE2
}

static void WriteArrayIncludingTagsToCodedOutputStream(
    NSArray *values, LCGPBExtensionDescription *description,
    LCGPBCodedOutputStream *output) {
  if (LCGPBExtensionIsPacked(description)) {
    [output writeTag:description->fieldNumber
              format:LCGPBWireFormatLengthDelimited];
    size_t dataSize = 0;
    size_t typeSize = DataTypeSize(description->dataType);
    if (typeSize != 0) {
      dataSize = values.count * typeSize;
    } else {
      for (id value in values) {
        dataSize +=
            ComputePBSerializedSizeNoTagOfObject(description->dataType, value);
      }
    }
    [output writeRawVarintSizeTAs32:dataSize];
    for (id value in values) {
      WriteObjectNoTagToCodedOutputStream(value, description, output);
    }
  } else {
    for (id value in values) {
      WriteObjectIncludingTagToCodedOutputStream(value, description, output);
    }
  }
}

// Direct access is use for speed, to avoid even internally declaring things
// read/write, etc. The warning is enabled in the project to ensure code calling
// protos can turn on -Wdirect-ivar-access without issues.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

void LCGPBExtensionMergeFromInputStream(LCGPBExtensionDescriptor *extension,
                                      BOOL isPackedOnStream,
                                      LCGPBCodedInputStream *input,
                                      LCGPBExtensionRegistry *extensionRegistry,
                                      LCGPBMessage *message) {
  LCGPBExtensionDescription *description = extension->description_;
  LCGPBCodedInputStreamState *state = &input->state_;
  if (isPackedOnStream) {
    NSCAssert(LCGPBExtensionIsRepeated(description),
              @"How was it packed if it isn't repeated?");
    int32_t length = LCGPBCodedInputStreamReadInt32(state);
    size_t limit = LCGPBCodedInputStreamPushLimit(state, length);
    while (LCGPBCodedInputStreamBytesUntilLimit(state) > 0) {
      id value = NewSingleValueFromInputStream(extension,
                                               input,
                                               extensionRegistry,
                                               nil);
      [message addExtension:extension value:value];
      [value release];
    }
    LCGPBCodedInputStreamPopLimit(state, limit);
  } else {
    id existingValue = nil;
    BOOL isRepeated = LCGPBExtensionIsRepeated(description);
    if (!isRepeated && LCGPBDataTypeIsMessage(description->dataType)) {
      existingValue = [message getExistingExtension:extension];
    }
    id value = NewSingleValueFromInputStream(extension,
                                             input,
                                             extensionRegistry,
                                             existingValue);
    if (isRepeated) {
      [message addExtension:extension value:value];
    } else {
      [message setExtension:extension value:value];
    }
    [value release];
  }
}

void LCGPBWriteExtensionValueToOutputStream(LCGPBExtensionDescriptor *extension,
                                          id value,
                                          LCGPBCodedOutputStream *output) {
  LCGPBExtensionDescription *description = extension->description_;
  if (LCGPBExtensionIsRepeated(description)) {
    WriteArrayIncludingTagsToCodedOutputStream(value, description, output);
  } else {
    WriteObjectIncludingTagToCodedOutputStream(value, description, output);
  }
}

size_t LCGPBComputeExtensionSerializedSizeIncludingTag(
    LCGPBExtensionDescriptor *extension, id value) {
  LCGPBExtensionDescription *description = extension->description_;
  if (LCGPBExtensionIsRepeated(description)) {
    return ComputeSerializedSizeIncludingTagOfArray(description, value);
  } else {
    return ComputeSerializedSizeIncludingTagOfObject(description, value);
  }
}

// Note that this returns a retained value intentionally.
static id NewSingleValueFromInputStream(LCGPBExtensionDescriptor *extension,
                                        LCGPBCodedInputStream *input,
                                        LCGPBExtensionRegistry *extensionRegistry,
                                        LCGPBMessage *existingValue) {
  LCGPBExtensionDescription *description = extension->description_;
  LCGPBCodedInputStreamState *state = &input->state_;
  switch (description->dataType) {
    case LCGPBDataTypeBool:     return [[NSNumber alloc] initWithBool:LCGPBCodedInputStreamReadBool(state)];
    case LCGPBDataTypeFixed32:  return [[NSNumber alloc] initWithUnsignedInt:LCGPBCodedInputStreamReadFixed32(state)];
    case LCGPBDataTypeSFixed32: return [[NSNumber alloc] initWithInt:LCGPBCodedInputStreamReadSFixed32(state)];
    case LCGPBDataTypeFloat:    return [[NSNumber alloc] initWithFloat:LCGPBCodedInputStreamReadFloat(state)];
    case LCGPBDataTypeFixed64:  return [[NSNumber alloc] initWithUnsignedLongLong:LCGPBCodedInputStreamReadFixed64(state)];
    case LCGPBDataTypeSFixed64: return [[NSNumber alloc] initWithLongLong:LCGPBCodedInputStreamReadSFixed64(state)];
    case LCGPBDataTypeDouble:   return [[NSNumber alloc] initWithDouble:LCGPBCodedInputStreamReadDouble(state)];
    case LCGPBDataTypeInt32:    return [[NSNumber alloc] initWithInt:LCGPBCodedInputStreamReadInt32(state)];
    case LCGPBDataTypeInt64:    return [[NSNumber alloc] initWithLongLong:LCGPBCodedInputStreamReadInt64(state)];
    case LCGPBDataTypeSInt32:   return [[NSNumber alloc] initWithInt:LCGPBCodedInputStreamReadSInt32(state)];
    case LCGPBDataTypeSInt64:   return [[NSNumber alloc] initWithLongLong:LCGPBCodedInputStreamReadSInt64(state)];
    case LCGPBDataTypeUInt32:   return [[NSNumber alloc] initWithUnsignedInt:LCGPBCodedInputStreamReadUInt32(state)];
    case LCGPBDataTypeUInt64:   return [[NSNumber alloc] initWithUnsignedLongLong:LCGPBCodedInputStreamReadUInt64(state)];
    case LCGPBDataTypeBytes:    return LCGPBCodedInputStreamReadRetainedBytes(state);
    case LCGPBDataTypeString:   return LCGPBCodedInputStreamReadRetainedString(state);
    case LCGPBDataTypeEnum:     return [[NSNumber alloc] initWithInt:LCGPBCodedInputStreamReadEnum(state)];
    case LCGPBDataTypeGroup:
    case LCGPBDataTypeMessage: {
      LCGPBMessage *message;
      if (existingValue) {
        message = [existingValue retain];
      } else {
        LCGPBDescriptor *decriptor = [extension.msgClass descriptor];
        message = [[decriptor.messageClass alloc] init];
      }

      if (description->dataType == LCGPBDataTypeGroup) {
        [input readGroup:description->fieldNumber
                 message:message
            extensionRegistry:extensionRegistry];
      } else {
        // description->dataType == LCGPBDataTypeMessage
        if (LCGPBExtensionIsWireFormat(description)) {
          // For MessageSet fields the message length will have already been
          // read.
          [message mergeFromCodedInputStream:input
                           extensionRegistry:extensionRegistry];
        } else {
          [input readMessage:message extensionRegistry:extensionRegistry];
        }
      }

      return message;
    }
  }

  return nil;
}

#pragma clang diagnostic pop
