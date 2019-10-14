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

#import "LCGPBArray.h"
#import "LCGPBMessage.h"
#import "LCGPBRuntimeTypes.h"

CF_EXTERN_C_BEGIN

NS_ASSUME_NONNULL_BEGIN

/**
 * Generates a string that should be a valid "TextFormat" for the C++ version
 * of Protocol Buffers.
 *
 * @param message    The message to generate from.
 * @param lineIndent A string to use as the prefix for all lines generated. Can
 *                   be nil if no extra indent is needed.
 *
 * @return An NSString with the TextFormat of the message.
 **/
NSString *LCGPBTextFormatForMessage(LCGPBMessage *message,
                                  NSString * __nullable lineIndent);

/**
 * Generates a string that should be a valid "TextFormat" for the C++ version
 * of Protocol Buffers.
 *
 * @param unknownSet The unknown field set to generate from.
 * @param lineIndent A string to use as the prefix for all lines generated. Can
 *                   be nil if no extra indent is needed.
 *
 * @return An NSString with the TextFormat of the unknown field set.
 **/
NSString *LCGPBTextFormatForUnknownFieldSet(LCGPBUnknownFieldSet * __nullable unknownSet,
                                          NSString * __nullable lineIndent);

/**
 * Checks if the given field number is set on a message.
 *
 * @param self        The message to check.
 * @param fieldNumber The field number to check.
 *
 * @return YES if the field number is set on the given message.
 **/
BOOL LCGPBMessageHasFieldNumberSet(LCGPBMessage *self, uint32_t fieldNumber);

/**
 * Checks if the given field is set on a message.
 *
 * @param self  The message to check.
 * @param field The field to check.
 *
 * @return YES if the field is set on the given message.
 **/
