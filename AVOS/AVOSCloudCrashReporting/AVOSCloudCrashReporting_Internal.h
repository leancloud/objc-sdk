//
//  AVOSCloudCrashReporting_Internal.h
//  AVOSCloudCrashReporting
//
//  Created by Qihe Bian on 3/10/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "AVOSCloudCrashReporting.h"
#import "AVOSCloud_Internal.h"
#import "BreakpadController.h"

@interface AVOSCloudCrashReporting () <AVOSCloudModule> {
  BreakpadController *_crashReporter;
}
//@property(nonatomic, getter=isCrashReportingEnabled) BOOL crashReportingEnabled;

+ (void)AVOSCloudDidInitializeWithApplicationId:(NSString *)applicationId clientKey:(NSString *)clientKey;
//- (void)processPendingCrashReports;
- (void)enableCrashReportingWithApplicationId:(NSString *)applicationId clientKey:(NSString *)clientKey;
@end
