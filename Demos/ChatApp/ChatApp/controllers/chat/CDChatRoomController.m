//
//  CDChatRoomController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDChatRoomController.h"
#import "CDSessionManager.h"
#import "CDChatDetailController.h"
#import "QBImagePickerController.h"
#import "UIImage+Resize.h"

@interface CDChatRoomController () <JSMessagesViewDelegate, JSMessagesViewDataSource, QBImagePickerControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate> {
    NSMutableArray *_timestampArray;
    NSDate *_lastTime;
    NSMutableDictionary *_loadedData;
}
@property (nonatomic, strong) NSArray *messages;
@end

@implementation CDChatRoomController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    if ((self = [super init])) {
        self.hidesBottomBarWhenPushed = YES;
        _loadedData = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.type == CDChatRoomTypeGroup) {
        NSString *title = @"group";
        if (self.group.groupId) {
            title = [NSString stringWithFormat:@"group:%@", self.group.groupId];
        }
        self.title = title;
    } else {
        self.title = self.otherId;
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showDetail:)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdated:) name:NOTIFICATION_MESSAGE_UPDATED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionUpdated:) name:NOTIFICATION_SESSION_UPDATED object:nil];
    
    self.delegate = self;
    self.dataSource = self;

//    if (self.group.groupId) {
//    AVObject *groupObject = [AVObject objectWithoutDataWithClassName:@"AVOSRealtimeGroups" objectId:self.group.groupId];
//    [groupObject fetch];
//    NSArray *groupMembers = [groupObject objectForKey:@"m"];
//        
//        [self.group invite:@[@"peerId1",@"peerId2",@"peerId3"]];
//        [self.group kick:@[@"peerId1",@"peerId2",@"peerId3"]];
//    }
//    self.messageArray = [NSMutableArray array];
//    self.timestamps = [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self messageUpdated:nil];
//    if (self.type == CDChatRoomTypeGroup) {
//        [[CDSessionManager sharedInstance] getHistoryMessagesForGroup:self.group.groupId callback:^(NSArray *objects, NSError *error) {
//            for (AVHistoryMessage *message in objects) {
//                NSLog(@"%@:%@:%@:%lld", message.conversationId, message.fromPeerId, message.payload,message.timestamp);
//            }
//        }];
//    } else {
//        [[CDSessionManager sharedInstance] getHistoryMessagesForPeerId:self.otherId callback:^(NSArray *objects, NSError *error) {
//            for (AVHistoryMessage *message in objects) {
//                NSLog(@"%@:%@:%@:%lld", message.conversationId, message.fromPeerId, message.payload,message.timestamp);
//            }
//        }];
//    }
    
    [AVAnalytics event:@"likebutton" attributes:@{@"source":@{@"view": @"week"}, @"do":@"unfollow"}];
    [AVAnalytics event:@"abcde" label:@"aaaa" durations:1000];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshTimestampArray {
    NSDate *lastDate = nil;
    NSMutableArray *hasTimestampArray = [NSMutableArray array];
    for (NSDictionary *dict in self.messages) {
        NSDate *date = [dict objectForKey:@"time"];
        if (!lastDate) {
            lastDate = date;
            [hasTimestampArray addObject:[NSNumber numberWithBool:YES]];
        } else {
            if ([date timeIntervalSinceDate:lastDate] > 60) {
                [hasTimestampArray addObject:[NSNumber numberWithBool:YES]];
                lastDate = date;
            } else {
                [hasTimestampArray addObject:[NSNumber numberWithBool:NO]];
            }
        }
    }
    _timestampArray = hasTimestampArray;
}

