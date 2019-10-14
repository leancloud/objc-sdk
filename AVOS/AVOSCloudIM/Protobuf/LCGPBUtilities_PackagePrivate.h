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

#import "LCGPBUtilities.h"

#import "LCGPBDescriptor_PackagePrivate.h"

// Macros for stringifying library symbols. These are used in the generated
// PB descriptor classes wherever a library symbol name is represented as a
// string. See README.google for more information.
#define LCGPBStringify(S) #S
#define LCGPBStringifySymbol(S) LCGPBStringify(S)

#define LCGPBNSStringify(S) @#S
#define LCGPBNSStringifySymbol(S) LCGPBNSStringify(S)

// Constant to internally mark when there is no has bit.
#define LCGPBNoHasBit INT32_MAX

CF_EXTERN_C_BEGIN

// These two are used to inject a runtime check for version mismatch into the
// generated sources to make sure they are linked with a supporting runtime.
void LCGPBCheckRuntimeVersionSupport(int32_t objcRuntimeVersion);
LCGPB_INLINE void LCGPB_DEBUG_CHECK_RUNTIME_VERSIONS() {
  // NOTE: By being inline here, this captures the value from the library's
  // headers at the time the generated code was compiled.
#if defined(DEBUG) && DEBUG
  LCGPBCheckRuntimeVersionSupport(GOOGLE_PROTOBUF_OBJC_VERSION);
#endif
}

// Legacy version of the checks, remove when GOOGLE_PROTOBUF_OBJC_GEN_VERSION
// goes away (see more info in LCGPBBootstrap.h).
void LCGPBCheckRuntimeVersionInternal(int32_t version);
LCGPB_INLINE void LCGPBDebugCheckRuntimeVersion() {
#if defined(DEBUG) && DEBUG
  LCGPBCheckRuntimeVersionInternal(GOOGLE_PROTOBUF_OBJC_GEN_VERSION);
#endif
}

// Conversion functions for de/serializing floating point types.

LCGPB_INLINE int64_t LCGPBConvertDoubleToInt64(double v) {
  LCGPBInternalCompileAssert(sizeof(double) == sizeof(int64_t), double_not_64_bits);
  int64_t result;
  memcpy(&result, &v, sizeof(result));
  return result;
}

LCGPB_INLINE int32_t LCGPBConvertFloatToInt32(float v) {
  LCGPBInternalCompileAssert(sizeof(float) == sizeof(int32_t), float_not_32_bits);
  int32_t result;
  memcpy(&result, &v, sizeof(result));
  return result;
}

LCGPB_INLINE double LCGPBConvertInt64ToDouble(int64_t v) {
  LCGPBInternalCompileAssert(sizeof(double) == sizeof(int64_t), double_not_64_bits);
  double result;
  memcpy(&result, &v, sizeof(result));
  return result;
}

LCGPB_INLINE float LCGPBConvertInt32ToFloat(int32_t v) {
  LCGPBInternalCompileAssert(sizeof(float) == sizeof(int32_t), float_not_32_bits);
  float result;
  memcpy(&result, &v, sizeof(result));
  return result;
}

LCGPB_INLINE int32_t LCGPBLogicalRightShift32(int32_t value, int32_t spaces) {
  return (int32_t)((uint32_t)(value) >> spaces);
}

LCGPB_INLINE int64_t LCGPBLogicalRightShift64(int64_t value, int32_t spaces) {
  return (int64_t)((uint64_t)(value) >> spaces);
}

// Decode a ZigZag-encoded 32-bit value.  ZigZag encodes signed integers
// into values that can be efficiently encoded with varint.  (Otherwise,
// negative values must be sign-extended to 64 bits to be varint encoded,
// thus always taking 10 bytes on the wire.)
LCGPB_INLINE int32_t LCGPBDecodeZigZag32(uint32_t n) {
  return (int32_t)(LCGPBLogicalRightShift32((int32_t)n, 1) ^ -((int32_t)(n) & 1));
}