BOOL LCGPBMessageHasFieldSet(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Clears the given field for the given message.
 *
 * @param self  The message for which to clear the field.
 * @param field The field to clear.
 **/
void LCGPBClearMessageField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

//%PDDM-EXPAND LCGPB_ACCESSORS()
// This block of code is generated, do not edit it directly.


//
// Get/Set a given field from/to a message.
//

// Single Fields

/**
 * Gets the value of a bytes field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
NSData *LCGPBGetMessageBytesField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a bytes field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageBytesField(LCGPBMessage *self, LCGPBFieldDescriptor *field, NSData *value);

/**
 * Gets the value of a string field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
NSString *LCGPBGetMessageStringField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a string field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageStringField(LCGPBMessage *self, LCGPBFieldDescriptor *field, NSString *value);

/**
 * Gets the value of a message field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
LCGPBMessage *LCGPBGetMessageMessageField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a message field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageMessageField(LCGPBMessage *self, LCGPBFieldDescriptor *field, LCGPBMessage *value);

/**
 * Gets the value of a group field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
LCGPBMessage *LCGPBGetMessageGroupField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a group field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageGroupField(LCGPBMessage *self, LCGPBFieldDescriptor *field, LCGPBMessage *value);

/**
 * Gets the value of a bool field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
BOOL LCGPBGetMessageBoolField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a bool field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageBoolField(LCGPBMessage *self, LCGPBFieldDescriptor *field, BOOL value);

/**
 * Gets the value of an int32 field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
int32_t LCGPBGetMessageInt32Field(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of an int32 field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageInt32Field(LCGPBMessage *self, LCGPBFieldDescriptor *field, int32_t value);

/**
 * Gets the value of an uint32 field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
uint32_t LCGPBGetMessageUInt32Field(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of an uint32 field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageUInt32Field(LCGPBMessage *self, LCGPBFieldDescriptor *field, uint32_t value);

/**
 * Gets the value of an int64 field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
int64_t LCGPBGetMessageInt64Field(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of an int64 field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageInt64Field(LCGPBMessage *self, LCGPBFieldDescriptor *field, int64_t value);

/**
 * Gets the value of an uint64 field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
uint64_t LCGPBGetMessageUInt64Field(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of an uint64 field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageUInt64Field(LCGPBMessage *self, LCGPBFieldDescriptor *field, uint64_t value);

/**
 * Gets the value of a float field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
float LCGPBGetMessageFloatField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a float field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageFloatField(LCGPBMessage *self, LCGPBFieldDescriptor *field, float value);

/**
 * Gets the value of a double field.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 **/
double LCGPBGetMessageDoubleField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a double field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The to set in the field.
 **/
void LCGPBSetMessageDoubleField(LCGPBMessage *self, LCGPBFieldDescriptor *field, double value);

/**
 * Gets the given enum field of a message. For proto3, if the value isn't a
 * member of the enum, @c kLCGPBUnrecognizedEnumeratorValue will be returned.
 * LCGPBGetMessageRawEnumField will bypass the check and return whatever value
 * was set.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 *
 * @return The enum value for the given field.
 **/
int32_t LCGPBGetMessageEnumField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Set the given enum field of a message. You can only set values that are
 * members of the enum.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The enum value to set in the field.
 **/
void LCGPBSetMessageEnumField(LCGPBMessage *self,
                            LCGPBFieldDescriptor *field,
                            int32_t value);

/**
 * Get the given enum field of a message. No check is done to ensure the value
 * was defined in the enum.
 *
 * @param self  The message from which to get the field.
 * @param field The field to get.
 *
 * @return The raw enum value for the given field.
 **/
int32_t LCGPBGetMessageRawEnumField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Set the given enum field of a message. You can set the value to anything,
 * even a value that is not a member of the enum.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param value The raw enum value to set in the field.
 **/
void LCGPBSetMessageRawEnumField(LCGPBMessage *self,
                               LCGPBFieldDescriptor *field,
                               int32_t value);

// Repeated Fields

/**
 * Gets the value of a repeated field.
 *
 * @param self  The message from which to get the field.
 * @param field The repeated field to get.
 *
 * @return A LCGPB*Array or an NSMutableArray based on the field's type.
 **/
id LCGPBGetMessageRepeatedField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a repeated field.
 *
 * @param self  The message into which to set the field.
 * @param field The field to set.
 * @param array A LCGPB*Array or NSMutableArray based on the field's type.
 **/
void LCGPBSetMessageRepeatedField(LCGPBMessage *self,
                                LCGPBFieldDescriptor *field,
                                id array);

// Map Fields

/**
 * Gets the value of a map<> field.
 *
 * @param self  The message from which to get the field.
 * @param field The repeated field to get.
 *
 * @return A LCGPB*Dictionary or NSMutableDictionary based on the field's type.
 **/
id LCGPBGetMessageMapField(LCGPBMessage *self, LCGPBFieldDescriptor *field);

/**
 * Sets the value of a map<> field.
 *
 * @param self       The message into which to set the field.
 * @param field      The field to set.
 * @param dictionary A LCGPB*Dictionary or NSMutableDictionary based on the
 *                   field's type.
 **/
void LCGPBSetMessageMapField(LCGPBMessage *self,
                           LCGPBFieldDescriptor *field,
                           id dictionary);

//%PDDM-EXPAND-END LCGPB_ACCESSORS()

/**
 * Returns an empty NSData to assign to byte fields when you wish to assign them
 * to empty. Prevents allocating a lot of little [NSData data] objects.
 **/
NSData *LCGPBEmptyNSData(void) __attribute__((pure));

/**
 * Drops the `unknownFields` from the given message and from all sub message.
 **/
void LCGPBMessageDropUnknownFieldsRecursively(LCGPBMessage *message);

NS_ASSUME_NONNULL_END

CF_EXTERN_C_END


//%PDDM-DEFINE LCGPB_ACCESSORS()
//%
//%//
//%// Get/Set a given field from/to a message.
//%//
//%
//%// Single Fields
//%
//%LCGPB_ACCESSOR_SINGLE_FULL(Bytes, NSData, , *)
//%LCGPB_ACCESSOR_SINGLE_FULL(String, NSString, , *)
//%LCGPB_ACCESSOR_SINGLE_FULL(Message, LCGPBMessage, , *)
//%LCGPB_ACCESSOR_SINGLE_FULL(Group, LCGPBMessage, , *)
//%LCGPB_ACCESSOR_SINGLE(Bool, BOOL, )
//%LCGPB_ACCESSOR_SINGLE(Int32, int32_t, n)
//%LCGPB_ACCESSOR_SINGLE(UInt32, uint32_t, n)
//%LCGPB_ACCESSOR_SINGLE(Int64, int64_t, n)
//%LCGPB_ACCESSOR_SINGLE(UInt64, uint64_t, n)
//%LCGPB_ACCESSOR_SINGLE(Float, float, )
//%LCGPB_ACCESSOR_SINGLE(Double, double, )
//%/**
//% * Gets the given enum field of a message. For proto3, if the value isn't a
//% * member of the enum, @c kLCGPBUnrecognizedEnumeratorValue will be returned.
//% * LCGPBGetMessageRawEnumField will bypass the check and return whatever value
//% * was set.
//% *
//% * @param self  The message from which to get the field.
//% * @param field The field to get.
//% *
//% * @return The enum value for the given field.
//% **/
//%int32_t LCGPBGetMessageEnumField(LCGPBMessage *self, LCGPBFieldDescriptor *field);
//%
//%/**
//% * Set the given enum field of a message. You can only set values that are
//% * members of the enum.
//% *
//% * @param self  The message into which to set the field.
//% * @param field The field to set.
//% * @param value The enum value to set in the field.
//% **/
//%void LCGPBSetMessageEnumField(LCGPBMessage *self,
//%                            LCGPBFieldDescriptor *field,
//%                            int32_t value);
//%
//%/**
//% * Get the given enum field of a message. No check is done to ensure the value
//% * was defined in the enum.
//% *
//% * @param self  The message from which to get the field.
//% * @param field The field to get.
//% *
//% * @return The raw enum value for the given field.
//% **/
//%int32_t LCGPBGetMessageRawEnumField(LCGPBMessage *self, LCGPBFieldDescriptor *field);
//%
//%/**
//% * Set the given enum field of a message. You can set the value to anything,
//% * even a value that is not a member of the enum.
//% *
//% * @param self  The message into which to set the field.
//% * @param field The field to set.
//% * @param value The raw enum value to set in the field.
//% **/
//%void LCGPBSetMessageRawEnumField(LCGPBMessage *self,
//%                               LCGPBFieldDescriptor *field,
//%                               int32_t value);
//%
//%// Repeated Fields
//%
//%/**
//% * Gets the value of a repeated field.
//% *
//% * @param self  The message from which to get the field.
//% * @param field The repeated field to get.
//% *
//% * @return A LCGPB*Array or an NSMutableArray based on the field's type.
//% **/
//%id LCGPBGetMessageRepeatedField(LCGPBMessage *self, LCGPBFieldDescriptor *field);
//%
//%/**
//% * Sets the value of a repeated field.
//% *
//% * @param self  The message into which to set the field.
//% * @param field The field to set.
//% * @param array A LCGPB*Array or NSMutableArray based on the field's type.
//% **/
//%void LCGPBSetMessageRepeatedField(LCGPBMessage *self,
//%                                LCGPBFieldDescriptor *field,
//%                                id array);
//%
//%// Map Fields
//%
//%/**
//% * Gets the value of a map<> field.
//% *
//% * @param self  The message from which to get the field.
//% * @param field The repeated field to get.
//% *
//% * @return A LCGPB*Dictionary or NSMutableDictionary based on the field's type.
//% **/
//%id LCGPBGetMessageMapField(LCGPBMessage *self, LCGPBFieldDescriptor *field);
//%
//%/**
//% * Sets the value of a map<> field.
//% *
//% * @param self       The message into which to set the field.
//% * @param field      The field to set.
//% * @param dictionary A LCGPB*Dictionary or NSMutableDictionary based on the
//% *                   field's type.
//% **/
//%void LCGPBSetMessageMapField(LCGPBMessage *self,
//%                           LCGPBFieldDescriptor *field,
//%                           id dictionary);
//%

//%PDDM-DEFINE LCGPB_ACCESSOR_SINGLE(NAME, TYPE, AN)
//%LCGPB_ACCESSOR_SINGLE_FULL(NAME, TYPE, AN, )
//%PDDM-DEFINE LCGPB_ACCESSOR_SINGLE_FULL(NAME, TYPE, AN, TisP)
//%/**
//% * Gets the value of a##AN NAME$L field.
//% *
//% * @param self  The message from which to get the field.
//% * @param field The field to get.
//% **/
//%TYPE TisP##LCGPBGetMessage##NAME##Field(LCGPBMessage *self, LCGPBFieldDescriptor *field);
//%
//%/**
//% * Sets the value of a##AN NAME$L field.
//% *
//% * @param self  The message into which to set the field.
//% * @param field The field to set.
//% * @param value The to set in the field.
//% **/
//%void LCGPBSetMessage##NAME##Field(LCGPBMessage *self, LCGPBFieldDescriptor *field, TYPE TisP##value);
//%
