// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: google/protobuf/type.proto

// This CPP symbol can be defined to use imports that match up to the framework
// imports needed when using CocoaPods.
#if !defined(LCIM_USE_PROTOBUF_FRAMEWORK_IMPORTS)
 #define LCIM_USE_PROTOBUF_FRAMEWORK_IMPORTS 0
#endif

#if LCIM_USE_PROTOBUF_FRAMEWORK_IMPORTS
 #import <Protobuf/LCIMProtocolBuffers_RuntimeSupport.h>
#else
 #import "LCIMProtocolBuffers_RuntimeSupport.h"
#endif

#if LCIM_USE_PROTOBUF_FRAMEWORK_IMPORTS
 #import <Protobuf/LCIMType.pbobjc.h>
 #import <Protobuf/LCIMAny.pbobjc.h>
 #import <Protobuf/LCIMSourceContext.pbobjc.h>
#else
 #import "google/protobuf/LCIMType.pbobjc.h"
 #import "google/protobuf/LCIMAny.pbobjc.h"
 #import "google/protobuf/LCIMSourceContext.pbobjc.h"
#endif
// @@protoc_insertion_point(imports)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - GPBTypeRoot

@implementation LCIMTypeRoot

// No extensions in the file and none of the imports (direct or indirect)
// defined extensions, so no need to generate +extensionRegistry.

@end

#pragma mark - GPBTypeRoot_FileDescriptor

static LCIMFileDescriptor *LCIMTypeRoot_FileDescriptor(void) {
  // This is called by +initialize so there is no need to worry
  // about thread safety of the singleton.
  static LCIMFileDescriptor *descriptor = NULL;
  if (!descriptor) {
    LCIM_DEBUG_CHECK_RUNTIME_VERSIONS();
    descriptor = [[LCIMFileDescriptor alloc] initWithPackage:@"google.protobuf"
                                                     syntax:GPBFileSyntaxProto3];
  }
  return descriptor;
}

#pragma mark - Enum GPBSyntax

LCIMEnumDescriptor *LCIMSyntax_EnumDescriptor(void) {
  static LCIMEnumDescriptor *descriptor = NULL;
  if (!descriptor) {
    static const char *valueNames =
        "SyntaxProto2\000SyntaxProto3\000";
    static const int32_t values[] = {
        GPBSyntax_SyntaxProto2,
        GPBSyntax_SyntaxProto3,
    };
    LCIMEnumDescriptor *worker =
        [LCIMEnumDescriptor allocDescriptorForName:GPBNSStringifySymbol(GPBSyntax)
                                       valueNames:valueNames
                                           values:values
                                            count:(uint32_t)(sizeof(values) / sizeof(int32_t))
                                     enumVerifier:LCIMSyntax_IsValidValue];
    if (!OSAtomicCompareAndSwapPtrBarrier(nil, worker, (void * volatile *)&descriptor)) {
      [worker release];
    }
  }
  return descriptor;
}

BOOL LCIMSyntax_IsValidValue(int32_t value__) {
  switch (value__) {
    case GPBSyntax_SyntaxProto2:
    case GPBSyntax_SyntaxProto3:
      return YES;
    default:
      return NO;
  }
}

#pragma mark - GPBType

@implementation LCIMType

@dynamic name;
@dynamic fieldsArray, fieldsArray_Count;
@dynamic oneofsArray, oneofsArray_Count;
@dynamic optionsArray, optionsArray_Count;
@dynamic hasSourceContext, sourceContext;
@dynamic syntax;

