//
//  LCChatDetailForm.m
//  ChatApp
//
//  Created by Qihe Bian on 12/31/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "LCChatDetailForm.h"
#import "LCChatMemberListCell.h"
#import "LCMemberListController.h"

@implementation LCChatDetailForm
- (NSDictionary *)nameField {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:@"name" forKey:FXFormFieldKey];
    if (self.name) {
        [dict setObject:self.name forKey:FXFormFieldDefaultValue];
    }
    return dict;
}

- (NSDictionary *)conversationField {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:@"conversation" forKey:FXFormFieldKey];
    if (self.conversation) {
        [dict setObject:@"成员列表" forKey:FXFormFieldTitle];
        [dict setObject:self.conversation forKey:@"conversation"];
        [dict setObject:[LCChatMemberListCell class] forKey:FXFormFieldCell];
        [dict setObject:[LCMemberListController class] forKey:FXFormFieldViewController];
    }
    return dict;
}

//- (NSArray *)fields {
//    return @[@{FXFormFieldKey: @"name", FXFormFieldType:FXFormFieldTypeText,
//               FXFormFieldDefaultValue:self.name}];
//}
@end
