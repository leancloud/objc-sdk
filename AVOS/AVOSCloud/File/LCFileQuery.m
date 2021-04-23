//
//  LCFileQuery.m
//  AVOS-DynamicFramework
//
//  Created by lzw on 15/10/8.
//  Copyright © 2015年 tang3w. All rights reserved.
//

#import "LCFileQuery.h"
#import "LCFile.h"
#import "AVQuery_Internal.h"
#import "AVUtils.h"

@implementation LCFileQuery

+ (instancetype)query {
    return [self queryWithClassName:@"_File"];
}
- (NSArray *)filesWithObjects:(NSArray *)objects {
    if (objects == nil) {
        return nil;
    }
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:objects.count];
    for (LCObject *object in [objects copy]) {
        LCFile *file = [LCFile fileWithObject:object];
        [files addObject:file];
    }
    return files;
}

- (void)getFileInBackgroundWithId:(NSString *)objectId
                            block:(LCFileResultBlock)block {
    [self getObjectInBackgroundWithId:objectId block:^(LCObject *object, NSError *error) {
        LCFile *file = nil;
        if (!error) {
            file = [LCFile fileWithObject:object];
        }
        [AVUtils callFileResultBlock:block file:file error:error];
    }];
}

- (LCFile *)getFileWithId:(NSString *)objectId error:(NSError **)error {
    LCObject *object = [self getObjectWithId:objectId error:error];
    LCFile *file = nil;
    if (object != nil) {
        file = [LCFile fileWithObject:object];
    }
    return file;
}

- (NSArray *)findFiles:(NSError **)error {
    NSArray *objects = [super findObjects:error];
    return [self filesWithObjects:objects];
}

- (void)findFilesInBackgroundWithBlock:(AVArrayResultBlock)resultBlock {
    [self findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        NSArray *files = [self filesWithObjects:objects];
        [AVUtils callArrayResultBlock:resultBlock array:files error:error];
    }];
}

@end