typedef struct GPBType__storage_ {
  uint32_t _has_storage_[1];
  GPBSyntax syntax;
  __unsafe_unretained NSString *name;
  __unsafe_unretained NSMutableArray *fieldsArray;
  __unsafe_unretained NSMutableArray *oneofsArray;
  __unsafe_unretained NSMutableArray *optionsArray;
  __unsafe_unretained LCIMSourceContext *sourceContext;
} GPBType__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCIMDescriptor *)descriptor {
  static LCIMDescriptor *descriptor = nil;
  if (!descriptor) {
    static GPBMessageFieldDescription fields[] = {
      {
        .name = "name",
        .dataTypeSpecific.className = NULL,
        .number = GPBType_FieldNumber_Name,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(GPBType__storage_, name),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeString,
      },
      {
        .name = "fieldsArray",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMField),
        .number = GPBType_FieldNumber_FieldsArray,
        .hasIndex = GPBNoHasBit,
        .offset = (uint32_t)offsetof(GPBType__storage_, fieldsArray),
        .flags = LCIMFieldRepeated,
        .dataType = GPBDataTypeMessage,
      },
      {
        .name = "oneofsArray",
        .dataTypeSpecific.className = NULL,
        .number = GPBType_FieldNumber_OneofsArray,
        .hasIndex = GPBNoHasBit,
        .offset = (uint32_t)offsetof(GPBType__storage_, oneofsArray),
        .flags = LCIMFieldRepeated,
        .dataType = GPBDataTypeString,
      },
      {
        .name = "optionsArray",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMOption),
        .number = GPBType_FieldNumber_OptionsArray,
        .hasIndex = GPBNoHasBit,
        .offset = (uint32_t)offsetof(GPBType__storage_, optionsArray),
        .flags = LCIMFieldRepeated,
        .dataType = GPBDataTypeMessage,
      },
      {
        .name = "sourceContext",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMSourceContext),
        .number = GPBType_FieldNumber_SourceContext,
        .hasIndex = 1,
        .offset = (uint32_t)offsetof(GPBType__storage_, sourceContext),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeMessage,
      },
      {
        .name = "syntax",
        .dataTypeSpecific.enumDescFunc = LCIMSyntax_EnumDescriptor,
        .number = GPBType_FieldNumber_Syntax,
        .hasIndex = 2,
        .offset = (uint32_t)offsetof(GPBType__storage_, syntax),
        .flags = LCIMFieldOptional | LCIMFieldHasEnumDescriptor,
        .dataType = GPBDataTypeEnum,
      },
    };
    LCIMDescriptor *localDescriptor =
        [LCIMDescriptor allocDescriptorForClass:[LCIMType class]
                                     rootClass:[LCIMTypeRoot class]
                                          file:LCIMTypeRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(GPBMessageFieldDescription))
                                   storageSize:sizeof(GPBType__storage_)
                                         flags:0];
    NSAssert(descriptor == nil, @"Startup recursed!");
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

int32_t LCIMType_Syntax_RawValue(LCIMType *message) {
  LCIMDescriptor *descriptor = [LCIMType descriptor];
  LCIMFieldDescriptor *field = [descriptor fieldWithNumber:GPBType_FieldNumber_Syntax];
  return LCIMGetMessageInt32Field(message, field);
}

void SetLCIMType_Syntax_RawValue(LCIMType *message, int32_t value) {
  LCIMDescriptor *descriptor = [LCIMType descriptor];
  LCIMFieldDescriptor *field = [descriptor fieldWithNumber:GPBType_FieldNumber_Syntax];
  LCIMSetInt32IvarWithFieldInternal(message, field, value, descriptor.file.syntax);
}

#pragma mark - GPBField

@implementation LCIMField

@dynamic kind;
@dynamic cardinality;
@dynamic number;
@dynamic name;
@dynamic typeURL;
@dynamic oneofIndex;
@dynamic packed;
@dynamic optionsArray, optionsArray_Count;
@dynamic jsonName;
@dynamic defaultValue;

