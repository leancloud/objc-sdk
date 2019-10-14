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

#import "LCGPBCodedInputStream.h"

@class LCGPBUnknownFieldSet;
@class LCGPBFieldDescriptor;

typedef struct LCGPBCodedInputStreamState {
  const uint8_t *bytes;
  size_t bufferSize;
  size_t bufferPos;

  // For parsing subsections of an input stream you can put a hard limit on
  // how much should be read. Normally the limit is the end of the stream,
  // but you can adjust it to anywhere, and if you hit it you will be at the
  // end of the stream, until you adjust the limit.
  size_t currentLimit;
  int32_t lastTag;
  NSUInteger recursionDepth;
} LCGPBCodedInputStreamState;

@interface LCGPBCodedInputStream () {
 @package
  struct LCGPBCodedInputStreamState state_;
  NSData *buffer_;
}

// Group support is deprecated, so we hide this interface from users, but
// support for older data.
- (void)readGroup:(int32_t)fieldNumber
              message:(LCGPBMessage *)message
    extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry;

// Reads a group field value from the stream and merges it into the given
// UnknownFieldSet.
- (void)readUnknownGroup:(int32_t)fieldNumber
                 message:(LCGPBUnknownFieldSet *)message;

// Reads a map entry.
- (void)readMapEntry:(id)mapDictionary
    extensionRegistry:(LCGPBExtensionRegistry *)extensionRegistry
                field:(LCGPBFieldDescriptor *)field
        parentMessage:(LCGPBMessage *)parentMessage;
@end

CF_EXTERN_C_BEGIN

int32_t LCGPBCodedInputStreamReadTag(LCGPBCodedInputStreamState *state);

double LCGPBCodedInputStreamReadDouble(LCGPBCodedInputStreamState *state);
float LCGPBCodedInputStreamReadFloat(LCGPBCodedInputStreamState *state);
uint64_t LCGPBCodedInputStreamReadUInt64(LCGPBCodedInputStreamState *state);
uint32_t LCGPBCodedInputStreamReadUInt32(LCGPBCodedInputStreamState *state);
int64_t LCGPBCodedInputStreamReadInt64(LCGPBCodedInputStreamState *state);
int32_t LCGPBCodedInputStreamReadInt32(LCGPBCodedInputStreamState *state);
uint64_t LCGPBCodedInputStreamReadFixed64(LCGPBCodedInputStreamState *state);
uint32_t LCGPBCodedInputStreamReadFixed32(LCGPBCodedInputStreamState *state);
int32_t LCGPBCodedInputStreamReadEnum(LCGPBCodedInputStreamState *state);
int32_t LCGPBCodedInputStreamReadSFixed32(LCGPBCodedInputStreamState *state);
int64_t LCGPBCodedInputStreamReadSFixed64(LCGPBCodedInputStreamState *state);
int32_t LCGPBCodedInputStreamReadSInt32(LCGPBCodedInputStreamState *state);
int64_t LCGPBCodedInputStreamReadSInt64(LCGPBCodedInputStreamState *state);
BOOL LCGPBCodedInputStreamReadBool(LCGPBCodedInputStreamState *state);
NSString *LCGPBCodedInputStreamReadRetainedString(LCGPBCodedInputStreamState *state)
    __attribute((ns_returns_retained));
NSData *LCGPBCodedInputStreamReadRetainedBytes(LCGPBCodedInputStreamState *state)
    __attribute((ns_returns_retained));
NSData *LCGPBCodedInputStreamReadRetainedBytesNoCopy(
    LCGPBCodedInputStreamState *state) __attribute((ns_returns_retained));

size_t LCGPBCodedInputStreamPushLimit(LCGPBCodedInputStreamState *state,
                                    size_t byteLimit);
void LCGPBCodedInputStreamPopLimit(LCGPBCodedInputStreamState *state,
                                 size_t oldLimit);
size_t LCGPBCodedInputStreamBytesUntilLimit(LCGPBCodedInputStreamState *state);
BOOL LCGPBCodedInputStreamIsAtEnd(LCGPBCodedInputStreamState *state);
void LCGPBCodedInputStreamCheckLastTagWas(LCGPBCodedInputStreamState *state,
                                        int32_t value);

CF_EXTERN_C_END
