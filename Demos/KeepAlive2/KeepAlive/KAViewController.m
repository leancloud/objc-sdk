//
//  KAViewController.m
//  KeepAlive
//
//  Created by yang chaozhong on 5/22/14.
//  Copyright (c) 2014 avoscloud. All rights reserved.
//

#import "KAViewController.h"
#import "KAChatCell.h"
#import <AVOSCloud/AVOSCloud.h>
#import <CommonCrypto/CommonHMAC.h>

#define MY_NAME @"cyang"

@interface KAMessage : NSObject

- (id)initWithMessage:(NSString *)message fromMe:(BOOL)fromMe;

@property (nonatomic, retain, readonly) NSString *message;
@property (nonatomic, readonly) BOOL fromMe;

@end

@implementation KAMessage

- (id)initWithMessage:(NSString *)message fromMe:(BOOL)fromMe;
{
    self = [super init];
    if (self) {
        _fromMe = fromMe;
        _message = message;
    }
    
    return self;
}

@end

@interface KAViewController () <UITextViewDelegate, AVSessionDelegate, AVSignatureDelegate>
- (IBAction)refreshButtonClicked:(id)sender;

@property (strong, nonatomic) IBOutlet UITextView *inputView;

@end

@implementation KAViewController {
    NSMutableArray *_messages;
    AVSession *_session;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _inputView.delegate = self;
    _messages = [[NSMutableArray alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self refreshSession];
    
    [_inputView becomeFirstResponder];
}

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

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
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

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    KAChatCell *chatCell = (id)cell;
    KAMessage *message = [_messages objectAtIndex:indexPath.row];
    chatCell.textView.text = message.message;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KAMessage *message = [_messages objectAtIndex:indexPath.row];

    return [self.tableView dequeueReusableCellWithIdentifier:message.fromMe ? @"SentCell" : @"ReceivedCell"];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
{
    if ([text rangeOfString:@"\n"].location != NSNotFound) {
        NSString *message = [[textView.text stringByReplacingCharactersInRange:range withString:text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        [_session sendMessage:[NSString stringWithFormat:@"{\"dn\":\"%@\", \"msg\":\"%@\"}", MY_NAME, message] isTransient:NO toPeerIds:_session.getAllPeers];
        
        [_messages addObject:[[KAMessage alloc] initWithMessage:[NSString stringWithFormat:@"%@:%@", MY_NAME, message] fromMe:YES]];
        
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_messages.count - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView scrollRectToVisible:self.tableView.tableFooterView.frame animated:YES];
        
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
                chatMessage = [[KAMessage alloc] initWithMessage:[NSString stringWithFormat:@"%@上线了", displayName] fromMe:NO];
            } else {
                chatMessage = [[KAMessage alloc] initWithMessage:[NSString stringWithFormat:@"%@下线了", displayName] fromMe:NO];
            }
        } else {
            NSString *displayName = [jsonDict objectForKey:@"dn"];
            NSString *message = [jsonDict objectForKey:@"msg"];
            if ([displayName isEqualToString:MY_NAME]) {
                chatMessage = [[KAMessage alloc] initWithMessage:[NSString stringWithFormat:@"%@:%@", displayName, message] fromMe:YES];
            } else {
                chatMessage = [[KAMessage alloc] initWithMessage:[NSString stringWithFormat:@"%@:%@", displayName, message] fromMe:NO];
            }
        }
        
        if (chatMessage) {
            [_messages addObject:chatMessage];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_messages.count - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
            [self.tableView scrollRectToVisible:self.tableView.tableFooterView.frame animated:YES];
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
- (AVSignature *)createSignature:(NSString *)peerId watchedPeerIds:(NSArray *)watchedPeerIds {
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

- (IBAction)refreshButtonClicked:(id)sender {
    [self refreshSession];
}

@end