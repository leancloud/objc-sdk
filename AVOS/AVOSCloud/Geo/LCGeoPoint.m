//
//  LCGeoPoint.h
//  LeanCloud
//


#import "LCGeoPoint.h"

@implementation  LCGeoPoint

@synthesize latitude = _latitude;
@synthesize longitude = _longitude;

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];

    if (self) {
        _latitude = [aDecoder decodeDoubleForKey:@"latitude"];
        _longitude = [aDecoder decodeDoubleForKey:@"longitude"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeDouble:_latitude forKey:@"latitude"];
    [aCoder encodeDouble:_longitude forKey:@"longitude"];
}

- (id)copyWithZone:(NSZone *)zone
{
    LCGeoPoint *point = [[[self class] allocWithZone:zone] init];
    point.longitude = self.longitude;
    point.latitude = self.latitude;
    return point;
}

+ (LCGeoPoint *)geoPoint
{
    LCGeoPoint * result = [[LCGeoPoint alloc] init];
    return result;
}

+ (LCGeoPoint *)geoPointWithLatitude:(double)latitude longitude:(double)longitude
{
    LCGeoPoint * point = [LCGeoPoint geoPoint];
    point.latitude = latitude;
    point.longitude = longitude;
    return point;
}

+(NSDictionary *)dictionaryFromGeoPoint:(LCGeoPoint *)point
{
    return @{ @"__type": @"GeoPoint", @"latitude": @(point.latitude), @"longitude": @(point.longitude) };
}

+(LCGeoPoint *)geoPointFromDictionary:(NSDictionary *)dict
{
    LCGeoPoint * point = [[LCGeoPoint alloc]init];
    point.latitude = [[dict objectForKey:@"latitude"] doubleValue];
    point.longitude = [[dict objectForKey:@"longitude"] doubleValue];
    return point;
}

@end
