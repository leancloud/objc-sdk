//
//  AVTargetConditionals.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 14/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#ifdef TARGET_OS_IOS
    #define LC_TARGET_OS_IOS TARGET_OS_IOS
#else
    #define LC_TARGET_OS_IOS 0
#endif

#ifdef TARGET_OS_OSX
    #define LC_TARGET_OS_MAC TARGET_OS_OSX
#else
    #define LC_TARGET_OS_MAC 0
#endif

#ifdef TARGET_OS_TV
    #define LC_TARGET_OS_TV TARGET_OS_TV
#else
    #define LC_TARGET_OS_TV 0
#endif

#ifdef TARGET_OS_WATCH
    #define LC_TARGET_OS_WATCH TARGET_OS_WATCH
#else
    #define LC_TARGET_OS_WATCH 0
#endif
