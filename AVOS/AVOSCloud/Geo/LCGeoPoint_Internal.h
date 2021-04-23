//
//  LCGeoPoint_Internal.h
//  paas
//
//  Created by Zhu Zeng on 3/12/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "LCGeoPoint.h"

@interface LCGeoPoint ()

+(NSDictionary *)dictionaryFromGeoPoint:(LCGeoPoint *)point;
+(LCGeoPoint *)geoPointFromDictionary:(NSDictionary *)dict;

@end
