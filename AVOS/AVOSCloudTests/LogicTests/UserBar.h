//
//  UserBar.h
//  
//
//  Created by Summer on 13-9-9.
//
//

#import <AVOSCloud/AVOSCloud.h>
#import "AVSubclassing.h"

@interface UserBar : AVUser<AVSubclassing>

+ (NSString *)parseClassName;

@property (retain) NSString *displayName;
@property int rupees;
@property BOOL fireproof;
@property (assign) double testDoubleValue;
@property (copy, nonatomic) NSString *nameForTextCopy;

@property float testFloatValue;
@property CGFloat testCGFloatValue;

@end
