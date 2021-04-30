//
//  LCRequestOperation.m
//  AVOSCloud
//
//  Created by Zhu Zeng on 7/9/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import "LCRequestOperation.h"

@implementation LCRequestOperation

-(id)init
{
    self = [super init];
    _batchRequest = [[NSMutableArray alloc] init];
    return self;
}

+(LCRequestOperation *)operation:(NSArray *)request
{
    LCRequestOperation * operation = [[LCRequestOperation alloc] init];
    [operation.batchRequest addObjectsFromArray:request];
    return operation;
}

@end

@implementation LCRequestOperationQueue

@synthesize queue = _queue;

-(id)init
{
    self = [super init];
    _queue = [[NSMutableArray alloc] init];
    return self;
}

-(void)increaseSequence
{
    self.currentSequence += 2;
}

-(LCRequestOperation *)addOperation:(NSArray *)request
                   withBlock:(LCBooleanResultBlock)block
{
    LCRequestOperation * operation = [LCRequestOperation operation:[request mutableCopy]];
    operation.sequence = self.currentSequence;
    operation.block = block;
    [self.queue addObject:operation];
    [self increaseSequence];
    return operation;
}

-(LCRequestOperation *)popHead
{
    if (self.queue.count > 0) {
        LCRequestOperation * operation = [self.queue objectAtIndex:0];
        [self.queue removeObjectAtIndex:0];
        return operation;
    }
    return nil;
}

-(BOOL)noPendingRequest
{
    return (self.queue.count <= 0);
}

-(void)clearOperationWithSequence:(int)seq
{
    NSMutableArray *discardedItems = [NSMutableArray array];
    for (LCRequestOperation * operation in self.queue) {
        if (operation.sequence == seq)
            [discardedItems addObject:operation];
    }
    
    [self.queue removeObjectsInArray:discardedItems];
}

@end

