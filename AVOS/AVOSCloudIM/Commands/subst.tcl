#!/usr/bin/env tclsh

array set rules {
    \\yGPBMessage\\y
    LCIMMessage

    GPBRootObject
    LCIMRootObject

    GPBProtocolBuffers
    LCIMProtocolBuffers

    GPBFieldFlags
    LCIMFieldFlags

    GPBFieldOptional
    LCIMFieldOptional

    GPBFieldRequired
    LCIMFieldRequired

    GPBFieldRepeated
    LCIMFieldRepeated

    GPBFieldHasEnumDescriptor
    LCIMFieldHasEnumDescriptor

    GPBFieldHasDefaultValue
    LCIMFieldHasDefaultValue

    GPBFieldTextFormatNameCustom
    LCIMFieldTextFormatNameCustom

    GPBDescriptor
    LCIMDescriptor

    GPBEnumDescriptor
    LCIMEnumDescriptor

    GPBEnumDescriptor
    LCIMEnumDescriptor

    GPBEnumDescriptor
    LCIMEnumDescriptor

    GPBFileDescriptor
    LCIMFileDescriptor

    GPBExtensionRegistry
    LCIMExtensionRegistry

    GPB_DEBUG_CHECK_RUNTIME_VERSIONS
    LCIM_DEBUG_CHECK_RUNTIME_VERSIONS

    GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
    LCIM_USE_PROTOBUF_FRAMEWORK_IMPORTS
}

proc gsubfile {path rules} {
    set file [open $path]
    set content [read $file]

    upvar 1 $rules arr

    foreach {pattern substitution} [array get arr] {
        regsub -all $pattern $content $substitution content
    }

    set file [open $path w]
    puts -nonewline $file $content
}

gsubfile MessagesProtoOrig.pbobjc.h rules
gsubfile MessagesProtoOrig.pbobjc.m rules
