//
//  LCUtility.h
//  LCChatApp
//
//  Created by Qihe Bian on 11/21/14.
//  Copyright (c) 2014 Lean Cloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface LCUtility : NSObject
+ (BOOL) isCameraAvailable;
+ (BOOL) isRearCameraAvailable;
+ (BOOL) isFrontCameraAvailable;
+ (BOOL) doesCameraSupportTakingPhotos;
+ (BOOL) isPhotoLibraryAvailable;
+ (BOOL) canUserPickVideosFromPhotoLibrary;
+ (BOOL) canUserPickPhotosFromPhotoLibrary;
@end
