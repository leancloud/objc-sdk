//
//  LCChatController.m
//  ChatApp
//
//  Created by Qihe Bian on 12/24/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCChatController.h"
#import "LCIMClient.h"
#import "QBImagePickerController.h"
#import "UIImage+Resize.h"
#import "LCUser.h"
#import "LCMessageEntity.h"
#import "NZCircularImageView.h"
#import "LCChatDetailController.h"

@interface LCChatController () <JSMessagesViewDelegate, JSMessagesViewDataSource, QBImagePickerControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *messages;

@end

@implementation LCChatController
- (instancetype)init {
    if ((self = [super init])) {
        self.hidesBottomBarWhenPushed = YES;
        self.delegate = self;
        self.dataSource = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showDetail:)];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:[UIImage imageNamed:@"button_group"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(showDetail:) forControlEvents:UIControlEventTouchUpInside];
    button.frame = CGRectMake(0, 0, 30, 30);
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.rightBarButtonItem = item;

    self.messages = [[LCIMClient sharedInstance] messagesForConversationId:_conversation.conversationId];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self scrollToBottomAnimated:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageUpdated:) name:LC_NOTIFICATION_MESSAGE_UPDATED object:_conversation];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:LC_NOTIFICATION_MESSAGE_UPDATED object:_conversation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showDetail:(id)sender {
    LCChatDetailController *controller = [[LCChatDetailController alloc] initWithConversation:self.conversation];
//    controller.conversation = self.conversation;
//    if (self.type == CDChatRoomTypeSingle) {
//        controller.otherId = self.otherId;
//    } else if (self.type == CDChatRoomTypeGroup) {
//        controller.otherId = self.group.groupId;
//    }
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)messageUpdated:(NSNotification *)notification {
    self.messages = [[LCIMClient sharedInstance] messagesForConversationId:_conversation.conversationId];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
}
#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

#pragma mark - JSMessagesViewDelegate
- (void)didSendText:(NSString *)text fromSender:(NSString *)sender onDate:(NSDate *)date {
//    if ((self.messages.count - 1) % 2) {
        [JSMessageSoundEffect playMessageSentSound];
//    }
//    else {
        // for demo purposes only, mimicing received messages
//        [JSMessageSoundEffect playMessageReceivedSound];
//        sender = arc4random_uniform(10) % 2 ? kSubtitleCook : kSubtitleWoz;
//    }
    [[LCIMClient sharedInstance] sendText:text conversation:_conversation callback:^(BOOL succeeded, NSError *error) {
        self.messages = [[LCIMClient sharedInstance] messagesForConversationId:_conversation.conversationId];
        [self finishSend];
        [self scrollToBottomAnimated:YES];
    }];
//    LCMessageEntity *entity = [LCMessageEntity SQPCreateEntity];
//    entity.text = text;
//    entity.sender = [LCUser userById:sender].nickname;
//    entity.clientId = sender;
//    entity.date = date;
//    [self.messages addObject:[[JSMessage alloc] initWithText:text sender:sender date:date]];
//    
//    [self finishSend];
//    [self scrollToBottomAnimated:YES];
}


- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    LCMessageEntity *entity = [self.messages objectAtIndex:indexPath.row];
    BOOL isSelf = [entity.clientId isEqualToString:[[LCUser currentUser] objectId]];
    return isSelf ? JSBubbleMessageTypeOutgoing : JSBubbleMessageTypeIncoming;
}

- (UIImageView *)bubbleImageViewWithType:(JSBubbleMessageType)type
                       forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (type == JSBubbleMessageTypeIncoming) {
        return [JSBubbleImageViewFactory bubbleImageViewForType:type
                                                          color:[UIColor js_bubbleWhiteColor]];
    } else {
        return [JSBubbleImageViewFactory bubbleImageViewForType:type
                                                          color:[UIColor js_bubbleBlueColor]];
    }
}

- (JSMessageInputViewStyle)inputViewStyle {
    return JSMessageInputViewStyleFlat;
}

- (BOOL)shouldDisplayTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)configureCell:(JSBubbleMessageCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if ([cell messageType] == JSBubbleMessageTypeOutgoing) {
        cell.bubbleView.textView.textColor = [UIColor whiteColor];
        
        if ([cell.bubbleView.textView respondsToSelector:@selector(linkTextAttributes)]) {
            NSMutableDictionary *attrs = [cell.bubbleView.textView.linkTextAttributes mutableCopy];
            [attrs setValue:[UIColor blueColor] forKey:UITextAttributeTextColor];
            
            cell.bubbleView.textView.linkTextAttributes = attrs;
        }
    }
    
    if (cell.timestampLabel) {
        cell.timestampLabel.textColor = [UIColor lightGrayColor];
        cell.timestampLabel.shadowOffset = CGSizeZero;
    }
    
    if (cell.subtitleLabel) {
        cell.subtitleLabel.textColor = [UIColor lightGrayColor];
    }
    
#if TARGET_IPHONE_SIMULATOR
    cell.bubbleView.textView.dataDetectorTypes = UIDataDetectorTypeNone;
#else
    cell.bubbleView.textView.dataDetectorTypes = UIDataDetectorTypeAll;
#endif
}