typedef struct LCIMField__storage_ {
  uint32_t _has_storage_[1];
  GPBField_Kind kind;
  GPBField_Cardinality cardinality;
  int32_t number;
  int32_t oneofIndex;
  __unsafe_unretained NSString *name;
  __unsafe_unretained NSString *typeURL;
  __unsafe_unretained NSMutableArray *optionsArray;
  __unsafe_unretained NSString *jsonName;
  __unsafe_unretained NSString *defaultValue;
} LCIMField__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCIMDescriptor *)descriptor {
  static LCIMDescriptor *descriptor = nil;
  if (!descriptor) {
    static GPBMessageFieldDescription fields[] = {
      {
        .name = "kind",
        .dataTypeSpecific.enumDescFunc = LCIMField_Kind_EnumDescriptor,
        .number = GPBField_FieldNumber_Kind,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCIMField__storage_, kind),
        .flags = LCIMFieldOptional | LCIMFieldHasEnumDescriptor,
        .dataType = GPBDataTypeEnum,
      },
      {
        .name = "cardinality",
        .dataTypeSpecific.enumDescFunc = LCIMField_Cardinality_EnumDescriptor,
        .number = GPBField_FieldNumber_Cardinality,
        .hasIndex = 1,
        .offset = (uint32_t)offsetof(LCIMField__storage_, cardinality),
        .flags = LCIMFieldOptional | LCIMFieldHasEnumDescriptor,
        .dataType = GPBDataTypeEnum,
      },
      {
        .name = "number",
        .dataTypeSpecific.className = NULL,
        .number = GPBField_FieldNumber_Number,
        .hasIndex = 2,
        .offset = (uint32_t)offsetof(LCIMField__storage_, number),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeInt32,
      },
      {
        .name = "name",
        .dataTypeSpecific.className = NULL,
        .number = GPBField_FieldNumber_Name,
        .hasIndex = 3,
        .offset = (uint32_t)offsetof(LCIMField__storage_, name),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeString,
      },
      {
        .name = "typeURL",
        .dataTypeSpecific.className = NULL,
        .number = GPBField_FieldNumber_TypeURL,
        .hasIndex = 4,
        .offset = (uint32_t)offsetof(LCIMField__storage_, typeURL),
        .flags = LCIMFieldOptional | LCIMFieldTextFormatNameCustom,
        .dataType = GPBDataTypeString,
      },
      {
        .name = "oneofIndex",
        .dataTypeSpecific.className = NULL,
        .number = GPBField_FieldNumber_OneofIndex,
        .hasIndex = 5,
        .offset = (uint32_t)offsetof(LCIMField__storage_, oneofIndex),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeInt32,
      },
      {
        .name = "packed",
        .dataTypeSpecific.className = NULL,
        .number = GPBField_FieldNumber_Packed,
        .hasIndex = 6,
        .offset = 7,  // Stored in _has_storage_ to save space.
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeBool,
      },
      {
        .name = "optionsArray",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMOption),
        .number = GPBField_FieldNumber_OptionsArray,
        .hasIndex = GPBNoHasBit,
        .offset = (uint32_t)offsetof(LCIMField__storage_, optionsArray),
        .flags = LCIMFieldRepeated,
        .dataType = GPBDataTypeMessage,
      },
      {
        .name = "jsonName",
        .dataTypeSpecific.className = NULL,
        .number = GPBField_FieldNumber_JsonName,
        .hasIndex = 8,
        .offset = (uint32_t)offsetof(LCIMField__storage_, jsonName),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeString,
      },
      {
        .name = "defaultValue",
        .dataTypeSpecific.className = NULL,
        .number = GPBField_FieldNumber_DefaultValue,
        .hasIndex = 9,
        .offset = (uint32_t)offsetof(LCIMField__storage_, defaultValue),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeString,
      },
    };
    LCIMDescriptor *localDescriptor =
        [LCIMDescriptor allocDescriptorForClass:[LCIMField class]
                                     rootClass:[LCIMTypeRoot class]
                                          file:LCIMTypeRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(GPBMessageFieldDescription))
                                   storageSize:sizeof(LCIMField__storage_)
                                         flags:0];
#if !GPBOBJC_SKIP_MESSAGE_TEXTFORMAT_EXTRAS
    static const char *extraTextFormatInfo =
        "\001\006\004\241!!\000";
    [localDescriptor setupExtraTextInfo:extraTextFormatInfo];
#endif  // !GPBOBJC_SKIP_MESSAGE_TEXTFORMAT_EXTRAS
    NSAssert(descriptor == nil, @"Startup recursed!");
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

int32_t LCIMField_Kind_RawValue(LCIMField *message) {
  LCIMDescriptor *descriptor = [LCIMField descriptor];
  LCIMFieldDescriptor *field = [descriptor fieldWithNumber:GPBField_FieldNumber_Kind];
  return LCIMGetMessageInt32Field(message, field);
}

void SetLCIMField_Kind_RawValue(LCIMField *message, int32_t value) {
  LCIMDescriptor *descriptor = [LCIMField descriptor];
  LCIMFieldDescriptor *field = [descriptor fieldWithNumber:GPBField_FieldNumber_Kind];
  LCIMSetInt32IvarWithFieldInternal(message, field, value, descriptor.file.syntax);
}

