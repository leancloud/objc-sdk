//
//  LCLogger.m
//  AVOS
//
//  Created by Qihe Bian on 9/9/14.
//
//

#import "LCLogger.h"

NSString *const LCLoggerDomainCURL = @"LOG_CURL";
NSString *const LCLoggerDomainNetwork = @"LOG_NETWORK";
NSString *const LCLoggerDomainStorage = @"LOG_STORAGE";
NSString *const LCLoggerDomainIM = @"LOG_IM";
NSString *const LCLoggerDomainDefault = @"LOG_DEFAULT";

static NSMutableSet *loggerDomain = nil;
static NSUInteger loggerLevelMask = LCLoggerLevelNone;
static NSArray *loggerDomains = nil;

@implementation LCLogger

+ (void)load {
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        loggerDomains = @[
                          LCLoggerDomainCURL,
                          LCLoggerDomainNetwork,
                          LCLoggerDomainIM,
                          LCLoggerDomainStorage,
                          LCLoggerDomainDefault
                          ];
    });
#ifdef DEBUG
    [self setAllLogsEnabled:YES];
#else
    [self setAllLogsEnabled:NO];
#endif
}

+ (void)setAllLogsEnabled:(BOOL)enabled {
    if (enabled) {
        for (NSString *loggerDomain in loggerDomains) {
            [LCLogger addLoggerDomain:loggerDomain];
        }
        [LCLogger setLoggerLevelMask:LCLoggerLevelAll];
    } else {
        for (NSString *loggerDomain in loggerDomains) {
            [LCLogger removeLoggerDomain:loggerDomain];
        }
        [LCLogger setLoggerLevelMask:LCLoggerLevelNone];
    }

    [self setCertificateInspectionEnabled:enabled];
}

+ (void)setCertificateInspectionEnabled:(BOOL)enabled {
    if (enabled) {
        setenv("CURL_INSPECT_CERT", "YES", 1);
    } else {
        unsetenv("CURL_INSPECT_CERT");
    }
}

+ (void)setLoggerLevelMask:(NSUInteger)levelMask {
    loggerLevelMask = levelMask;
}

+ (void)addLoggerDomain:(NSString *)domain {
    if (!loggerDomain) {
        loggerDomain = [[NSMutableSet alloc] init];
    }
    [loggerDomain addObject:domain];
}

+ (void)removeLoggerDomain:(NSString *)domain {
    [loggerDomain removeObject:domain];
}

+ (BOOL)levelEnabled:(LCLoggerLevel)level {
    return loggerLevelMask & level;
}

+ (BOOL)containDomain:(NSString *)domain {
    return [loggerDomain containsObject:domain];
}

+ (void)logFunc:(const char *)func line:(int)line domain:(NSString *)domain level:(LCLoggerLevel)level message:(NSString *)fmt, ... {
    if (!domain || [loggerDomain containsObject:domain]) {
        if (level & loggerLevelMask) {
            NSString *symbol = nil;
            NSString *levelString = nil;
            switch (level) {
                case LCLoggerLevelInfo:
                    symbol = @"💙";
                    levelString = @"Info";
                    break;
                case LCLoggerLevelDebug:
                    symbol = @"💚";
                    levelString = @"Debug";
                    break;
                case LCLoggerLevelError:
                    symbol = @"❤️";
                    levelString = @"Error";
                    break;
                default:
                    symbol = @"🧡";
                    levelString = @"Unknown";
                    break;
            }
            va_list args;
            va_start(args, fmt);
            NSString *message = [[NSString alloc] initWithFormat:fmt arguments:args];
            va_end(args);
            NSLog(@"[%@][%@] %s [Line %d]: %@", symbol, levelString, func, line, message);
        }
    }
}

@end
