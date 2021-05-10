//
//  LCCloudQueryResult_Internal.h
//  LeanCloud
//
//  Created by Qihe Bian on 9/22/14.
//
//

#import <Foundation/Foundation.h>
#import "LCCloudQueryResult.h"

@interface LCCloudQueryResult()
- (void)setClassName:(NSString *)className;
- (void)setCount:(NSUInteger)count;
- (void)setResults:(NSArray *)results;
@end
