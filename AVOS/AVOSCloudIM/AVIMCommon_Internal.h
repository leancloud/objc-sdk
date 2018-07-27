//
//  AVIMCommon_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/7/27.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"

/// { kAVIMUserOptionUseUnread: true } support unread notification feature. use [lc.protobuf2.3].
/// { kAVIMUserOptionUseUnread: false } not support unread notification feature. use [lc.protobuf2.1].
static NSString * const kAVIMUserOptionUseUnread = @"AVIMUserOptionUseUnread";
