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

#import "LCGPBBootstrap.h"

#import "LCGPBArray.h"
#import "LCGPBCodedInputStream.h"
#import "LCGPBCodedOutputStream.h"
#import "LCGPBDescriptor.h"
#import "LCGPBDictionary.h"
#import "LCGPBExtensionRegistry.h"
#import "LCGPBMessage.h"
#import "LCGPBRootObject.h"
#import "LCGPBUnknownField.h"
#import "LCGPBUnknownFieldSet.h"
#import "LCGPBUtilities.h"
#import "LCGPBWellKnownTypes.h"
#import "LCGPBWireFormat.h"

// This CPP symbol can be defined to use imports that match up to the framework
// imports needed when using CocoaPods.
#if !defined(LCGPB_USE_PROTOBUF_FRAMEWORK_IMPORTS)
 #define LCGPB_USE_PROTOBUF_FRAMEWORK_IMPORTS 0
#endif

// Well-known proto types
#if LCGPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
 #import <protobuf/Any.pbobjc.h>
 #import <protobuf/Api.pbobjc.h>
 #import <protobuf/Duration.pbobjc.h>
 #import <protobuf/Empty.pbobjc.h>
 #import <protobuf/FieldMask.pbobjc.h>
 #import <protobuf/SourceContext.pbobjc.h>
 #import <protobuf/Struct.pbobjc.h>
 #import <protobuf/Timestamp.pbobjc.h>
 #import <protobuf/Type.pbobjc.h>
 #import <protobuf/Wrappers.pbobjc.h>
#else
 #import "LCGPBAny.pbobjc.h"
 #import "LCGPBApi.pbobjc.h"
 #import "LCGPBDuration.pbobjc.h"
 #import "LCGPBEmpty.pbobjc.h"
 #import "LCGPBFieldMask.pbobjc.h"
 #import "LCGPBSourceContext.pbobjc.h"
 #import "LCGPBStruct.pbobjc.h"
 #import "LCGPBTimestamp.pbobjc.h"
 #import "LCGPBType.pbobjc.h"
 #import "LCGPBWrappers.pbobjc.h"
#endif
