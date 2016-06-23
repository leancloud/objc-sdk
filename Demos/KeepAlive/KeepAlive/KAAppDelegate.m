//
//  KAAppDelegate.m
//  KeepAlive
//
//  Created by Qihe Bian on 7/21/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "KAAppDelegate.h"
#import <AVOSCloud/AVOSCloud.h>
#import "KALoginController.h"
#import "KASessionChatController.h"

@implementation KAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [AVOSCloud setApplicationId:@"19y77w6qkz7k5h1wifou7lwnrxf9i3g4qdpxb4k1yeuvjgp7"
                      clientKey:@"gyxj747shi4j6ryedriq68k2jlqoftqfjpqxrzmqo8zmkjf6"];
    
    AVObject *installation = [AVObject objectWithClassName:@"_Installation"];
    [installation setObject:@"1234567890" forKey:@"installationId"];
    [installation setObject:@"android" forKey:@"deviceType"];
    [installation saveInBackground];

    UITabBarController *tab = [[UITabBarController alloc] init];
    KASessionChatController *chat = [[KASessionChatController alloc] init];
    [tab addChildViewController:chat];
    self.window.rootViewController = tab;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        KALoginController *vc = [[KALoginController alloc] init];
        [tab presentViewController:vc animated:YES completion:^{
            
        }];
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

@end
