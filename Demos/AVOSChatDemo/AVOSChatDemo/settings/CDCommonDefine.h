//
//  CDCommonDefine.h
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/24/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#ifndef AVOSChatDemo_CDCommonDefine_h
#define AVOSChatDemo_CDCommonDefine_h

#define USE_US 0
#if !USE_US
//国内节点
#define AVOSAppID @"bhtojqyzlsrbz9z34s7snxgzxblduzy2jvj5cdblc3cka2bq"
#define AVOSAppKey @"zcbu9s9twkm9ud6obfj6ctx4qio3juf4j71syws0s3a9anm6"
#else
//美国节点
#define AVOSAppID @"l8td56kxwdg3o3p4lw4ma6mczopgomuer0b6yd8oomodill4"
#define AVOSAppKey @"v4y1hsw6pv0yibqmtfib6qfhcvvxq8l9x7ive8460jl0t4jg"
#endif

#define RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define RGBACOLOR(r,g,b,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]
#define UIColorFromRGB(rgb) [UIColor colorWithRed:((rgb) & 0xFF0000 >> 16)/255.0 green:((rgb) & 0xFF00 >> 8)/255.0 blue:((rgb) & 0xFF)/255.0 alpha:1.0]

#define NAVIGATION_COLOR_MALE RGBCOLOR(24,120,148)
#define NAVIGATION_COLOR_FEMALE RGBCOLOR(215,81,67)
#define NAVIGATION_COLOR_SQUARE RGBCOLOR(248,248,248)
#define NAVIGATION_COLOR NAVIGATION_COLOR_MALE

#define SCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)

#define SYSTEM_VERSION [[[UIDevice currentDevice] systemVersion] floatValue]

#define NOTIFICATION_MESSAGE_UPDATED @"NOTIFICATION_MESSAGE_UPDATED"
#define NOTIFICATION_SESSION_UPDATED @"NOTIFICATION_SESSION_UPDATED"
#define KEY_USERNAME @"KEY_USERNAME"
#define KEY_ISLOGINED @"KEY_ISLOGINED"

#define USERNAME_MIN_LENGTH 6
#define PASSWORD_MIN_LENGTH 6
#endif