int32_t LCIMField_Cardinality_RawValue(LCIMField *message) {
  LCIMDescriptor *descriptor = [LCIMField descriptor];
  LCIMFieldDescriptor *field = [descriptor fieldWithNumber:GPBField_FieldNumber_Cardinality];
  return LCIMGetMessageInt32Field(message, field);
}

void SetLCIMField_Cardinality_RawValue(LCIMField *message, int32_t value) {
  LCIMDescriptor *descriptor = [LCIMField descriptor];
  LCIMFieldDescriptor *field = [descriptor fieldWithNumber:GPBField_FieldNumber_Cardinality];
  LCIMSetInt32IvarWithFieldInternal(message, field, value, descriptor.file.syntax);
}

#pragma mark - Enum GPBField_Kind

LCIMEnumDescriptor *LCIMField_Kind_EnumDescriptor(void) {
  static LCIMEnumDescriptor *descriptor = NULL;
  if (!descriptor) {
    static const char *valueNames =
        "TypeUnknown\000TypeDouble\000TypeFloat\000TypeInt"
        "64\000TypeUint64\000TypeInt32\000TypeFixed64\000Type"
        "Fixed32\000TypeBool\000TypeString\000TypeGroup\000Ty"
        "peMessage\000TypeBytes\000TypeUint32\000TypeEnum\000"
        "TypeSfixed32\000TypeSfixed64\000TypeSint32\000Typ"
        "eSint64\000";
    static const int32_t values[] = {
        GPBField_Kind_TypeUnknown,
        GPBField_Kind_TypeDouble,
        GPBField_Kind_TypeFloat,
        GPBField_Kind_TypeInt64,
        GPBField_Kind_TypeUint64,
        GPBField_Kind_TypeInt32,
        GPBField_Kind_TypeFixed64,
        GPBField_Kind_TypeFixed32,
        GPBField_Kind_TypeBool,
        GPBField_Kind_TypeString,
        GPBField_Kind_TypeGroup,
        GPBField_Kind_TypeMessage,
        GPBField_Kind_TypeBytes,
        GPBField_Kind_TypeUint32,
        GPBField_Kind_TypeEnum,
        GPBField_Kind_TypeSfixed32,
        GPBField_Kind_TypeSfixed64,
        GPBField_Kind_TypeSint32,
        GPBField_Kind_TypeSint64,
    };
    LCIMEnumDescriptor *worker =
        [LCIMEnumDescriptor allocDescriptorForName:GPBNSStringifySymbol(LCIMField_Kind)
                                       valueNames:valueNames
                                           values:values
                                            count:(uint32_t)(sizeof(values) / sizeof(int32_t))
                                     enumVerifier:LCIMField_Kind_IsValidValue];
    if (!OSAtomicCompareAndSwapPtrBarrier(nil, worker, (void * volatile *)&descriptor)) {
      [worker release];
    }
  }
  return descriptor;
}

BOOL LCIMField_Kind_IsValidValue(int32_t value__) {
  switch (value__) {
    case GPBField_Kind_TypeUnknown:
    case GPBField_Kind_TypeDouble:
    case GPBField_Kind_TypeFloat:
    case GPBField_Kind_TypeInt64:
    case GPBField_Kind_TypeUint64:
    case GPBField_Kind_TypeInt32:
    case GPBField_Kind_TypeFixed64:
    case GPBField_Kind_TypeFixed32:
    case GPBField_Kind_TypeBool:
    case GPBField_Kind_TypeString:
    case GPBField_Kind_TypeGroup:
    case GPBField_Kind_TypeMessage:
    case GPBField_Kind_TypeBytes:
    case GPBField_Kind_TypeUint32:
    case GPBField_Kind_TypeEnum:
    case GPBField_Kind_TypeSfixed32:
    case GPBField_Kind_TypeSfixed64:
    case GPBField_Kind_TypeSint32:
    case GPBField_Kind_TypeSint64:
      return YES;
    default:
      return NO;
  }
}

#pragma mark - Enum GPBField_Cardinality

