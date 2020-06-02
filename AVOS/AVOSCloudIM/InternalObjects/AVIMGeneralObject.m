//
//  AVIMGeneralObject.m
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/15/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVIMGeneralObject.h"
#import "AVUtils.h"

@implementation AVIMGeneralObject

//LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (width,     setWidth, uint)
//LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (height,    setHeight, uint)
//LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (size,      setSize, uint64_t)
//LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (duration,  setDuration, float)
//LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (name,      setName)
//LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (format,    setFormat)
//LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (url,       setUrl)
//LC_FORWARD_PROPERTY_ACCESSOR_OBJECT_COPY    (objId,     setObjId)
//LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (longitude, setLongitude, float)
//LC_FORWARD_PROPERTY_ACCESSOR_NUMBER         (latitude,  setLatitude, float)
//LC_FORWARD_PROPERTY_ACCESSOR_OBJECT         (metaData, setMetaData)
//LC_FORWARD_PROPERTY_ACCESSOR_OBJECT         (location, setLocation)

// MARK: NSNumber

- (double)width {
    return [NSNumber _lc_decoding:self.localData key:@"width"].doubleValue;
}

- (void)setWidth:(double)width {
    [self setObject:@(width) forKey:@"width"];
}

- (double)height {
    return [NSNumber _lc_decoding:self.localData key:@"height"].doubleValue;
}

- (void)setHeight:(double)height {
    [self setObject:@(height) forKey:@"height"];
}

- (double)size {
    return [NSNumber _lc_decoding:self.localData key:@"size"].doubleValue;
}

- (void)setSize:(double)size {
    [self setObject:@(size) forKey:@"size"];
}

- (double)duration {
    return [NSNumber _lc_decoding:self.localData key:@"duration"].doubleValue;
}

- (void)setDuration:(double)duration {
    [self setObject:@(duration) forKey:@"duration"];
}

- (double)latitude {
    return [NSNumber _lc_decoding:self.localData key:@"latitude"].doubleValue;
}

- (void)setLatitude:(double)latitude {
    [self setObject:@(latitude) forKey:@"latitude"];
}

- (double)longitude {
    return [NSNumber _lc_decoding:self.localData key:@"longitude"].doubleValue;
}

- (void)setLongitude:(double)longitude {
    [self setObject:@(longitude) forKey:@"longitude"];
}

// MARK: NSString

- (NSString *)name {
    return [NSString _lc_decoding:self.localData key:@"name"];
}

- (void)setName:(NSString *)name {
    [self setObject:name forKey:@"name"];
}

- (NSString *)format {
    return [NSString _lc_decoding:self.localData key:@"format"];
}

- (void)setFormat:(NSString *)format {
    [self setObject:format forKey:@"format"];
}

- (NSString *)url {
    return [NSString _lc_decoding:self.localData key:@"url"];
}

- (void)setUrl:(NSString *)url {
    [self setObject:url forKey:@"url"];
}

- (NSString *)objId {
    return [NSString _lc_decoding:self.localData key:@"objId"];
}

- (void)setObjId:(NSString *)objId {
    [self setObject:objId forKey:@"objId"];
}

// MARK: AVIMGeneralObject

- (AVIMGeneralObject *)metaData {
    NSDictionary *object = [NSDictionary _lc_decoding:self.localData key:@"metaData"];
    if (object) {
        return [[AVIMGeneralObject alloc] initWithDictionary:object];
    } else if ([object isKindOfClass:[AVIMGeneralObject class]]) {
        return (AVIMGeneralObject *)object;
    } else {
        return nil;
    }
}

- (void)setMetaData:(AVIMGeneralObject *)metaData {
    [self setObject:[metaData dictionary] forKey:@"metaData"];
}

- (AVIMGeneralObject *)location {
    NSDictionary *object = [NSDictionary _lc_decoding:self.localData key:@"location"];
    if (object) {
        return [[AVIMGeneralObject alloc] initWithDictionary:object];
    } else if ([object isKindOfClass:[AVIMGeneralObject class]]) {
        return (AVIMGeneralObject *)object;
    } else {
        return nil;
    }
}

- (void)setLocation:(AVIMGeneralObject *)location {
    [self setObject:[location dictionary] forKey:@"location"];
}

@end
