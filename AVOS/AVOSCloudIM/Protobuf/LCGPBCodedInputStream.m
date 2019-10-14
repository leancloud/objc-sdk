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

#import "LCGPBCodedInputStream_PackagePrivate.h"

#import "LCGPBDictionary_PackagePrivate.h"
#import "LCGPBMessage_PackagePrivate.h"
#import "LCGPBUnknownFieldSet_PackagePrivate.h"
#import "LCGPBUtilities_PackagePrivate.h"
#import "LCGPBWireFormat.h"

NSString *const LCGPBCodedInputStreamException =
    LCGPBNSStringifySymbol(LCGPBCodedInputStreamException);

NSString *const LCGPBCodedInputStreamUnderlyingErrorKey =
    LCGPBNSStringifySymbol(LCGPBCodedInputStreamUnderlyingErrorKey);

NSString *const LCGPBCodedInputStreamErrorDomain =
    LCGPBNSStringifySymbol(LCGPBCodedInputStreamErrorDomain);

// Matching:
// https://github.com/protocolbuffers/protobuf/blob/master/java/core/src/main/java/com/google/protobuf/CodedInputStream.java#L62
//  private static final int DEFAULT_RECURSION_LIMIT = 100;
// https://github.com/protocolbuffers/protobuf/blob/master/src/google/protobuf/io/coded_stream.cc#L86
//  int CodedInputStream::default_recursion_limit_ = 100;
static const NSUInteger kDefaultRecursionLimit = 100;

static void RaiseException(NSInteger code, NSString *reason) {
  NSDictionary *errorInfo = nil;
  if ([reason length]) {
    errorInfo = @{ LCGPBErrorReasonKey: reason };
  }
  NSError *error = [NSError errorWithDomain:LCGPBCodedInputStreamErrorDomain
                                       code:code
                                   userInfo:errorInfo];

  NSDictionary *exceptionInfo =
      @{ LCGPBCodedInputStreamUnderlyingErrorKey: error };
  [[NSException exceptionWithName:LCGPBCodedInputStreamException
                           reason:reason
                         userInfo:exceptionInfo] raise];
}

static void CheckRecursionLimit(LCGPBCodedInputStreamState *state) {
  if (state->recursionDepth >= kDefaultRecursionLimit) {
    RaiseException(LCGPBCodedInputStreamErrorRecursionDepthExceeded, nil);
  }
}

static void CheckSize(LCGPBCodedInputStreamState *state, size_t size) {
  size_t newSize = state->bufferPos + size;
  if (newSize > state->bufferSize) {
    RaiseException(LCGPBCodedInputStreamErrorInvalidSize, nil);
  }
  if (newSize > state->currentLimit) {
    // Fast forward to end of currentLimit;
    state->bufferPos = state->currentLimit;
    RaiseException(LCGPBCodedInputStreamErrorSubsectionLimitReached, nil);
  }
}

static int8_t ReadRawByte(LCGPBCodedInputStreamState *state) {
  CheckSize(state, sizeof(int8_t));
  return ((int8_t *)state->bytes)[state->bufferPos++];
}

static int32_t ReadRawLittleEndian32(LCGPBCodedInputStreamState *state) {
  CheckSize(state, sizeof(int32_t));
  // Not using OSReadLittleInt32 because it has undocumented dependency
  // on reads being aligned.
  int32_t value;
  memcpy(&value, state->bytes + state->bufferPos, sizeof(int32_t));
  value = OSSwapLittleToHostInt32(value);
  state->bufferPos += sizeof(int32_t);
  return value;
}

static int64_t ReadRawLittleEndian64(LCGPBCodedInputStreamState *state) {
  CheckSize(state, sizeof(int64_t));
  // Not using OSReadLittleInt64 because it has undocumented dependency
  // on reads being aligned.  
  int64_t value;
  memcpy(&value, state->bytes + state->bufferPos, sizeof(int64_t));
  value = OSSwapLittleToHostInt64(value);
  state->bufferPos += sizeof(int64_t);
  return value;
}

static int64_t ReadRawVarint64(LCGPBCodedInputStreamState *state) {
  int32_t shift = 0;
  int64_t result = 0;
  while (shift < 64) {
    int8_t b = ReadRawByte(state);
    result |= (int64_t)((uint64_t)(b & 0x7F) << shift);
    if ((b & 0x80) == 0) {
      return result;
    }
    shift += 7;
  }
  RaiseException(LCGPBCodedInputStreamErrorInvalidVarInt, @"Invalid VarInt64");
  return 0;
}

