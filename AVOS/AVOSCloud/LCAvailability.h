//
//  LCAvailability.h
//  LeanCloud
//
//  Created by Tang Tianyong on 1/6/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Availability.h>
#import <TargetConditionals.h>

#ifndef LC_IOS_UNAVAILABLE
#  ifdef __IOS_UNAVILABLE
#    define LC_IOS_UNAVAILABLE __IOS_UNAVAILABLE
#  else
#    define LC_IOS_UNAVAILABLE
#  endif
#endif

#ifndef LC_OSX_UNAVAILABLE
#  if TARGET_OS_MAC
#    define LC_OSX_UNAVAILABLE __OSX_UNAVAILABLE
#  else
#    define LC_OSX_UNAVAILABLE
#  endif
#endif

#ifndef LC_WATCH_UNAVAILABLE
#  ifdef __WATCHOS_UNAVAILABLE
#    define LC_WATCH_UNAVAILABLE __WATCHOS_UNAVAILABLE
#  else
#    define LC_WATCH_UNAVAILABLE
#  endif
#endif

#ifndef LC_TV_UNAVAILABLE
#  ifdef __TVOS_PROHIBITED
#    define LC_TV_UNAVAILABLE __TVOS_PROHIBITED
#  else
#    define LC_TV_UNAVAILABLE
#  endif
#endif

#define LC_IOS_ONLY (TARGET_OS_IPHONE)
#define LC_OSX_ONLY (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#define LC_TARGET_OS_OSX (TARGET_OS_MAC && !TARGET_OS_IOS && !TARGET_OS_WATCH && !TARGET_OS_TV)
#define LC_TARGET_OS_IOS (TARGET_OS_IOS && !TARGET_OS_WATCH && !TARGET_OS_TV)