- (void)showDetail:(id)sender {
    CDChatDetailController *controller = [[CDChatDetailController alloc] init];
    controller.type = self.type;
    if (self.type == CDChatRoomTypeSingle) {
        controller.otherId = self.otherId;
    } else if (self.type == CDChatRoomTypeGroup) {
        controller.otherId = self.group.groupId;
    }
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

#pragma mark - Messages view delegate
- (void)sendPressed:(UIButton *)sender withText:(NSString *)text {
//    [self.messageArray addObject:[NSDictionary dictionaryWithObject:text forKey:@"Text"]];
//    
//    [self.timestamps addObject:[NSDate date]];
//    
//    if((self.messageArray.count - 1) % 2)
//        [JSMessageSoundEffect playMessageSentSound];
//    else
//        [JSMessageSoundEffect playMessageReceivedSound];
//    NSString *message = [[textView.text stringByReplacingCharactersInRange:range withString:text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
//    [dict setObject:self.session.getSelfPeerId forKey:@"dn"];
//    [dict setObject:text forKey:@"msg"];
//    NSError *error = nil;
//    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
//    NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    [self.session sendMessage:message isTransient:NO toPeerIds:self.session.getAllPeers];
//    [_messages addObject:[[KAMessage alloc] initWithDisplayName:MY_NAME Message:message fromMe:YES]];
    if (self.type == CDChatRoomTypeGroup) {
        if (!self.group.groupId) {
            return;
        }
        [[CDSessionManager sharedInstance] sendMessage:text toGroup:self.group.groupId];
    } else {
        [[CDSessionManager sharedInstance] sendMessage:text toPeerId:self.otherId];
    }
    [self refreshTimestampArray];
    [self finishSend];
}

- (void)sendAttachment:(AVObject *)object {
    if (self.type == CDChatRoomTypeGroup) {
        if (!self.group.groupId) {
            return;
        }
        [[CDSessionManager sharedInstance] sendAttachment:object toGroup:self.group.groupId];
    } else {
        [[CDSessionManager sharedInstance] sendAttachment:object toPeerId:self.otherId];
    }
    [self refreshTimestampArray];
    [self finishSend];

}

- (void)cameraPressed:(id)sender{
    
    [self.inputToolBarView.textView resignFirstResponder];
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"拍照",@"相册", nil];
    [actionSheet showInView:self.view];
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *fromid = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"fromid"];
    
    return (![fromid isEqualToString:[AVUser currentUser].username]) ? JSBubbleMessageTypeIncoming : JSBubbleMessageTypeOutgoing;
}

- (JSBubbleMessageStyle)messageStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return JSBubbleMessageStyleFlat;
}

- (JSBubbleMediaType)messageMediaTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *type = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"type"];

    if ([type isEqualToString:@"text"]) {
        return JSBubbleMediaTypeText;
    } else if ([type isEqualToString:@"image"]) {
        return JSBubbleMediaTypeImage;
    }
    return JSBubbleMediaTypeText;

//    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
//        return JSBubbleMediaTypeText;
//    }else if ([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
//        return JSBubbleMediaTypeImage;
//    }
//    
//    return -1;
}

- (UIButton *)sendButton
{
    return [UIButton defaultSendButton];
}

- (JSMessagesViewTimestampPolicy)timestampPolicy
{
    /*
     JSMessagesViewTimestampPolicyAll = 0,
     JSMessagesViewTimestampPolicyAlternating,
     JSMessagesViewTimestampPolicyEveryThree,
     JSMessagesViewTimestampPolicyEveryFive,
     JSMessagesViewTimestampPolicyCustom
     */
    return JSMessagesViewTimestampPolicyCustom;
}

- (JSMessagesViewAvatarPolicy)avatarPolicy
{
    /*
     JSMessagesViewAvatarPolicyIncomingOnly = 0,
     JSMessagesViewAvatarPolicyBoth,
     JSMessagesViewAvatarPolicyNone
     */
    return JSMessagesViewAvatarPolicyNone;
}

- (JSAvatarStyle)avatarStyle
{
    /*
     JSAvatarStyleCircle = 0,
     JSAvatarStyleSquare,
     JSAvatarStyleNone
     */
    return JSAvatarStyleNone;
}

- (JSInputBarStyle)inputBarStyle
{
    /*
     JSInputBarStyleDefault,
     JSInputBarStyleFlat
     
     */
    return JSInputBarStyleFlat;
}

//  Optional delegate method
//  Required if using `JSMessagesViewTimestampPolicyCustom`
//
- (BOOL)hasTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[_timestampArray objectAtIndex:indexPath.row] boolValue];
}

- (BOOL)hasNameForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.type == CDChatRoomTypeGroup) {
        return YES;
    }
    return NO;
}

#pragma mark - Messages view data source
- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath {
//    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
//        return [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"];
//    }
    return [[self.messages objectAtIndex:indexPath.row] objectForKey:@"message"];
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath {
//    return [self.timestamps objectAtIndex:indexPath.row];
    NSDate *time = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"time"];
    return time;
}

- (NSString *)nameForRowAtIndexPath:(NSIndexPath *)indexPath {
    //    return [self.timestamps objectAtIndex:indexPath.row];
    NSString *name = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"fromid"];
    return name;
}

- (UIImage *)avatarImageForIncomingMessage {
    return [UIImage imageNamed:@"demo-avatar-jobs"];
}

- (SEL)avatarImageForIncomingMessageAction {
    return @selector(onInComingAvatarImageClick);
}

- (void)onInComingAvatarImageClick {
    NSLog(@"__%s__",__func__);
}

- (SEL)avatarImageForOutgoingMessageAction {
    return @selector(onOutgoingAvatarImageClick);
}

- (void)onOutgoingAvatarImageClick {
    NSLog(@"__%s__",__func__);
}

- (UIImage *)avatarImageForOutgoingMessage
{
    return [UIImage imageNamed:@"demo-avatar-woz"];
}