static int32_t ReadRawVarint32(LCGPBCodedInputStreamState *state) {
  return (int32_t)ReadRawVarint64(state);
}

static void SkipRawData(LCGPBCodedInputStreamState *state, size_t size) {
  CheckSize(state, size);
  state->bufferPos += size;
}

double LCGPBCodedInputStreamReadDouble(LCGPBCodedInputStreamState *state) {
  int64_t value = ReadRawLittleEndian64(state);
  return LCGPBConvertInt64ToDouble(value);
}

float LCGPBCodedInputStreamReadFloat(LCGPBCodedInputStreamState *state) {
  int32_t value = ReadRawLittleEndian32(state);
  return LCGPBConvertInt32ToFloat(value);
}

uint64_t LCGPBCodedInputStreamReadUInt64(LCGPBCodedInputStreamState *state) {
  uint64_t value = ReadRawVarint64(state);
  return value;
}

uint32_t LCGPBCodedInputStreamReadUInt32(LCGPBCodedInputStreamState *state) {
  uint32_t value = ReadRawVarint32(state);
  return value;
}

int64_t LCGPBCodedInputStreamReadInt64(LCGPBCodedInputStreamState *state) {
  int64_t value = ReadRawVarint64(state);
  return value;
}

int32_t LCGPBCodedInputStreamReadInt32(LCGPBCodedInputStreamState *state) {
  int32_t value = ReadRawVarint32(state);
  return value;
}

uint64_t LCGPBCodedInputStreamReadFixed64(LCGPBCodedInputStreamState *state) {
  uint64_t value = ReadRawLittleEndian64(state);
  return value;
}

uint32_t LCGPBCodedInputStreamReadFixed32(LCGPBCodedInputStreamState *state) {
  uint32_t value = ReadRawLittleEndian32(state);
  return value;
}

int32_t LCGPBCodedInputStreamReadEnum(LCGPBCodedInputStreamState *state) {
  int32_t value = ReadRawVarint32(state);
  return value;
}

int32_t LCGPBCodedInputStreamReadSFixed32(LCGPBCodedInputStreamState *state) {
  int32_t value = ReadRawLittleEndian32(state);
  return value;
}

int64_t LCGPBCodedInputStreamReadSFixed64(LCGPBCodedInputStreamState *state) {
  int64_t value = ReadRawLittleEndian64(state);
  return value;
}

int32_t LCGPBCodedInputStreamReadSInt32(LCGPBCodedInputStreamState *state) {
  int32_t value = LCGPBDecodeZigZag32(ReadRawVarint32(state));
  return value;
}

int64_t LCGPBCodedInputStreamReadSInt64(LCGPBCodedInputStreamState *state) {
  int64_t value = LCGPBDecodeZigZag64(ReadRawVarint64(state));
  return value;
}

BOOL LCGPBCodedInputStreamReadBool(LCGPBCodedInputStreamState *state) {
  return ReadRawVarint32(state) != 0;
}

int32_t LCGPBCodedInputStreamReadTag(LCGPBCodedInputStreamState *state) {
  if (LCGPBCodedInputStreamIsAtEnd(state)) {
    state->lastTag = 0;
    return 0;
  }

  state->lastTag = ReadRawVarint32(state);
  // Tags have to include a valid wireformat.
  if (!LCGPBWireFormatIsValidTag(state->lastTag)) {
    RaiseException(LCGPBCodedInputStreamErrorInvalidTag,
                   @"Invalid wireformat in tag.");
  }
  // Zero is not a valid field number.
  if (LCGPBWireFormatGetTagFieldNumber(state->lastTag) == 0) {
    RaiseException(LCGPBCodedInputStreamErrorInvalidTag,
                   @"A zero field number on the wire is invalid.");
  }
  return state->lastTag;
}

NSString *LCGPBCodedInputStreamReadRetainedString(
    LCGPBCodedInputStreamState *state) {
  int32_t size = ReadRawVarint32(state);
  NSString *result;
  if (size == 0) {
    result = @"";
  } else {
    CheckSize(state, size);
    result = [[NSString alloc] initWithBytes:&state->bytes[state->bufferPos]
                                      length:size
                                    encoding:NSUTF8StringEncoding];
    state->bufferPos += size;
    if (!result) {
#ifdef DEBUG
      // https://developers.google.com/protocol-buffers/docs/proto#scalar
      NSLog(@"UTF-8 failure, is some field type 'string' when it should be "
            @"'bytes'?");
#endif
      RaiseException(LCGPBCodedInputStreamErrorInvalidUTF8, nil);
    }
  }
  return result;
}

