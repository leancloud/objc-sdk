//
//  LCQuery_Internal.h
//  Paas
//
//  Created by Zhu Zeng on 3/28/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>

@interface LCQuery ()
@property (nonatomic, readwrite, strong) NSMutableDictionary *parameters;
@property (nonatomic, readwrite, strong) NSMutableDictionary *where;
@property (nonatomic) NSMutableSet<NSString *> *selectedKeys;
@property (nonatomic, strong) NSMutableDictionary *extraParameters;
@property (nonatomic) NSString *endpoint;

- (NSMutableDictionary *)assembleParameters;
+ (NSDictionary *)dictionaryFromIncludeKeys:(NSArray *)array;
- (NSString *)queryPath;
-(void)queryWithBlock:(NSString *)path
           parameters:(NSDictionary *)parameters
                block:(LCArrayResultBlock)resultBlock;
- (LCObject *)getFirstObjectWithBlock:(LCObjectResultBlock)resultBlock
                        waitUntilDone:(BOOL)wait
                                error:(NSError **)theError;

/**
 *  Convert server response json to LCObjects. Indend to be overridden.
 *  @param results "results" value of the server response.
 *  @param className The class name for parsing. If nil, the query's className will be used.
 *  @return LCObject array.
 */
- (NSMutableArray *)processResults:(NSArray *)results className:(NSString *)className;

/**
 *  Process end value of server response. Used in LCStatusQuery.
 *  @param end end value
 */
- (void)processEnd:(BOOL)end;

/**
 * Get JSON-compatible dictionary of where constraints.
 */
- (NSDictionary *)whereJSONDictionary;

@end
