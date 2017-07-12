//
//  AVNamedTable.h
//  AVOS
//
//  Created by Tang Tianyong on 27/04/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 AVNamedTable defines an object acts like a dictionary.
 As extra benefits, you can subclass it and add some named properties,
 then, all named properties support copy and encoding automatically like a charm.
 */
@interface AVNamedTable : NSObject <NSCopying, NSSecureCoding>

- (nullable id)objectForKey:(NSString *)key;

- (void)setObject:(nullable id)object forKey:(NSString *)key;

- (nullable id)objectForKeyedSubscript:(NSString *)key;

- (void)setObject:(nullable id)object forKeyedSubscript:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
