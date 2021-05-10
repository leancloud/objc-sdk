//
//  LCCloudQueryResult.m
//  LeanCloud
//
//  Created by Qihe Bian on 9/22/14.
//
//

#import "LCCloudQueryResult.h"
#import "LCCloudQueryResult_Internal.h"

@implementation LCCloudQueryResult

- (void)setClassName:(NSString *)className {
    _className = className;
}

- (void)setResults:(NSArray *)results {
    _results = results;
}

- (void)setCount:(NSUInteger)count {
    _count = count;
}
@end
