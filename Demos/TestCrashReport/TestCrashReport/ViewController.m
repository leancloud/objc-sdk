//
//  ViewController.m
//  TestCrashReport
//
//  Created by Qihe Bian on 4/24/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction) triggerCrash {
  /* Trigger a crash */
  
  CFRelease(NULL);
  
}


- (IBAction) triggerExceptionCrash {
  /* Trigger a crash */
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSArray *array = [NSArray array];
    [array objectAtIndex:23];
  });

}
@end
