//
//  LCLogger.h
//  LeanCloud
//
//  Created by Qihe Bian on 9/9/14.
//
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    LCLoggerLevelNone = 0,
    LCLoggerLevelInfo = 1,
    LCLoggerLevelDebug = 1 << 1,
    LCLoggerLevelError = 1 << 2,
    LCLoggerLevelAll = LCLoggerLevelInfo | LCLoggerLevelDebug | LCLoggerLevelError,
} LCLoggerLevel;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const LCLoggerDomainCURL;
extern NSString *const LCLoggerDomainNetwork;
extern NSString *const LCLoggerDomainIM;
extern NSString *const LCLoggerDomainStorage;
extern NSString *const LCLoggerDomainDefault;

@interface LCLogger : NSObject
+ (void)setAllLogsEnabled:(BOOL)enabled;
+ (void)setLoggerLevelMask:(NSUInteger)levelMask;
+ (void)addLoggerDomain:(NSString *)domain;
+ (void)removeLoggerDomain:(NSString *)domain;
+ (void)logFunc:(const char *)func line:(const int)line domain:(nullable NSString *)domain level:(LCLoggerLevel)level message:(NSString *)fmt, ... NS_FORMAT_FUNCTION(5, 6);
+ (BOOL)levelEnabled:(LCLoggerLevel)level;
+ (BOOL)containDomain:(NSString *)domain;
@end

NS_ASSUME_NONNULL_END

#define _LCLoggerInfo(_domain, ...) [LCLogger logFunc:__func__ line:__LINE__ domain:_domain level:LCLoggerLevelInfo message:__VA_ARGS__]
#define _LCLoggerDebug(_domain, ...) [LCLogger logFunc:__func__ line:__LINE__ domain:_domain level:LCLoggerLevelDebug message:__VA_ARGS__]
#define _LCLoggerError(_domain, ...) [LCLogger logFunc:__func__ line:__LINE__ domain:_domain level:LCLoggerLevelError message:__VA_ARGS__]

#define LCLoggerInfo(domain, ...) _LCLoggerInfo(domain, __VA_ARGS__)
#define LCLoggerDebug(domain, ...) _LCLoggerDebug(domain, __VA_ARGS__)
#define LCLoggerError(domain, ...) _LCLoggerError(domain, __VA_ARGS__)

#define LCLoggerI(...) LCLoggerInfo(LCLoggerDomainDefault, __VA_ARGS__)
#define LCLoggerD(...) LCLoggerDebug(LCLoggerDomainDefault, __VA_ARGS__)
#define LCLoggerE(...) LCLoggerError(LCLoggerDomainDefault, __VA_ARGS__)