LCIMEnumDescriptor *LCIMField_Cardinality_EnumDescriptor(void) {
  static LCIMEnumDescriptor *descriptor = NULL;
  if (!descriptor) {
    static const char *valueNames =
        "CardinalityUnknown\000CardinalityOptional\000C"
        "ardinalityRequired\000CardinalityRepeated\000";
    static const int32_t values[] = {
        GPBField_Cardinality_CardinalityUnknown,
        GPBField_Cardinality_CardinalityOptional,
        GPBField_Cardinality_CardinalityRequired,
        GPBField_Cardinality_CardinalityRepeated,
    };
    LCIMEnumDescriptor *worker =
        [LCIMEnumDescriptor allocDescriptorForName:GPBNSStringifySymbol(LCIMField_Cardinality)
                                       valueNames:valueNames
                                           values:values
                                            count:(uint32_t)(sizeof(values) / sizeof(int32_t))
                                     enumVerifier:LCIMField_Cardinality_IsValidValue];

      if (!OSAtomicCompareAndSwapPtrBarrier(nil, worker, (void * volatile *)&descriptor)) {
          [worker release];
      }
  }
  return descriptor;
}

BOOL LCIMField_Cardinality_IsValidValue(int32_t value__) {
  switch (value__) {
    case GPBField_Cardinality_CardinalityUnknown:
    case GPBField_Cardinality_CardinalityOptional:
    case GPBField_Cardinality_CardinalityRequired:
    case GPBField_Cardinality_CardinalityRepeated:
      return YES;
    default:
      return NO;
  }
}

#pragma mark - GPBEnum

@implementation LCIMEnum

@dynamic name;
@dynamic enumvalueArray, enumvalueArray_Count;
@dynamic optionsArray, optionsArray_Count;
@dynamic hasSourceContext, sourceContext;
@dynamic syntax;

typedef struct LCIMEnum__storage_ {
  uint32_t _has_storage_[1];
  GPBSyntax syntax;
  __unsafe_unretained NSString *name;
  __unsafe_unretained NSMutableArray *enumvalueArray;
  __unsafe_unretained NSMutableArray *optionsArray;
  __unsafe_unretained LCIMSourceContext *sourceContext;
} LCIMEnum__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCIMDescriptor *)descriptor {
  static LCIMDescriptor *descriptor = nil;
  if (!descriptor) {
    static GPBMessageFieldDescription fields[] = {
      {
        .name = "name",
        .dataTypeSpecific.className = NULL,
        .number = GPBEnum_FieldNumber_Name,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCIMEnum__storage_, name),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeString,
      },
      {
        .name = "enumvalueArray",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMEnumValue),
        .number = GPBEnum_FieldNumber_EnumvalueArray,
        .hasIndex = GPBNoHasBit,
        .offset = (uint32_t)offsetof(LCIMEnum__storage_, enumvalueArray),
        .flags = LCIMFieldRepeated,
        .dataType = GPBDataTypeMessage,
      },
      {
        .name = "optionsArray",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMOption),
        .number = GPBEnum_FieldNumber_OptionsArray,
        .hasIndex = GPBNoHasBit,
        .offset = (uint32_t)offsetof(LCIMEnum__storage_, optionsArray),
        .flags = LCIMFieldRepeated,
        .dataType = GPBDataTypeMessage,
      },
      {
        .name = "sourceContext",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMSourceContext),
        .number = GPBEnum_FieldNumber_SourceContext,
        .hasIndex = 1,
        .offset = (uint32_t)offsetof(LCIMEnum__storage_, sourceContext),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeMessage,
      },
      {
        .name = "syntax",
        .dataTypeSpecific.enumDescFunc = LCIMSyntax_EnumDescriptor,
        .number = GPBEnum_FieldNumber_Syntax,
        .hasIndex = 2,
        .offset = (uint32_t)offsetof(LCIMEnum__storage_, syntax),
        .flags = LCIMFieldOptional | LCIMFieldHasEnumDescriptor,
        .dataType = GPBDataTypeEnum,
      },
    };
    LCIMDescriptor *localDescriptor =
        [LCIMDescriptor allocDescriptorForClass:[LCIMEnum class]
                                     rootClass:[LCIMTypeRoot class]
                                          file:LCIMTypeRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(GPBMessageFieldDescription))
                                   storageSize:sizeof(LCIMEnum__storage_)
                                         flags:0];
    NSAssert(descriptor == nil, @"Startup recursed!");
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

int32_t LCIMEnum_Syntax_RawValue(LCIMEnum *message) {
  LCIMDescriptor *descriptor = [LCIMEnum descriptor];
  LCIMFieldDescriptor *field = [descriptor fieldWithNumber:GPBEnum_FieldNumber_Syntax];
  return LCIMGetMessageInt32Field(message, field);
}

