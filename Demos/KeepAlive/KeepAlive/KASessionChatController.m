//
//  KASessionChatController.m
//  KeepAlive
//
//  Created by Qihe Bian on 7/21/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "KASessionChatController.h"
#import <AVOSCloud/AVOSCloud.h>
#import <CommonCrypto/CommonHMAC.h>

#define MY_NAME [[NSUserDefaults standardUserDefaults] objectForKey:@"DisplayName"]
static const int kTagMessageLabel = 1000;
static const int kTagDisplayNameLabel = 1001;
static const int kTagLineView = 1002;
@interface KAMessage : NSObject

- (id)initWithDisplayName:(NSString *)displayName Message:(NSString *)message fromMe:(BOOL)fromMe;
@property (nonatomic, strong, readonly) NSString *displayName;
@property (nonatomic, strong, readonly) NSString *message;
@property (nonatomic, readonly) BOOL fromMe;
@property (nonatomic) BOOL isStatus;
@end

@implementation KAMessage

- (id)initWithDisplayName:(NSString *)displayName Message:(NSString *)message fromMe:(BOOL)fromMe
{
    self = [super init];
    if (self) {
        _fromMe = fromMe;
        _message = message;
        _displayName = displayName;
    }
    
    return self;
}

@end

@interface KASessionChatController () <UITextViewDelegate, UITableViewDelegate, UITableViewDataSource, AVSessionDelegate, AVSignatureDelegate> {
    NSMutableArray *_messages;
    NSMutableArray *_cellHeights;
    AVSession *_session;
}
- (void)refreshButtonClicked:(id)sender;

@property (strong, nonatomic) UITextView *inputView;
@property (strong, nonatomic) UITableView *tableView;

@end

