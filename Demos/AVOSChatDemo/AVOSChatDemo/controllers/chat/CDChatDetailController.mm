//
//  CDChatDetailController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 8/6/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDChatDetailController.h"
#import "QREncoder.h"
#import "DataMatrix.h"

@interface CDChatDetailController ()

@end

@implementation CDChatDetailController

- (void)viewDidLoad {
    [super viewDidLoad];
    //the qrcode is square. now we make it 250 pixels wide
    int qrcodeImageDimension = 250;
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:self.otherId forKey:@"id"];
    [dict setObject:[NSNumber numberWithInt:self.type] forKey:@"type"];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    //first encode the string into a matrix of bools, TRUE for black dot and FALSE for white. Let the encoder decide the error correction level and version
    DataMatrix* qrMatrix = [QREncoder encodeWithECLevel:QR_ECLEVEL_AUTO version:QR_VERSION_AUTO string:json];
    
    //then render the matrix
    UIImage* qrcodeImage = [QREncoder renderDataMatrix:qrMatrix imageDimension:qrcodeImageDimension];
    
    //put the image into the view
    UIImageView* qrcodeImageView = [[UIImageView alloc] initWithImage:qrcodeImage];
    CGRect parentFrame = self.view.frame;
    CGRect tabBarFrame = self.tabBarController.tabBar.frame;
    
    //center the image
    CGFloat x = (parentFrame.size.width - qrcodeImageDimension) / 2.0;
    CGFloat y = (parentFrame.size.height - qrcodeImageDimension - tabBarFrame.size.height) / 2.0;
    CGRect qrcodeImageViewFrame = CGRectMake(x, y, qrcodeImageDimension, qrcodeImageDimension);
    [qrcodeImageView setFrame:qrcodeImageViewFrame];
    
    //and that's it!
    [self.view addSubview:qrcodeImageView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
