//
//  AVGeoPoint.h
//  LeanCloud
//


#import "AVGeoPoint.h"

@implementation  AVGeoPoint

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
    AVGeoPoint *point = [[[self class] allocWithZone:zone] init];
    point.longitude = self.longitude;
    point.latitude = self.latitude;
    return point;
}

+ (AVGeoPoint *)geoPoint
{
    AVGeoPoint * result = [[AVGeoPoint alloc] init];
    return result;
}

+ (AVGeoPoint *)geoPointWithLatitude:(double)latitude longitude:(double)longitude
{
    AVGeoPoint * point = [AVGeoPoint geoPoint];
    point.latitude = latitude;
    point.longitude = longitude;
    return point;
}

+(NSDictionary *)dictionaryFromGeoPoint:(AVGeoPoint *)point
{
    return @{ @"__type": @"GeoPoint", @"latitude": @(point.latitude), @"longitude": @(point.longitude) };
}

+(AVGeoPoint *)geoPointFromDictionary:(NSDictionary *)dict
{
    AVGeoPoint * point = [[AVGeoPoint alloc]init];
    point.latitude = [[dict objectForKey:@"latitude"] doubleValue];
    point.longitude = [[dict objectForKey:@"longitude"] doubleValue];
    return point;
}

@end
