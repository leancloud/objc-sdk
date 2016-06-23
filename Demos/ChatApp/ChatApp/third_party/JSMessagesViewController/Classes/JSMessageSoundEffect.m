//
//  Created by Jesse Squires
//  http://www.hexedbits.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSMessagesViewController
//
//
//  The MIT License
//  Copyright (c) 2013 Jesse Squires
//  http://opensource.org/licenses/MIT
//

#import "JSMessageSoundEffect.h"
#import "JSQSystemSoundPlayer.h"

static NSString * const kJSMessageReceived = @"message-received";
static NSString * const kJSMessageSent = @"message-sent";

@implementation JSMessageSoundEffect

+ (void)playMessageReceivedSound
{
    [[JSQSystemSoundPlayer sharedPlayer] playSoundWithFilename:kJSMessageReceived fileExtension:kJSQSystemSoundTypeAIFF];
//    [[JSQSystemSoundPlayer sharedPlayer] playSoundWithName:kJSMessageReceived
//                                                 fileExtension:kJSQSystemSoundTypeAIFF];
}

+ (void)playMessageReceivedAlert
{
    [[JSQSystemSoundPlayer sharedPlayer] playAlertSoundWithFilename:kJSMessageReceived
                                                      fileExtension:kJSQSystemSoundTypeAIFF];
}

+ (void)playMessageSentSound
{
    [[JSQSystemSoundPlayer sharedPlayer] playSoundWithFilename:kJSMessageSent
                                                 fileExtension:kJSQSystemSoundTypeAIFF];
}

+ (void)playMessageSentAlert
{
    [[JSQSystemSoundPlayer sharedPlayer] playAlertSoundWithFilename:kJSMessageSent
                                                      fileExtension:kJSQSystemSoundTypeAIFF];
}

@end