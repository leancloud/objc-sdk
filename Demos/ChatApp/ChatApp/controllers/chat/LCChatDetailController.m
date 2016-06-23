//
//  LCChatDetailController.m
//  ChatApp
//
//  Created by Qihe Bian on 12/31/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCChatDetailController.h"
#import "LCChatDetailForm.h"
#import "LCIMClient.h"

@interface LCChatDetailController ()

@end

@implementation LCChatDetailController

- (id)initWithConversation:(AVIMConversation *)conversation {
    if ((self = [super init])) {
        self.conversation = conversation;
        LCChatDetailForm *form = [[LCChatDetailForm alloc] init];
        form.name = conversation.name;
        form.conversation = conversation;
        self.formController.form = form;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)done:(id)sender {
    LCChatDetailForm *form = self.formController.form;
    NSLog(@"name:%@", form.name);
    [[LCIMClient sharedInstance] updateConversation:self.conversation withName:form.name attributes:nil callback:^(BOOL succeeded, NSError *error) {
        
    }];
}

@end