@implementation KASessionChatController
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    [super loadView];
    UIView *view = [[UIScrollView alloc] initWithFrame:self.view.frame];
    self.view = view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _messages = [[NSMutableArray alloc] init];
    CGRect rect = self.view.frame;
    rect.size.height -= 100;
    UITableView *tableView = [[UITableView alloc] initWithFrame:rect style:UITableViewStylePlain];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
    tableView.dataSource = self;
    tableView.delegate = self;
    [self.view addSubview:tableView];
    self.tableView = tableView;
    rect = self.view.frame;
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, rect.size.height - 100, rect.size.width, 40)];
    textView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    textView.editable = YES;
    textView.delegate = self;
    textView.userInteractionEnabled = YES;
    textView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:textView];
    self.inputView = textView;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
    [self.view addGestureRecognizer:tap];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardDidShow:)
                   name:UIKeyboardDidShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide:)
                   name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self refreshSession];
    
    [_inputView becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)refreshSession {
    [_messages removeAllObjects];
    [self.tableView reloadData];
    AVQuery *query = [AVInstallation query];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        NSMutableArray *installationIds = [[NSMutableArray alloc] init];
        for (AVObject *object in objects) {
            if ([object objectForKey:@"installationId"]) {
                [installationIds addObject:[object objectForKey:@"installationId"]];
            }
        }
        
        if ([_session isOpen]) {
            [_session close];
        } else {
            _session = [[AVSession alloc] init];
        }
        _session.sessionDelegate = self;
        _session.signatureDelegate = self;
        [installationIds removeObject:@"selfId"];
        [_session open:@"selfId" withPeerIds:installationIds];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _messages.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    KAMessage *message = [_messages objectAtIndex:indexPath.row];
    CGFloat height1 = [message.message sizeWithFont:[UIFont systemFontOfSize:14] forWidth:200 lineBreakMode:NSLineBreakByWordWrapping].height;
    CGFloat height2 = [message.displayName sizeWithFont:[UIFont boldSystemFontOfSize:16] forWidth:60 lineBreakMode:NSLineBreakByCharWrapping].height;
    return (height1>height2?height1:height2) + 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = @"ChatCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        UILabel *label = [[UILabel alloc] init];
        label.tag = kTagMessageLabel;
        label.font = [UIFont systemFontOfSize:14];
        [cell.contentView addSubview:label];
        
        label = [[UILabel alloc] init];
        label.tag = kTagDisplayNameLabel;
        label.font = [UIFont systemFontOfSize:16];
        [cell.contentView addSubview:label];
        
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 1)];
        line.backgroundColor = [UIColor grayColor];
        line.tag = kTagLineView;
        [cell.contentView addSubview:line];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    CGFloat height = [self tableView:tableView heightForRowAtIndexPath:indexPath] - 10;
    KAMessage *message = [_messages objectAtIndex:indexPath.row];
    

    UILabel *label = (UILabel *)[cell.contentView viewWithTag:kTagMessageLabel];
    label.frame = CGRectMake(60, 5, 200, height);
    label.text = message.message;
    if (message.fromMe) {
        label.textAlignment = NSTextAlignmentRight;
    } else {
        label.textAlignment = NSTextAlignmentLeft;
    }
    
    label = (UILabel *)[cell.contentView viewWithTag:kTagDisplayNameLabel];
    label.text = message.displayName;
    if (message.fromMe) {
        label.frame = CGRectMake(260, 5, 60, height);
        label.textAlignment = NSTextAlignmentRight;
    } else {
        label.frame = CGRectMake(0, 5, 60, height);
        label.textAlignment = NSTextAlignmentLeft;
    }
    UIView *line = [cell.contentView viewWithTag:kTagLineView];
    CGRect rect = line.frame;
    rect.origin.y = height + 10 - 1;
    line.frame = rect;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
{
    if ([text rangeOfString:@"\n"].location != NSNotFound) {
        NSString *message = [[textView.text stringByReplacingCharactersInRange:range withString:text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        [_session sendMessage:[NSString stringWithFormat:@"{\"dn\":\"%@\", \"msg\":\"%@\"}", MY_NAME, message] isTransient:NO toPeerIds:_session.getAllPeers];
        [_messages addObject:[[KAMessage alloc] initWithDisplayName:MY_NAME Message:message fromMe:YES]];
        
//        [self.tableView beginUpdates];
        [self.tableView reloadData];
//        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_messages.count - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView scrollRectToVisible:self.tableView.tableFooterView.frame animated:YES];
//        [self.tableView endUpdates];
        textView.text = @"";
        return NO;
    }
    return YES;
}

#pragma mark - AVSessionDelegate
- (void)onSessionOpen:(AVSession *)session {
    NSLog(@"on open");
}

- (void)onSessionPaused:(AVSession *)session {
    NSLog(@"on pause");
}

- (void)onSessionResumed:(AVSession *)seesion {
    NSLog(@"on resume");
}

- (void)onSessionMessage:(AVSession *)session message:(NSString *)message peerId:(NSString *)peerId {
    NSLog(@"on message: %@", message);
    NSError *error;
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    
    if (error == nil) {
        KAMessage *chatMessage = nil;
        if ([jsonDict objectForKey:@"st"]) {
            NSString *displayName = [jsonDict objectForKey:@"dn"];
            NSString *status = [jsonDict objectForKey:@"st"];
            if ([status isEqualToString:@"on"]) {
                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:@"上线了" fromMe:YES];
            } else {
                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:@"下线了" fromMe:YES];
            }
            chatMessage.isStatus = YES;
        } else {
            NSString *displayName = [jsonDict objectForKey:@"dn"];
            NSString *message = [jsonDict objectForKey:@"msg"];
            if ([displayName isEqualToString:MY_NAME]) {
                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:message fromMe:YES];
            } else {
                chatMessage = [[KAMessage alloc] initWithDisplayName:displayName Message:message fromMe:NO];
            }
        }
        
        if (chatMessage) {
            [_messages addObject:chatMessage];
//            [self.tableView beginUpdates];
            [self.tableView reloadData];
//            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_messages.count - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
            [self.tableView scrollRectToVisible:self.tableView.tableFooterView.frame animated:YES];
//            [self.tableView endUpdates];
        }
    }
}

- (void)onSessionMessageFailure:(AVSession *)session message:(NSString *)message toPeerIds:(NSArray *)peerIds {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)onSessionMessageSent:(AVSession *)session message:(NSString *)message toPeerIds:(NSArray *)peerIds{
    NSLog(@"on session message sent %@", message);
}

- (void)onSessionStatusOnline:(AVSession *)session peers:(NSArray *)peerIds {
    NSLog(@"on Online, %@", peerIds);
}

