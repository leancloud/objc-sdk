//
//  AVIMGeneralObject.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/15/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMGeneralObject.h"

@implementation AVIMGeneralObject

LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (width,     setWidth, uint)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (height,    setHeight, uint)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (size,      setSize, uint64_t)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (duration,  setDuration, float)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (name,      setName)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (format,    setFormat)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (url,       setUrl)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (objId,     setObjId)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (longitude, setLongitude, float)
LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (latitude,  setLatitude, float)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT         (metaData, setMetaData)
LC_FORWARD_PROPERTY_ACCESSOR_OBJECT         (location, setLocation)

@end