void SetLCIMEnum_Syntax_RawValue(LCIMEnum *message, int32_t value) {
  LCIMDescriptor *descriptor = [LCIMEnum descriptor];
  LCIMFieldDescriptor *field = [descriptor fieldWithNumber:GPBEnum_FieldNumber_Syntax];
  LCIMSetInt32IvarWithFieldInternal(message, field, value, descriptor.file.syntax);
}

#pragma mark - GPBEnumValue

@implementation LCIMEnumValue

@dynamic name;
@dynamic number;
@dynamic optionsArray, optionsArray_Count;

typedef struct LCIMEnumValue__storage_ {
  uint32_t _has_storage_[1];
  int32_t number;
  __unsafe_unretained NSString *name;
  __unsafe_unretained NSMutableArray *optionsArray;
} LCIMEnumValue__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCIMDescriptor *)descriptor {
  static LCIMDescriptor *descriptor = nil;
  if (!descriptor) {
    static GPBMessageFieldDescription fields[] = {
      {
        .name = "name",
        .dataTypeSpecific.className = NULL,
        .number = GPBEnumValue_FieldNumber_Name,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCIMEnumValue__storage_, name),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeString,
      },
      {
        .name = "number",
        .dataTypeSpecific.className = NULL,
        .number = GPBEnumValue_FieldNumber_Number,
        .hasIndex = 1,
        .offset = (uint32_t)offsetof(LCIMEnumValue__storage_, number),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeInt32,
      },
      {
        .name = "optionsArray",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMOption),
        .number = GPBEnumValue_FieldNumber_OptionsArray,
        .hasIndex = GPBNoHasBit,
        .offset = (uint32_t)offsetof(LCIMEnumValue__storage_, optionsArray),
        .flags = LCIMFieldRepeated,
        .dataType = GPBDataTypeMessage,
      },
    };
    LCIMDescriptor *localDescriptor =
        [LCIMDescriptor allocDescriptorForClass:[LCIMEnumValue class]
                                     rootClass:[LCIMTypeRoot class]
                                          file:LCIMTypeRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(GPBMessageFieldDescription))
                                   storageSize:sizeof(LCIMEnumValue__storage_)
                                         flags:0];
    NSAssert(descriptor == nil, @"Startup recursed!");
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end

#pragma mark - GPBOption

@implementation LCIMOption

@dynamic name;
@dynamic hasValue, value;

typedef struct LCIMOption__storage_ {
  uint32_t _has_storage_[1];
  __unsafe_unretained NSString *name;
  __unsafe_unretained LCIMAny *value;
} LCIMOption__storage_;

// This method is threadsafe because it is initially called
// in +initialize for each subclass.
+ (LCIMDescriptor *)descriptor {
  static LCIMDescriptor *descriptor = nil;
  if (!descriptor) {
    static GPBMessageFieldDescription fields[] = {
      {
        .name = "name",
        .dataTypeSpecific.className = NULL,
        .number = GPBOption_FieldNumber_Name,
        .hasIndex = 0,
        .offset = (uint32_t)offsetof(LCIMOption__storage_, name),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeString,
      },
      {
        .name = "value",
        .dataTypeSpecific.className = GPBStringifySymbol(LCIMAny),
        .number = GPBOption_FieldNumber_Value,
        .hasIndex = 1,
        .offset = (uint32_t)offsetof(LCIMOption__storage_, value),
        .flags = LCIMFieldOptional,
        .dataType = GPBDataTypeMessage,
      },
    };
    LCIMDescriptor *localDescriptor =
        [LCIMDescriptor allocDescriptorForClass:[LCIMOption class]
                                     rootClass:[LCIMTypeRoot class]
                                          file:LCIMTypeRoot_FileDescriptor()
                                        fields:fields
                                    fieldCount:(uint32_t)(sizeof(fields) / sizeof(GPBMessageFieldDescription))
                                   storageSize:sizeof(LCIMOption__storage_)
                                         flags:0];
    NSAssert(descriptor == nil, @"Startup recursed!");
    descriptor = localDescriptor;
  }
  return descriptor;
}

@end


#pragma clang diagnostic pop

// @@protoc_insertion_point(global_scope)