NSData *LCGPBCodedInputStreamReadRetainedBytes(LCGPBCodedInputStreamState *state) {
  int32_t size = ReadRawVarint32(state);
  if (size < 0) return nil;
  CheckSize(state, size);
  NSData *result = [[NSData alloc] initWithBytes:state->bytes + state->bufferPos
                                          length:size];
  state->bufferPos += size;
  return result;
}

NSData *LCGPBCodedInputStreamReadRetainedBytesNoCopy(
    LCGPBCodedInputStreamState *state) {
  int32_t size = ReadRawVarint32(state);
  if (size < 0) return nil;
  CheckSize(state, size);
  // Cast is safe because freeWhenDone is NO.
  NSData *result = [[NSData alloc]
      initWithBytesNoCopy:(void *)(state->bytes + state->bufferPos)
                   length:size
             freeWhenDone:NO];
  state->bufferPos += size;
  return result;
}

size_t LCGPBCodedInputStreamPushLimit(LCGPBCodedInputStreamState *state,
                                    size_t byteLimit) {
  byteLimit += state->bufferPos;
  size_t oldLimit = state->currentLimit;
  if (byteLimit > oldLimit) {
    RaiseException(LCGPBCodedInputStreamErrorInvalidSubsectionLimit, nil);
  }
  state->currentLimit = byteLimit;
  return oldLimit;
}

void LCGPBCodedInputStreamPopLimit(LCGPBCodedInputStreamState *state,
                                 size_t oldLimit) {
  state->currentLimit = oldLimit;
}

size_t LCGPBCodedInputStreamBytesUntilLimit(LCGPBCodedInputStreamState *state) {
  return state->currentLimit - state->bufferPos;
}

BOOL LCGPBCodedInputStreamIsAtEnd(LCGPBCodedInputStreamState *state) {
  return (state->bufferPos == state->bufferSize) ||
         (state->bufferPos == state->currentLimit);
}

void LCGPBCodedInputStreamCheckLastTagWas(LCGPBCodedInputStreamState *state,
                                        int32_t value) {
  if (state->lastTag != value) {
    RaiseException(LCGPBCodedInputStreamErrorInvalidTag, @"Unexpected tag read");
  }
}

@implementation LCGPBCodedInputStream

+ (instancetype)streamWithData:(NSData *)data {
  return [[[self alloc] initWithData:data] autorelease];
}

- (instancetype)initWithData:(NSData *)data {
  if ((self = [super init])) {
#ifdef DEBUG
    NSCAssert([self class] == [LCGPBCodedInputStream class],
              @"Subclassing of LCGPBCodedInputStream is not allowed.");
#endif
    buffer_ = [data retain];
    state_.bytes = (const uint8_t *)[data bytes];
    state_.bufferSize = [data length];
    state_.currentLimit = state_.bufferSize;
  }
  return self;
}

- (void)dealloc {
  [buffer_ release];
  [super dealloc];
}

// Direct access is use for speed, to avoid even internally declaring things
// read/write, etc. The warning is enabled in the project to ensure code calling
// protos can turn on -Wdirect-ivar-access without issues.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

- (int32_t)readTag {
  return LCGPBCodedInputStreamReadTag(&state_);
}

- (void)checkLastTagWas:(int32_t)value {
  LCGPBCodedInputStreamCheckLastTagWas(&state_, value);
}

- (BOOL)skipField:(int32_t)tag {
  NSAssert(LCGPBWireFormatIsValidTag(tag), @"Invalid tag");
  switch (LCGPBWireFormatGetTagWireType(tag)) {
    case LCGPBWireFormatVarint:
      LCGPBCodedInputStreamReadInt32(&state_);
      return YES;
    case LCGPBWireFormatFixed64:
      SkipRawData(&state_, sizeof(int64_t));
      return YES;
    case LCGPBWireFormatLengthDelimited:
      SkipRawData(&state_, ReadRawVarint32(&state_));
      return YES;
    case LCGPBWireFormatStartGroup:
      [self skipMessage];
      LCGPBCodedInputStreamCheckLastTagWas(
          &state_, LCGPBWireFormatMakeTag(LCGPBWireFormatGetTagFieldNumber(tag),
                                        LCGPBWireFormatEndGroup));
      return YES;
    case LCGPBWireFormatEndGroup:
      return NO;
    case LCGPBWireFormatFixed32:
      SkipRawData(&state_, sizeof(int32_t));
      return YES;
  }
}

- (void)skipMessage {
  while (YES) {
    int32_t tag = LCGPBCodedInputStreamReadTag(&state_);
    if (tag == 0 || ![self skipField:tag]) {
      return;
    }
  }
}