// Decode a ZigZag-encoded 64-bit value.  ZigZag encodes signed integers
// into values that can be efficiently encoded with varint.  (Otherwise,
// negative values must be sign-extended to 64 bits to be varint encoded,
// thus always taking 10 bytes on the wire.)
LCGPB_INLINE int64_t LCGPBDecodeZigZag64(uint64_t n) {
  return (int64_t)(LCGPBLogicalRightShift64((int64_t)n, 1) ^ -((int64_t)(n) & 1));
}

// Encode a ZigZag-encoded 32-bit value.  ZigZag encodes signed integers
// into values that can be efficiently encoded with varint.  (Otherwise,
// negative values must be sign-extended to 64 bits to be varint encoded,
// thus always taking 10 bytes on the wire.)
LCGPB_INLINE uint32_t LCGPBEncodeZigZag32(int32_t n) {
  // Note:  the right-shift must be arithmetic
  return ((uint32_t)n << 1) ^ (uint32_t)(n >> 31);
}

// Encode a ZigZag-encoded 64-bit value.  ZigZag encodes signed integers
// into values that can be efficiently encoded with varint.  (Otherwise,
// negative values must be sign-extended to 64 bits to be varint encoded,
// thus always taking 10 bytes on the wire.)
LCGPB_INLINE uint64_t LCGPBEncodeZigZag64(int64_t n) {
  // Note:  the right-shift must be arithmetic
  return ((uint64_t)n << 1) ^ (uint64_t)(n >> 63);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

LCGPB_INLINE BOOL LCGPBDataTypeIsObject(LCGPBDataType type) {
  switch (type) {
    case LCGPBDataTypeBytes:
    case LCGPBDataTypeString:
    case LCGPBDataTypeMessage:
    case LCGPBDataTypeGroup:
      return YES;
    default:
      return NO;
  }
}

LCGPB_INLINE BOOL LCGPBDataTypeIsMessage(LCGPBDataType type) {
  switch (type) {
    case LCGPBDataTypeMessage:
    case LCGPBDataTypeGroup:
      return YES;
    default:
      return NO;
  }
}

LCGPB_INLINE BOOL LCGPBFieldDataTypeIsMessage(LCGPBFieldDescriptor *field) {
  return LCGPBDataTypeIsMessage(field->description_->dataType);
}

LCGPB_INLINE BOOL LCGPBFieldDataTypeIsObject(LCGPBFieldDescriptor *field) {
  return LCGPBDataTypeIsObject(field->description_->dataType);
}

LCGPB_INLINE BOOL LCGPBExtensionIsMessage(LCGPBExtensionDescriptor *ext) {
  return LCGPBDataTypeIsMessage(ext->description_->dataType);
}

// The field is an array/map or it has an object value.
LCGPB_INLINE BOOL LCGPBFieldStoresObject(LCGPBFieldDescriptor *field) {
  LCGPBMessageFieldDescription *desc = field->description_;
  if ((desc->flags & (LCGPBFieldRepeated | LCGPBFieldMapKeyMask)) != 0) {
    return YES;
  }
  return LCGPBDataTypeIsObject(desc->dataType);
}

BOOL LCGPBGetHasIvar(LCGPBMessage *self, int32_t index, uint32_t fieldNumber);
void LCGPBSetHasIvar(LCGPBMessage *self, int32_t idx, uint32_t fieldNumber,
                   BOOL value);
uint32_t LCGPBGetHasOneof(LCGPBMessage *self, int32_t index);

LCGPB_INLINE BOOL
LCGPBGetHasIvarField(LCGPBMessage *self, LCGPBFieldDescriptor *field) {
  LCGPBMessageFieldDescription *fieldDesc = field->description_;
  return LCGPBGetHasIvar(self, fieldDesc->hasIndex, fieldDesc->number);
}
LCGPB_INLINE void LCGPBSetHasIvarField(LCGPBMessage *self, LCGPBFieldDescriptor *field,
                                   BOOL value) {
  LCGPBMessageFieldDescription *fieldDesc = field->description_;
  LCGPBSetHasIvar(self, fieldDesc->hasIndex, fieldDesc->number, value);
}

void LCGPBMaybeClearOneof(LCGPBMessage *self, LCGPBOneofDescriptor *oneof,
                        int32_t oneofHasIndex, uint32_t fieldNumberNotToClear);

#pragma clang diagnostic pop

//%PDDM-DEFINE LCGPB_IVAR_SET_DECL(NAME, TYPE)
//%void LCGPBSet##NAME##IvarWithFieldInternal(LCGPBMessage *self,
//%            NAME$S                     LCGPBFieldDescriptor *field,
//%            NAME$S                     TYPE value,
//%            NAME$S                     LCGPBFileSyntax syntax);
//%PDDM-EXPAND LCGPB_IVAR_SET_DECL(Bool, BOOL)
// This block of code is generated, do not edit it directly.

void LCGPBSetBoolIvarWithFieldInternal(LCGPBMessage *self,
                                     LCGPBFieldDescriptor *field,
                                     BOOL value,
                                     LCGPBFileSyntax syntax);
//%PDDM-EXPAND LCGPB_IVAR_SET_DECL(Int32, int32_t)
// This block of code is generated, do not edit it directly.

void LCGPBSetInt32IvarWithFieldInternal(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field,
                                      int32_t value,
                                      LCGPBFileSyntax syntax);
//%PDDM-EXPAND LCGPB_IVAR_SET_DECL(UInt32, uint32_t)
// This block of code is generated, do not edit it directly.

void LCGPBSetUInt32IvarWithFieldInternal(LCGPBMessage *self,
                                       LCGPBFieldDescriptor *field,
                                       uint32_t value,
                                       LCGPBFileSyntax syntax);
//%PDDM-EXPAND LCGPB_IVAR_SET_DECL(Int64, int64_t)
// This block of code is generated, do not edit it directly.

void LCGPBSetInt64IvarWithFieldInternal(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field,
                                      int64_t value,
                                      LCGPBFileSyntax syntax);
//%PDDM-EXPAND LCGPB_IVAR_SET_DECL(UInt64, uint64_t)
// This block of code is generated, do not edit it directly.

void LCGPBSetUInt64IvarWithFieldInternal(LCGPBMessage *self,
                                       LCGPBFieldDescriptor *field,
                                       uint64_t value,
                                       LCGPBFileSyntax syntax);
//%PDDM-EXPAND LCGPB_IVAR_SET_DECL(Float, float)
// This block of code is generated, do not edit it directly.

void LCGPBSetFloatIvarWithFieldInternal(LCGPBMessage *self,
                                      LCGPBFieldDescriptor *field,
                                      float value,
                                      LCGPBFileSyntax syntax);
//%PDDM-EXPAND LCGPB_IVAR_SET_DECL(Double, double)
// This block of code is generated, do not edit it directly.

void LCGPBSetDoubleIvarWithFieldInternal(LCGPBMessage *self,
                                       LCGPBFieldDescriptor *field,
                                       double value,
                                       LCGPBFileSyntax syntax);
//%PDDM-EXPAND LCGPB_IVAR_SET_DECL(Enum, int32_t)
// This block of code is generated, do not edit it directly.

void LCGPBSetEnumIvarWithFieldInternal(LCGPBMessage *self,
                                     LCGPBFieldDescriptor *field,
                                     int32_t value,
                                     LCGPBFileSyntax syntax);
//%PDDM-EXPAND-END (8 expansions)

int32_t LCGPBGetEnumIvarWithFieldInternal(LCGPBMessage *self,
                                        LCGPBFieldDescriptor *field,
                                        LCGPBFileSyntax syntax);

id LCGPBGetObjectIvarWithField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

void LCGPBSetObjectIvarWithFieldInternal(LCGPBMessage *self,
                                       LCGPBFieldDescriptor *field, id value,
                                       LCGPBFileSyntax syntax);
void LCGPBSetRetainedObjectIvarWithFieldInternal(LCGPBMessage *self,
                                               LCGPBFieldDescriptor *field,
                                               id __attribute__((ns_consumed))
                                               value,
                                               LCGPBFileSyntax syntax);

// LCGPBGetObjectIvarWithField will automatically create the field (message) if
// it doesn't exist. LCGPBGetObjectIvarWithFieldNoAutocreate will return nil.
id LCGPBGetObjectIvarWithFieldNoAutocreate(LCGPBMessage *self,
                                         LCGPBFieldDescriptor *field);

void LCGPBSetAutocreatedRetainedObjectIvarWithField(
    LCGPBMessage *self, LCGPBFieldDescriptor *field,
    id __attribute__((ns_consumed)) value);

// Clears and releases the autocreated message ivar, if it's autocreated. If
// it's not set as autocreated, this method does nothing.
void LCGPBClearAutocreatedMessageIvarWithField(LCGPBMessage *self,
                                             LCGPBFieldDescriptor *field);

// Returns an Objective C encoding for |selector|. |instanceSel| should be
// YES if it's an instance selector (as opposed to a class selector).
// |selector| must be a selector from MessageSignatureProtocol.
const char *LCGPBMessageEncodingForSelector(SEL selector, BOOL instanceSel);

// Helper for text format name encoding.
// decodeData is the data describing the sepecial decodes.
// key and inputString are the input that needs decoding.
NSString *LCGPBDecodeTextFormatName(const uint8_t *decodeData, int32_t key,
                                  NSString *inputString);

// A series of selectors that are used solely to get @encoding values
// for them by the dynamic protobuf runtime code. See
// LCGPBMessageEncodingForSelector for details. LCGPBRootObject conforms to
// the protocol so that it is encoded in the Objective C runtime.
@protocol LCGPBMessageSignatureProtocol
@optional

#define LCGPB_MESSAGE_SIGNATURE_ENTRY(TYPE, NAME) \
  -(TYPE)get##NAME;                             \
  -(void)set##NAME : (TYPE)value;               \
  -(TYPE)get##NAME##AtIndex : (NSUInteger)index;

LCGPB_MESSAGE_SIGNATURE_ENTRY(BOOL, Bool)
LCGPB_MESSAGE_SIGNATURE_ENTRY(uint32_t, Fixed32)
LCGPB_MESSAGE_SIGNATURE_ENTRY(int32_t, SFixed32)
LCGPB_MESSAGE_SIGNATURE_ENTRY(float, Float)
LCGPB_MESSAGE_SIGNATURE_ENTRY(uint64_t, Fixed64)
LCGPB_MESSAGE_SIGNATURE_ENTRY(int64_t, SFixed64)
LCGPB_MESSAGE_SIGNATURE_ENTRY(double, Double)
LCGPB_MESSAGE_SIGNATURE_ENTRY(int32_t, Int32)
LCGPB_MESSAGE_SIGNATURE_ENTRY(int64_t, Int64)
LCGPB_MESSAGE_SIGNATURE_ENTRY(int32_t, SInt32)
LCGPB_MESSAGE_SIGNATURE_ENTRY(int64_t, SInt64)
LCGPB_MESSAGE_SIGNATURE_ENTRY(uint32_t, UInt32)
LCGPB_MESSAGE_SIGNATURE_ENTRY(uint64_t, UInt64)
LCGPB_MESSAGE_SIGNATURE_ENTRY(NSData *, Bytes)
LCGPB_MESSAGE_SIGNATURE_ENTRY(NSString *, String)
LCGPB_MESSAGE_SIGNATURE_ENTRY(LCGPBMessage *, Message)
LCGPB_MESSAGE_SIGNATURE_ENTRY(LCGPBMessage *, Group)
LCGPB_MESSAGE_SIGNATURE_ENTRY(int32_t, Enum)

#undef LCGPB_MESSAGE_SIGNATURE_ENTRY

- (id)getArray;
- (NSUInteger)getArrayCount;
- (void)setArray:(NSArray *)array;
+ (id)getClassValue;
@end

BOOL LCGPBClassHasSel(Class aClass, SEL sel);

CF_EXTERN_C_END
