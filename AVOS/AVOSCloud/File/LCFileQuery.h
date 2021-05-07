//
//  LCFileQuery.h
//  LeanCloud-DynamicFramework
//
//  Created by lzw on 15/10/8.
//  Copyright © 2015年 tang3w. All rights reserved.
//

#import "LCQuery.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  LCFile 查询类
 */
@interface LCFileQuery : LCQuery

+ (instancetype)query;

/**
 *  查找一组文件，同步方法
 *  @param error 通常是网络错误或者查找权限未开启
 *  @return 返回一组 LCFile 对象
 */
- (nullable NSArray *)findFiles:(NSError **)error;

/**
 *  查找一组文件，异步方法
 *  @see findFiles:
 *  @param resultBlock 回调 block
 */
- (void)findFilesInBackgroundWithBlock:(LCArrayResultBlock)resultBlock;


/**
 *  根据 objectId 来查找文件，同步方法
 *  @param objectId 目标文件的 objectId
 *  @param error    通过是网络错误或查找权限未开启
 *  @return 返回 LCFile 对象
 */
- (nullable LCFile *)getFileWithId:(NSString *)objectId error:(NSError **)error;

/**
 *  根据 objectId 来查找文件，异步方法
 *  @see getFileWithId:error
 *  @param objectId 目标文件的 objectId
 *  @param block    回调 block
 */
- (void)getFileInBackgroundWithId:(NSString *)objectId
                            block:(LCFileResultBlock)block;


@end

NS_ASSUME_NONNULL_END