- (BOOL)shouldPreventScrollToBottomWhileUserScrolling {
    return YES;
}

- (BOOL)allowsPanToDismissKeyboard {
    return NO;
}

//- (UIButton *)sendButtonForInputView {
//    return [UIButton ]
//}

- (NSString *)customCellIdentifierForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - JSMessagesViewDataSource
- (id<JSMessageData>)messageForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self.messages objectAtIndex:indexPath.row];
}

- (UIImageView *)avatarImageViewForRowAtIndexPath:(NSIndexPath *)indexPath sender:(NSString *)sender {
    __block NZCircularImageView *imageView = [[NZCircularImageView alloc] initWithFrame:CGRectMake(0, 0, 256, 256)];
    LCMessageEntity *entity = [self.messages objectAtIndex:indexPath.row];
    __block LCUser *user = [LCUser userById:entity.clientId];
    if (user) {
        NSURL *url = [NSURL URLWithString:user.photoUrl];
        [imageView sd_setImageWithURL:url placeholderImage:[UIImage imageNamed:@"head_default"]];
    } else {
        [LCUser queryUserWithId:entity.clientId callback:^(AVObject *object, NSError *error) {
            user = (LCUser *)object;
            NSURL *url = [NSURL URLWithString:user.photoUrl];
            [imageView sd_setImageWithURL:url placeholderImage:[UIImage imageNamed:@"head_default"]];
        }];
    }
//    [query getObjectInBackgroundWithId: block:^(AVObject *object, NSError *error) {
//        LCUser *user = (LCUser *)object;
//        NSString *nickname = user.nickname;
//        conversationCell.nameLabel.text = nickname;
//        [conversationCell.headView sd_setImageWithURL:[NSURL URLWithString:user.photoUrl] placeholderImage:[UIImage imageNamed:@"head_default.png"]];
//        
//    }];
    return imageView;
//    imageView sd_setImageWithURL:[NSURL URLWithString:<#(NSString *)#>] placeholderImage:<#(UIImage *)#>
}