- (BOOL)isAtEnd {
  return LCGPBCodedInputStreamIsAtEnd(&state_);
}

- (size_t)position {
  return state_.bufferPos;
}

- (size_t)pushLimit:(size_t)byteLimit {
  return LCGPBCodedInputStreamPushLimit(&state_, byteLimit);
}

- (void)popLimit:(size_t)oldLimit {
  LCGPBCodedInputStreamPopLimit(&state_, oldLimit);
}

- (double)readDouble {
  return LCGPBCodedInputStreamReadDouble(&state_);
}

- (float)readFloat {
  return LCGPBCodedInputStreamReadFloat(&state_);
}

- (uint64_t)readUInt64 {
  return LCGPBCodedInputStreamReadUInt64(&state_);
}

- (int64_t)readInt64 {
  return LCGPBCodedInputStreamReadInt64(&state_);
}

- (int32_t)readInt32 {
  return LCGPBCodedInputStreamReadInt32(&state_);
}

- (uint64_t)readFixed64 {
  return LCGPBCodedInputStreamReadFixed64(&state_);
}

- (uint32_t)readFixed32 {
  return LCGPBCodedInputStreamReadFixed32(&state_);
}

- (BOOL)readBool {
  return LCGPBCodedInputStreamReadBool(&state_);
}

- (NSString *)readString {
  return [LCGPBCodedInputStreamReadRetainedString(&state_) autorelease];
}

- (void)readGroup:(int32_t)fieldNumber
              message:(LCGPBMessage *)message
    extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry {
  CheckRecursionLimit(&state_);
  ++state_.recursionDepth;
  [message mergeFromCodedInputStream:self extensionRegistry:extensionRegistry];
  LCGPBCodedInputStreamCheckLastTagWas(
      &state_, LCGPBWireFormatMakeTag(fieldNumber, LCGPBWireFormatEndGroup));
  --state_.recursionDepth;
}

- (void)readUnknownGroup:(int32_t)fieldNumber
                 message:(LCGPBUnknownFieldSet *)message {
  CheckRecursionLimit(&state_);
  ++state_.recursionDepth;
  [message mergeFromCodedInputStream:self];
  LCGPBCodedInputStreamCheckLastTagWas(
      &state_, LCGPBWireFormatMakeTag(fieldNumber, LCGPBWireFormatEndGroup));
  --state_.recursionDepth;
}

- (void)readMessage:(LCGPBMessage *)message
    extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry {
  CheckRecursionLimit(&state_);
  int32_t length = ReadRawVarint32(&state_);
  size_t oldLimit = LCGPBCodedInputStreamPushLimit(&state_, length);
  ++state_.recursionDepth;
  [message mergeFromCodedInputStream:self extensionRegistry:extensionRegistry];
  LCGPBCodedInputStreamCheckLastTagWas(&state_, 0);
  --state_.recursionDepth;
  LCGPBCodedInputStreamPopLimit(&state_, oldLimit);
}

- (void)readMapEntry:(id)mapDictionary
    extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry
                field:(LCGPBFieldDescriptor *)field
        parentMessage:(LCGPBMessage *)parentMessage {
  CheckRecursionLimit(&state_);
  int32_t length = ReadRawVarint32(&state_);
  size_t oldLimit = LCGPBCodedInputStreamPushLimit(&state_, length);
  ++state_.recursionDepth;
  LCGPBDictionaryReadEntry(mapDictionary, self, extensionRegistry, field,
                         parentMessage);
  LCGPBCodedInputStreamCheckLastTagWas(&state_, 0);
  --state_.recursionDepth;
  LCGPBCodedInputStreamPopLimit(&state_, oldLimit);
}

- (NSData *)readBytes {
  return [LCGPBCodedInputStreamReadRetainedBytes(&state_) autorelease];
}

- (uint32_t)readUInt32 {
  return LCGPBCodedInputStreamReadUInt32(&state_);
}

- (int32_t)readEnum {
  return LCGPBCodedInputStreamReadEnum(&state_);
}

- (int32_t)readSFixed32 {
  return LCGPBCodedInputStreamReadSFixed32(&state_);
}

- (int64_t)readSFixed64 {
  return LCGPBCodedInputStreamReadSFixed64(&state_);
}

- (int32_t)readSInt32 {
  return LCGPBCodedInputStreamReadSInt32(&state_);
}

- (int64_t)readSInt64 {
  return LCGPBCodedInputStreamReadSInt64(&state_);
}

#pragma clang diagnostic pop

@end
