//
//  AVHelpers.h
//  paas
//
//  Created by Travis on 13-12-17.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (AVBase64)

/* 根据传入的base64编码字符串生成NSData
 * @param aString 需要转换的base64格式字符串
 * @return 返回生成的data
 */
+ (NSData *)AVdataFromBase64String:(NSString *)aString;

/* 获得当前data的base64编码字符串 */
- (NSString *)AVbase64EncodedString;

@end

@interface NSString (AVMD5)

/* 返回当前字符串的*大写*MD5值
 * @return 返回当前字符串的*大写*MD5值
 */
- (NSString *)AVMD5String;

@end


@interface NSURLRequest (curl)
/* 获得当前请求的curl命令行代码, 方便命令行调试 对比结果
 * @return 当前请求的curl命令行代码
 */
- (NSString *)cURLCommand;
@end
