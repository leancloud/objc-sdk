//
//  AVIMErrorUtil.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 1/20/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVIMCommon.h"
#import "MessagesProtoOrig.pbobjc.h"

FOUNDATION_EXPORT NSString *AVIMErrorMessage(AVIMErrorCode code);

FOUNDATION_EXPORT NSError *LCErrorFromErrorCommand(AVIMErrorCommand *command);
FOUNDATION_EXPORT NSError *LCErrorFromSessionCommand(AVIMSessionCommand *command);
FOUNDATION_EXPORT NSError *LCErrorFromAckCommand(AVIMAckCommand *command);