- (void)onSessionStatusOffline:(AVSession *)session peers:(NSArray *)peerId {
    NSLog(@"on Offline, %@", peerId);
}

- (void)onSessionError:(AVSession *)session withException:(NSException *)exception {
    NSLog(@"%@", exception);
}

#pragma mark - AVSignatureDelegate
- (AVSignature *)createSessionSignature:(NSString *)peerId watchedPeerIds:(NSArray *)watchedPeerIds action:(NSString *)action {
    NSString *appId = @"19y77w6qkz7k5h1wifou7lwnrxf9i3g4qdpxb4k1yeuvjgp7";
    
    AVSignature *signature = [[AVSignature alloc] init];
    signature.timestamp = [[NSDate date] timeIntervalSince1970];
    signature.nonce = @"ForeverAlone";
    
    NSArray *sortedArray = [watchedPeerIds sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    
    signature.signedPeerIds = sortedArray;
    
    NSMutableArray *tempArray = [[NSMutableArray alloc] init];
    [tempArray addObject:appId];
    [tempArray addObject:peerId];
    
    if ([sortedArray count]> 0) {
        [tempArray addObjectsFromArray:sortedArray];
    } else {
        [tempArray addObject:@""];
    }
    
    [tempArray addObject:@(signature.timestamp)];
    [tempArray addObject:signature.nonce];
    
    NSString *message = [tempArray componentsJoinedByString:@":"];
    NSString *secret = @"此处应该是 masterKey";
    signature.signature = [self hmacsha1:message key:secret];
    signature.action = action;
    
    return signature;
}

- (NSString *)hmacsha1:(NSString *)text key:(NSString *)secret {
    NSData *secretData = [secret dataUsingEncoding:NSUTF8StringEncoding];
    NSData *clearTextData = [text dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char result[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, [secretData bytes], [secretData length], [clearTextData bytes], [clearTextData length], result);
    
    return [self hexStringWithData:result ofLength:CC_SHA1_DIGEST_LENGTH];
}

- (NSString*) hexStringWithData:(unsigned char*) data ofLength:(NSUInteger)len {
    NSMutableString *tmp = [NSMutableString string];
    for (NSUInteger i=0; i<len; i++)
        [tmp appendFormat:@"%02x", data[i]];
    return [NSString stringWithString:tmp];
}

#pragma mark - UIBarButtonItem Event Handler

- (void)refreshButtonClicked:(id)sender {
    [self refreshSession];
}

- (void)hideKeyboard:(UITapGestureRecognizer *)sender {
    [self.inputView resignFirstResponder];
}
- (void)keyboardWillHide:(NSNotification *)notification
{
//    UIScrollView *scrollView = (UIScrollView *)self.view;
//    scrollView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
//    scrollView.scrollIndicatorInsets = scrollView.contentInset;
    CGRect rect = self.view.frame;
    rect.size.height -= 100;
    self.tableView.frame = rect;
    rect = self.view.frame;
    self.inputView.frame = CGRectMake(0, rect.size.height - 100, rect.size.width, 40);
}

- (void)keyboardDidShow:(NSNotification *)notification
{
    // keyboard frame is in window coordinates
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    // convert own frame to window coordinates, frame is in superview's coordinates
    CGRect ownFrame = [self.view.window convertRect:self.view.frame fromView:self.view.superview];
    
    // calculate the area of own frame that is covered by keyboard
    CGRect coveredFrame = CGRectIntersection(ownFrame, keyboardFrame);
    
    // now this might be rotated, so convert it back
    coveredFrame = [self.view.window convertRect:coveredFrame toView:self.view.superview];
    
    UIView *view = self.tableView;
    CGRect rect = self.view.frame;
    rect.size.height -= 100;
    rect.size.height -= coveredFrame.size.height;
    view.frame = rect;
    
    view = self.inputView;
    rect = self.view.frame;
    rect = CGRectMake(0, rect.size.height - 100, rect.size.width, 40);
    rect.origin.y -= coveredFrame.size.height;
    view.frame = rect;
    // set inset to make up for covered array at bottom
//    scrollView.contentInset = UIEdgeInsetsMake(0, 0, coveredFrame.size.height, 0);
//    scrollView.scrollIndicatorInsets = scrollView.contentInset;
}
@end
