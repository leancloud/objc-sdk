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

// If you want to build protocol buffers in your own project without adding the
// project dependency, you can just add this file.


// This warning seems to treat code differently when it is #imported than when
// it is inline in the file.  GPBDictionary.m compiles cleanly in other targets,
// but when #imported here it triggers a bunch of warnings that don't make
// much sense, and don't trigger when compiled directly.  So we shut off the
// warnings here.
#pragma clang diagnostic ignored "-Wnullability-completeness"

#import "LCIMArray.m"
#import "LCIMCodedInputStream.m"
#import "LCIMCodedOutputStream.m"
#import "LCIMDescriptor.m"
#import "LCIMDictionary.m"
#import "LCIMExtensionInternals.m"
#import "LCIMExtensionRegistry.m"
#import "LCIMMessage.m"
#import "LCIMRootObject.m"
#import "LCIMUnknownField.m"
#import "LCIMUnknownFieldSet.m"
#import "LCIMUtilities.m"
#import "LCIMWellKnownTypes.m"
#import "LCIMWireFormat.m"

#import "google/protobuf/LCIMAny.pbobjc.m"
#import "google/protobuf/LCIMApi.pbobjc.m"
#import "google/protobuf/LCIMDuration.pbobjc.m"
#import "google/protobuf/LCIMEmpty.pbobjc.m"
#import "google/protobuf/LCIMFieldMask.pbobjc.m"
#import "google/protobuf/LCIMSourceContext.pbobjc.m"
#import "google/protobuf/LCIMStruct.pbobjc.m"
#import "google/protobuf/LCIMTimestamp.pbobjc.m"
#import "google/protobuf/LCIMType.pbobjc.m"
#import "google/protobuf/LCIMWrappers.pbobjc.m"
