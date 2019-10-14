// Protocol Buffers - Google's data interchange format
// Copyright 2016 Google Inc.  All rights reserved.
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

#import "LCGPBCodedOutputStream.h"

NS_ASSUME_NONNULL_BEGIN

CF_EXTERN_C_BEGIN

size_t LCGPBComputeDoubleSize(int32_t fieldNumber, double value)
    __attribute__((const));
size_t LCGPBComputeFloatSize(int32_t fieldNumber, float value)
    __attribute__((const));
size_t LCGPBComputeUInt64Size(int32_t fieldNumber, uint64_t value)
    __attribute__((const));
size_t LCGPBComputeInt64Size(int32_t fieldNumber, int64_t value)
    __attribute__((const));
size_t LCGPBComputeInt32Size(int32_t fieldNumber, int32_t value)
    __attribute__((const));
size_t LCGPBComputeFixed64Size(int32_t fieldNumber, uint64_t value)
    __attribute__((const));
size_t LCGPBComputeFixed32Size(int32_t fieldNumber, uint32_t value)
    __attribute__((const));
size_t LCGPBComputeBoolSize(int32_t fieldNumber, BOOL value)
    __attribute__((const));
size_t LCGPBComputeStringSize(int32_t fieldNumber, NSString *value)
    __attribute__((const));
size_t LCGPBComputeGroupSize(int32_t fieldNumber, LCGPBMessage *value)
    __attribute__((const));
size_t LCGPBComputeUnknownGroupSize(int32_t fieldNumber,
                                  LCGPBUnknownFieldSet *value)
    __attribute__((const));
size_t LCGPBComputeMessageSize(int32_t fieldNumber, LCGPBMessage *value)
    __attribute__((const));
size_t LCGPBComputeBytesSize(int32_t fieldNumber, NSData *value)
    __attribute__((const));
size_t LCGPBComputeUInt32Size(int32_t fieldNumber, uint32_t value)
    __attribute__((const));
size_t LCGPBComputeSFixed32Size(int32_t fieldNumber, int32_t value)
    __attribute__((const));
size_t LCGPBComputeSFixed64Size(int32_t fieldNumber, int64_t value)
    __attribute__((const));
size_t LCGPBComputeSInt32Size(int32_t fieldNumber, int32_t value)
    __attribute__((const));
size_t LCGPBComputeSInt64Size(int32_t fieldNumber, int64_t value)
    __attribute__((const));
size_t LCGPBComputeTagSize(int32_t fieldNumber) __attribute__((const));
size_t LCGPBComputeWireFormatTagSize(int field_number, LCGPBDataType dataType)
    __attribute__((const));

size_t LCGPBComputeDoubleSizeNoTag(double value) __attribute__((const));
size_t LCGPBComputeFloatSizeNoTag(float value) __attribute__((const));
size_t LCGPBComputeUInt64SizeNoTag(uint64_t value) __attribute__((const));
size_t LCGPBComputeInt64SizeNoTag(int64_t value) __attribute__((const));
size_t LCGPBComputeInt32SizeNoTag(int32_t value) __attribute__((const));
size_t LCGPBComputeFixed64SizeNoTag(uint64_t value) __attribute__((const));
size_t LCGPBComputeFixed32SizeNoTag(uint32_t value) __attribute__((const));
size_t LCGPBComputeBoolSizeNoTag(BOOL value) __attribute__((const));
size_t LCGPBComputeStringSizeNoTag(NSString *value) __attribute__((const));
size_t LCGPBComputeGroupSizeNoTag(LCGPBMessage *value) __attribute__((const));
size_t LCGPBComputeUnknownGroupSizeNoTag(LCGPBUnknownFieldSet *value)
    __attribute__((const));
size_t LCGPBComputeMessageSizeNoTag(LCGPBMessage *value) __attribute__((const));
size_t LCGPBComputeBytesSizeNoTag(NSData *value) __attribute__((const));
size_t LCGPBComputeUInt32SizeNoTag(int32_t value) __attribute__((const));
size_t LCGPBComputeEnumSizeNoTag(int32_t value) __attribute__((const));
size_t LCGPBComputeSFixed32SizeNoTag(int32_t value) __attribute__((const));
size_t LCGPBComputeSFixed64SizeNoTag(int64_t value) __attribute__((const));
size_t LCGPBComputeSInt32SizeNoTag(int32_t value) __attribute__((const));
size_t LCGPBComputeSInt64SizeNoTag(int64_t value) __attribute__((const));

// Note that this will calculate the size of 64 bit values truncated to 32.
size_t LCGPBComputeSizeTSizeAsInt32NoTag(size_t value) __attribute__((const));

size_t LCGPBComputeRawVarint32Size(int32_t value) __attribute__((const));
size_t LCGPBComputeRawVarint64Size(int64_t value) __attribute__((const));

// Note that this will calculate the size of 64 bit values truncated to 32.
size_t LCGPBComputeRawVarint32SizeForInteger(NSInteger value)
    __attribute__((const));

// Compute the number of bytes that would be needed to encode a
// MessageSet extension to the stream.  For historical reasons,
// the wire format differs from normal fields.
size_t LCGPBComputeMessageSetExtensionSize(int32_t fieldNumber, LCGPBMessage *value)
    __attribute__((const));

// Compute the number of bytes that would be needed to encode an
// unparsed MessageSet extension field to the stream.  For
// historical reasons, the wire format differs from normal fields.
size_t LCGPBComputeRawMessageSetExtensionSize(int32_t fieldNumber, NSData *value)
    __attribute__((const));

size_t LCGPBComputeEnumSize(int32_t fieldNumber, int32_t value)
    __attribute__((const));

CF_EXTERN_C_END

NS_ASSUME_NONNULL_END
