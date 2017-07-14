//
//  LCTargetUmbrella.h
//  AVOSCloud
//
//  Created by Tang Tianyong on 14/06/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import "AVTargetConditionals.h"

#if LC_TARGET_OS_IOS
    #import <UIKit/UIKit.h>
    #import <CoreTelephony/CTTelephonyNetworkInfo.h>
    #import <CoreTelephony/CTCarrier.h>
#elif LC_TARGET_OS_MAC
    #import <AppKit/AppKit.h>
#elif LC_TARGET_OS_TV
    #import <UIKit/UIKit.h>
#elif LC_TARGET_OS_WATCH
    #import <WatchKit/WatchKit.h>
#endif
