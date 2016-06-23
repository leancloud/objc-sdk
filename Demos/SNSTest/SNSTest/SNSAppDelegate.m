//
//  SNSAppDelegate.m
//  SNSTest
//
//  Created by Qihe Bian on 9/17/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "SNSAppDelegate.h"
#import <AVOSCloud/AVOSCloud.h>
#import <AVOSCloudSNS/AVOSCloudSNS.h>

#define AVOSAppID @"bhtojqyzlsrbz9z34s7snxgzxblduzy2jvj5cdblc3cka2bq"
#define AVOSAppKey @"zcbu9s9twkm9ud6obfj6ctx4qio3juf4j71syws0s3a9anm6"

@implementation SNSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *vc = [[UIViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    self.window.rootViewController = nav;
    [AVLogger setLoggerLevelMask:AVLoggerLevelAll];
    [AVLogger addLoggerDomain:AVLoggerDomainIM];
    [AVLogger addLoggerDomain:AVLoggerDomainCURL];
    
//    [AVOSCloud setApplicationId:AVOSAppID
//                      clientKey:AVOSAppKey];
    [AVOSCloud setApplicationId:@"pbszrneu2pru7ht0nedf47z5zsml4gy7n5qdgpyc60dyfxp7"
                      clientKey:@"jpknm5a2koe550a92f77hyn4cg63zqnsi13kyfz6if0q7yng"];
    dispatch_async(dispatch_get_main_queue(), ^{
//        AVUser *user = [AVUser user];
//        user.username = @"tttttt1";
//        user.password = @"123456";
//        [user signUp];
//        [AVUser logInWithUsername:@"tttttt1" password:@"123456"];
//        [AVOSCloudSNS setupPlatform:AVOSCloudSNSSinaWeibo
//                         withAppKey:@"3255235375"
//                       andAppSecret:@"4fcce273924fccf65a0d3c464cd8336c"
//                     andRedirectURI:@"http://www.ufosky.com"];
        [AVOSCloudSNS setupPlatform:AVOSCloudSNSSinaWeibo withAppKey:@"3010488771" andAppSecret:@"9da755a333383ca068d0aa93dad83756" andRedirectURI:@"https://api.weibo.com/oauth2/default.html"];
        [AVOSCloudSNS loginWithCallback:^(NSDictionary* object, NSError *error) {
            if (object) {
                NSLog(@"object:%@", object);
//                [user addAuthData:object platform:AVOSCloudSNSPlatformWeiBo block:^(AVUser *user, NSError *error) {
//                    if (error) {
//                        NSLog(@"error:%@", error);
//                    }
//                    [AVUser loginWithAuthData:object platform:AVOSCloudSNSPlatformWeiBo block:^(AVUser *user, NSError *error) {
//                        if (error) {
//                            NSLog(@"error:%@", error);
//                        }
//                    }];
//                }];
            } else {
                NSLog(@"error:%@", error);
            }
            
        } toPlatform:AVOSCloudSNSSinaWeibo];

//        [AVOSCloudSNS setupPlatform:AVOSCloudSNSQQ
//                         withAppKey:@"100512940"
//                       andAppSecret:@"afbfdff94b95a2fb8fe58a8e24c4ba5f"
//                     andRedirectURI:@"auth://tauth.qq.com/"];
//        [AVOSCloudSNS loginWithCallback:^(id object, NSError *error) {
//            NSLog(@"error:%@",[error localizedDescription]);
//            NSLog(@"%@",object);
//            
//            if (!error && object) {
//                [[AVUser currentUser] addAuthData:object platform:AVOSCloudSNSPlatformQQ block:^(AVUser *user, NSError *error) {
//                    if (error) {
//                        NSLog(@"error:%@", error);
//                    }
//                    [AVUser loginWithAuthData:object platform:AVOSCloudSNSPlatformQQ block:^(AVUser *user, NSError *error) {
//                        if (error) {
//                            NSLog(@"error:%@", error);
//                        }
//                    }];
//                }];
//            } else {
//                NSLog(@"Error");
//            }
//
//        } toPlatform:AVOSCloudSNSQQ];
    });
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

-(BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url{
    return [AVOSCloudSNS handleOpenURL:url];
}
@end