//#pragma mark - Table view data source
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//    return self.messages.count;
//}
//
//#pragma mark - Messages view delegate
//- (void)sendPressed:(UIButton *)sender withText:(NSString *)text {
//    //    [self.messageArray addObject:[NSDictionary dictionaryWithObject:text forKey:@"Text"]];
//    //
//    //    [self.timestamps addObject:[NSDate date]];
//    //
//    //    if((self.messageArray.count - 1) % 2)
//    //        [JSMessageSoundEffect playMessageSentSound];
//    //    else
//    //        [JSMessageSoundEffect playMessageReceivedSound];
//    //    NSString *message = [[textView.text stringByReplacingCharactersInRange:range withString:text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//    //    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
//    //    [dict setObject:self.session.getSelfPeerId forKey:@"dn"];
//    //    [dict setObject:text forKey:@"msg"];
//    //    NSError *error = nil;
//    //    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
//    //    NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    //    [self.session sendMessage:message isTransient:NO toPeerIds:self.session.getAllPeers];
//    //    [_messages addObject:[[KAMessage alloc] initWithDisplayName:MY_NAME Message:message fromMe:YES]];
//    if (self.type == CDChatRoomTypeGroup) {
//        if (!self.group.groupId) {
//            return;
//        }
//        [[CDSessionManager sharedInstance] sendMessage:text toGroup:self.group.groupId];
//    } else {
//        [[CDSessionManager sharedInstance] sendMessage:text toPeerId:self.otherId];
//    }
//    [self refreshTimestampArray];
//    [self finishSend];
//}
//
//- (void)sendAttachment:(AVObject *)object {
//    if (self.type == CDChatRoomTypeGroup) {
//        if (!self.group.groupId) {
//            return;
//        }
//        [[CDSessionManager sharedInstance] sendAttachment:object toGroup:self.group.groupId];
//    } else {
//        [[CDSessionManager sharedInstance] sendAttachment:object toPeerId:self.otherId];
//    }
//    [self refreshTimestampArray];
//    [self finishSend];
//    
//}
//
//- (void)cameraPressed:(id)sender{
//    
//    [self.inputToolBarView.textView resignFirstResponder];
//    
//    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"拍照",@"相册", nil];
//    [actionSheet showInView:self.view];
//}
//
//- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSString *fromid = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"fromid"];
//    
//    return (![fromid isEqualToString:[AVUser currentUser].username]) ? JSBubbleMessageTypeIncoming : JSBubbleMessageTypeOutgoing;
//}
//
//- (JSBubbleMessageStyle)messageStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
//    return JSBubbleMessageStyleFlat;
//}
//
//- (JSBubbleMediaType)messageMediaTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSString *type = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"type"];
//    
//    if ([type isEqualToString:@"text"]) {
//        return JSBubbleMediaTypeText;
//    } else if ([type isEqualToString:@"image"]) {
//        return JSBubbleMediaTypeImage;
//    }
//    return JSBubbleMediaTypeText;
//    
//    //    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
//    //        return JSBubbleMediaTypeText;
//    //    }else if ([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
//    //        return JSBubbleMediaTypeImage;
//    //    }
//    //
//    //    return -1;
//}
//
//- (UIButton *)sendButton
//{
//    return [UIButton defaultSendButton];
//}
//
//- (JSMessagesViewTimestampPolicy)timestampPolicy
//{
//    /*
//     JSMessagesViewTimestampPolicyAll = 0,
//     JSMessagesViewTimestampPolicyAlternating,
//     JSMessagesViewTimestampPolicyEveryThree,
//     JSMessagesViewTimestampPolicyEveryFive,
//     JSMessagesViewTimestampPolicyCustom
//     */
//    return JSMessagesViewTimestampPolicyCustom;
//}
//
//- (JSMessagesViewAvatarPolicy)avatarPolicy
//{
//    /*
//     JSMessagesViewAvatarPolicyIncomingOnly = 0,
//     JSMessagesViewAvatarPolicyBoth,
//     JSMessagesViewAvatarPolicyNone
//     */
//    return JSMessagesViewAvatarPolicyNone;
//}
//
//- (JSAvatarStyle)avatarStyle
//{
//    /*
//     JSAvatarStyleCircle = 0,
//     JSAvatarStyleSquare,
//     JSAvatarStyleNone
//     */
//    return JSAvatarStyleNone;
//}
//
//- (JSInputBarStyle)inputBarStyle
//{
//    /*
//     JSInputBarStyleDefault,
//     JSInputBarStyleFlat
//     
//     */
//    return JSInputBarStyleFlat;
//}
//
////  Optional delegate method
////  Required if using `JSMessagesViewTimestampPolicyCustom`
////
//- (BOOL)hasTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
//    return [[_timestampArray objectAtIndex:indexPath.row] boolValue];
//}
//
//- (BOOL)hasNameForRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (self.type == CDChatRoomTypeGroup) {
//        return YES;
//    }
//    return NO;
//}
//
//#pragma mark - Messages view data source
//- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath {
//    //    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"]){
//    //        return [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Text"];
//    //    }
//    return [[self.messages objectAtIndex:indexPath.row] objectForKey:@"message"];
//}
//
//- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath {
//    //    return [self.timestamps objectAtIndex:indexPath.row];
//    NSDate *time = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"time"];
//    return time;
//}
//
//- (NSString *)nameForRowAtIndexPath:(NSIndexPath *)indexPath {
//    //    return [self.timestamps objectAtIndex:indexPath.row];
//    NSString *name = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"fromid"];
//    return name;
//}
//
//- (UIImage *)avatarImageForIncomingMessage {
//    return [UIImage imageNamed:@"demo-avatar-jobs"];
//}
//
//- (SEL)avatarImageForIncomingMessageAction {
//    return @selector(onInComingAvatarImageClick);
//}
//
//- (void)onInComingAvatarImageClick {
//    NSLog(@"__%s__",__func__);
//}
//
//- (SEL)avatarImageForOutgoingMessageAction {
//    return @selector(onOutgoingAvatarImageClick);
//}
//
//- (void)onOutgoingAvatarImageClick {
//    NSLog(@"__%s__",__func__);
//}
//
//- (UIImage *)avatarImageForOutgoingMessage
//{
//    return [UIImage imageNamed:@"demo-avatar-woz"];
//}
//
//- (id)dataForRowAtIndexPath:(NSIndexPath *)indexPath{
//    //    if([[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"]){
//    //        return [[self.messageArray objectAtIndex:indexPath.row] objectForKey:@"Image"];
//    //    }
//    NSNumber *r = @(indexPath.row);
//    AVFile *file = [_loadedData objectForKey:r];
//    if (file) {
//        //        NSString *objectId = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"object"];
//        //        NSString *type = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"type"];
//        //        AVObject *object = [AVObject objectWithoutDataWithClassName:@"Attachments" objectId:objectId];
//        //        [object fetchIfNeeded];
//        //        AVFile *file = [object objectForKey:type];
//        NSData *data = [file getData];
//        UIImage *image = [[UIImage alloc] initWithData:data];
//        return image;
//    } else {
//        NSString *objectId = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"object"];
//        NSString *type = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"type"];
//        AVObject *object = [AVObject objectWithoutDataWithClassName:@"Attachments" objectId:objectId];
//        [object fetchIfNeededInBackgroundWithBlock:^(AVObject *object, NSError *error) {
//            AVFile *file = [object objectForKey:type];
//            [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
//                [_loadedData setObject:file forKey:r];
//                [self.tableView reloadData];
//            }];
//        }];
//        UIImage *image = [UIImage imageNamed:@"image_placeholder"];
//        return image;
//    }
//}


@end