- (id)dataForRowAtIndexPath:(NSIndexPath *)indexPath{
//    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
//        return [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"];
//    }
    NSNumber *r = @(indexPath.row);
    AVFile *file = [_loadedData objectForKey:r];
    if (file) {
//        NSString *objectId = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"object"];
//        NSString *type = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"type"];
//        AVObject *object = [AVObject objectWithoutDataWithClassName:@"Attachments" objectId:objectId];
//        [object fetchIfNeeded];
//        AVFile *file = [object objectForKey:type];
        NSData *data = [file getData];
        UIImage *image = [[UIImage alloc] initWithData:data];
        return image;
    } else {
        NSString *objectId = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"object"];
        NSString *type = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"type"];
        AVObject *object = [AVObject objectWithoutDataWithClassName:@"Attachments" objectId:objectId];
        [object fetchIfNeededInBackgroundWithBlock:^(AVObject *object, NSError *error) {
            AVFile *file = [object objectForKey:type];
            [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
                [_loadedData setObject:file forKey:r];
                [self.tableView reloadData];
            }];
        }];
        UIImage *image = [UIImage imageNamed:@"image_placeholder"];
        return image;
    }
}

- (void)messageUpdated:(NSNotification *)notification {
    NSArray *messages = nil;
    if (self.type == CDChatRoomTypeGroup) {
        NSString *groupId = self.group.groupId;
        if (!groupId) {
            return;
        }
        messages = [[CDSessionManager sharedInstance] getMessagesForGroup:groupId];
    } else {
        messages = [[CDSessionManager sharedInstance] getMessagesForPeerId:self.otherId];
    }
    self.messages = messages;
    [self refreshTimestampArray];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}

- (void)sessionUpdated:(NSNotification *)notification {
    if (self.type == CDChatRoomTypeGroup) {
        NSString *title = @"group";
        if (self.group.groupId) {
            title = [NSString stringWithFormat:@"group:%@", self.group.groupId];
        }
        self.title = title;
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
        {
            @try {
                UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
                imagePickerController.delegate = self;
                imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
                [self presentViewController:imagePickerController animated:YES completion:^{
                    
                }];
            }
            @catch (NSException *exception) {
                
            }
            @finally {
                
            }
        }
            break;
        case 1:
        {
            QBImagePickerController *imagePickerController = [[QBImagePickerController alloc] init];
            imagePickerController.delegate = self;
            imagePickerController.allowsMultipleSelection = NO;
            //            imagePickerController.minimumNumberOfSelection = 3;
            
            //                [self.navigationController pushViewController:imagePickerController animated:YES];
            UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:imagePickerController];
            [self presentViewController:navigationController animated:YES completion:^{
                
            }];

        }
            break;
        default:
            break;
    }
}

- (void)dismissImagePickerController
{
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:NULL];
    } else {
        [self.navigationController popToViewController:self animated:YES];
    }
}

#pragma mark - QBImagePickerControllerDelegate

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAsset:(ALAsset *)asset
{
    NSLog(@"*** qb_imagePickerController:didSelectAsset:");
    NSLog(@"%@", asset);
    ALAssetRepresentation *representation = [asset defaultRepresentation];
    Byte *buffer = (Byte*)malloc((unsigned long)representation.size);
    
    // add error checking here
    NSUInteger buffered = [representation getBytes:buffer fromOffset:0.0 length:(NSUInteger)representation.size error:nil];
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
    if (data) {
        AVFile *imageFile = [AVFile fileWithName:@"image.png" data:data];
        [imageFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (succeeded) {
                AVObject *object = [AVObject objectWithClassName:@"Attachments"];
                [object setObject:@"image" forKey:@"type"];
                [object setObject:imageFile forKey:@"image"];
                [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    if (succeeded) {
                        [self sendAttachment:object];
                    }
                }];
            }
        }];
    }
    [self dismissImagePickerController];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAssets:(NSArray *)assets
{
    NSLog(@"*** qb_imagePickerController:didSelectAssets:");
    NSLog(@"%@", assets);
    
    [self dismissImagePickerController];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController
{
    NSLog(@"*** qb_imagePickerControllerDidCancel:");
    
    [self dismissImagePickerController];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    if (!image) {
        image = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    if (image) {
        UIImage *scaledImage = [image resizedImageToFitInSize:CGSizeMake(1080, 1920) scaleIfSmaller:NO];

        NSData *imageData = UIImageJPEGRepresentation(scaledImage, 0.6);
        NSLog(@"image size %lu", (unsigned long)[imageData length]);
        AVFile *imageFile = [AVFile fileWithName:@"image.png" data:imageData];
        [imageFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (succeeded) {
                AVObject *object = [AVObject objectWithClassName:@"Attachments"];
                [object setObject:@"image" forKey:@"type"];
                [object setObject:imageFile forKey:@"image"];
                [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    if (succeeded) {
                        [self sendAttachment:object];
                    }
                }];
            }
        }];
    }
    [self dismissImagePickerController];
}
@end
