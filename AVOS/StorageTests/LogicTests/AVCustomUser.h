//
//  AVCustomUser.h
//  AVOS
//
//  Created by lzw on 15/10/22.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import <AVOSCloud/AVOSCloud.h>

@interface AVCustomUser : AVUser<AVSubclassing>

@property (nonatomic, copy) NSString *title;

@end
