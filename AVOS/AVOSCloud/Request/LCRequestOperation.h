//
//  LCRequestOperation.h
//  LeanCloud
//
//  Created by Zhu Zeng on 7/9/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LCConstants.h"

@interface LCRequestOperation : NSObject

@property (nonatomic, readwrite, strong) NSMutableArray * batchRequest;
@property (nonatomic, readwrite, copy) LCBooleanResultBlock block;
@property (nonatomic, readwrite) int sequence;

+(LCRequestOperation *)operation:(NSArray *)request;

@end


@interface LCRequestOperationQueue : NSObject

@property (nonatomic, readwrite) NSMutableArray * queue;
@property (nonatomic, readwrite) int currentSequence;

-(void)increaseSequence;
-(LCRequestOperation *)addOperation:(NSArray *)request
                   withBlock:(LCBooleanResultBlock)block;
-(LCRequestOperation *)popHead;
-(BOOL)noPendingRequest;
-(void)clearOperationWithSequence:(int)seq;

@end
