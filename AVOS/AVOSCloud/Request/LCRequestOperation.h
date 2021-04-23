//
//  LCRequestOperation.h
//  AVOSCloud
//
//  Created by Zhu Zeng on 7/9/13.
//  Copyright (c) 2013 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVConstants.h"

@interface LCRequestOperation : NSObject

@property (nonatomic, readwrite, strong) NSMutableArray * batchRequest;
@property (nonatomic, readwrite, copy) AVBooleanResultBlock block;
@property (nonatomic, readwrite) int sequence;

+(LCRequestOperation *)operation:(NSArray *)request;

@end


@interface LCRequestOperationQueue : NSObject

@property (nonatomic, readwrite) NSMutableArray * queue;
@property (nonatomic, readwrite) int currentSequence;

-(void)increaseSequence;
-(LCRequestOperation *)addOperation:(NSArray *)request
                   withBlock:(AVBooleanResultBlock)block;
-(LCRequestOperation *)popHead;
-(BOOL)noPendingRequest;
-(void)clearOperationWithSequence:(int)seq;

@end
