//
//  LCUtils.m
//  paas
//
//  Created by Zhu Zeng on 2/27/13.
//  Copyright (c) 2013 LeanCloud. All rights reserved.
//

#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#import "LCUtils_Internal.h"
#import "LCHelpers.h"
#import "LCLogger.h"
#import "LCObject_Internal.h"
#import "LCGeoPoint_Internal.h"
#import "LCUser_Internal.h"
#import "LCRole_Internal.h"
#import "LCFile_Internal.h"
#import "LCObjectUtils.h"
#import "LCPaasClient.h"
#import "LCCloudQueryResult.h"
#import "LCKeychain.h"
#import "LCURLConnection.h"

static char base62_tab[62] = {
    'A','B','C','D','E','F','G','H',
    'I','J','K','L','M','N','O','P',
    'Q','R','S','T','U','V','W','X',
    'Y','Z','a','b','c','d','e','f',
    'g','h','i','j','k','l','m','n',
    'o','p','q','r','s','t','u','v',
    'w','x','y','z','0','1','2','3',
    '4','5','6','7','8','9'
};

static int b62_encode(char* out, const void *data, int length)
{
    int i,j;
    char *start = out;
    uint64_t bitstring;
    const unsigned char *s = (const unsigned char *)data;
    for (i=0;i<length-4;i+=5) {
        bitstring =
        (uint64_t)s[i]<<32|(uint64_t)s[i+1]<<24|(uint64_t)s[i+2]<<16|
        (uint64_t)s[i+3]<<8|(uint64_t)s[i+4];
        
        for (j=0;j<7;++j) {
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
        }
        /*
         b62_divide(quotient,len,quotient,&rem);
         *out++ = base62_tab[rem];
         for (j=1;j<len;++j) {
         b62_divide(quotient,len,quotient,&rem);
         *out++ = base62_tab[rem];
         }*/
    }
    switch (length-i) {
        case 1:
            *out++ = base62_tab[s[i]%62];
            *out++ = base62_tab[s[i]/62];
            break;
        case 2:
            bitstring = s[i]<<8|s[i+1];
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
            *out++ = base62_tab[bitstring%62];
            *out++ = base62_tab[bitstring/62];
            break;
        case 3:
            bitstring = s[i]<<16|s[i+1]<<8|s[i];
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
            *out++ = base62_tab[bitstring%62];
            *out++ = base62_tab[bitstring/62];
            break;
        case 4:
            bitstring = s[i]<<24|s[i+1]<<16|s[i+2]<<8|s[i];
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
            *out++ = base62_tab[bitstring%62];
            bitstring /= 62;
            *out++ = base62_tab[bitstring%62];
            *out++ = base62_tab[bitstring/62];
            break;
    }
    return (int)(out-start);
}

@implementation LCUtils

+ (void)warnMainThreadIfNecessary {
    if ([NSThread isMainThread]) {
        LCLoggerI(@"Warning: A long-running Paas operation is being executed on the main thread.");
    }
}

+ (BOOL)containsProperty:(NSString *)name inClass:(Class)objectClass containSuper:(BOOL)containSuper filterDynamic:(BOOL)filterDynamic {
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(objectClass, &outCount);
    for(i = 0; i < outCount; i++) {
    	objc_property_t property = properties[i];
        
        if (filterDynamic) {
            char *dynamic = property_copyAttributeValue(property, "D");
            if (dynamic) {
                free(dynamic);
                continue;
            }
            
        }
        
        const char *propName = property_getName(property);
    	if (propName) {
    		NSString *propertyName = [NSString stringWithCString:propName encoding:NSUTF8StringEncoding];
            if ([name isEqualToString:propertyName])
            {
                free(properties);
                return YES;
            }
        }
    }
    free(properties);
    // isSubclassOfClass : a subclass of, or identical to, a given class.
    // 如果是 LCObject 类或者是其子类，则遍历。不遍历 NSObject。
    if (containSuper && [[objectClass superclass] isSubclassOfClass:[LCObject class]])
    {
        return [LCUtils containsProperty:name inClass:[objectClass superclass] containSuper:containSuper filterDynamic:filterDynamic];
    }
    return NO;
}

+ (BOOL)isDynamicProperty:(NSString *)name
                  inClass:(Class)objectClass
                 withType:(Class)targetClass
             containSuper:(BOOL)containSuper {
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(objectClass, &outCount);
    for(i = 0; i < outCount; i++) {
    	objc_property_t property = properties[i];
        const char *propName = property_getName(property);
    	if (propName == nil) {
            continue;
        }
        NSString *propertyName = [NSString stringWithCString:propName encoding:NSUTF8StringEncoding];
        if ([propertyName isEqualToString:name]) {
            char *dynamic = property_copyAttributeValue(property, "D");
            const char * attributes = property_getAttributes(property);
            NSString *attributesName = [NSString stringWithCString:attributes encoding:NSUTF8StringEncoding];
            NSString * className = NSStringFromClass(targetClass);
            NSRange range = [attributesName rangeOfString:className];
            if (range.location <= 3 && range.length == className.length && dynamic) {
                free(dynamic);
                free(properties);
                return true;
            }
            if (dynamic) {
                free(dynamic);
            }
        }
    }
    free(properties);
    if (containSuper && [objectClass isSubclassOfClass:[LCObject class]])
    {
        return [LCUtils isDynamicProperty:name inClass:[objectClass superclass] withType:targetClass containSuper:containSuper];
    }
    return NO;
}

+ (NSString *)jsonStringFromDictionary:(NSDictionary *)dictionary {
    if (![NSDictionary _lc_isTypeOf:dictionary]) {
        return nil;
    }
    return [self jsonStringFromJSONObject:dictionary];
}

+ (NSString *)jsonStringFromArray:(NSArray *)array {
    if (![NSArray _lc_isTypeOf:array]) {
        return nil;
    }
    return [self jsonStringFromJSONObject:array];
}

+ (NSString *)jsonStringFromJSONObject:(id)JSONObject {
    if (JSONObject == nil) {
        return nil;
    }
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error];
    if (error) {
        LCLoggerE(@"%@", error);
    }
    if (data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}

+ (NSString *)generateUUID {
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString * string = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
    string = [string lowercaseString];
    CFRelease(theUUID);
    return string;
}

+ (NSString *)generateCompactUUID {
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFUUIDBytes bytes = CFUUIDGetUUIDBytes(uuid);
    CFRelease(uuid);
    char buf[24];
    memset(buf, 0, sizeof(buf));
    int len = b62_encode(buf, &bytes, sizeof(bytes));
    assert(len == 23);
    return [[NSString alloc] initWithFormat:@"%s", buf];
}

+ (NSString *)deviceUUIDKey {
    static NSString *const suffix = @"@leancloud";
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleIdentifier) {
        return [bundleIdentifier stringByAppendingString:suffix];
    } else {
        return suffix; /* Bundle identifier is nil in unit test. */
    }
}

+ (dispatch_queue_t)defaultSerialQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("cn.leancloud.utils", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

+ (NSString *)deviceUUID {
    static NSString *UUID;
    if (!UUID) {
        dispatch_sync([self defaultSerialQueue], ^{
            NSString *key = [self deviceUUIDKey];
            NSString *savedUUID = [LCKeychain loadValueForKey:key];
            if (savedUUID) {
                UUID = savedUUID;
            } else {
                NSString *tempUUID = [self generateUUID];
                if (tempUUID) {
                    [LCKeychain saveValue:tempUUID forKey:key];
                    UUID = tempUUID;
                }
            }
        });
    }
    return UUID;
}

+ (dispatch_queue_t)asynchronousTaskQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("avos.common.dispatchQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    return queue;
}

+ (void)asynchronizeTask:(void (^)(void))task {
    NSAssert(task != nil, @"Task cannot be nil.");
    dispatch_async([self asynchronousTaskQueue], ^{
        task();
    });
}

+ (NSString *)MIMEType:(NSString *)filePathOrName {
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[filePathOrName pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    return MIMEType ? (__bridge_transfer NSString *)MIMEType : @"application/octet-stream";
}

+ (NSString *)MIMETypeFromPath:(NSString *)fullPath {
    NSURL *fileUrl = [NSURL fileURLWithPath:fullPath];
    NSURLRequest *fileUrlRequest = [[NSURLRequest alloc] initWithURL:fileUrl cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:.1];
    NSError *error;
    NSURLResponse *response;
    [LCURLConnection sendSynchronousRequest:fileUrlRequest returningResponse:&response error:&error];
    return [response MIMEType];
}

+ (NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
    }
    return nil;
}

// MARK: Call block

#define safeBlock(first_param) \
if (block) { \
    if ([NSThread isMainThread]) { \
        block(first_param, error); \
    } else {\
        dispatch_async(dispatch_get_main_queue(), ^{ \
            block(first_param, error); \
        }); \
    } \
}

+ (void)callBooleanResultBlock:(LCBooleanResultBlock)block error:(NSError *)error {
    safeBlock(error == nil);
}

+ (void)callIntegerResultBlock:(LCIntegerResultBlock)block number:(NSInteger)number error:(NSError *)error {
    safeBlock(number);
}

+ (void)callStringResultBlock:(LCStringResultBlock)block string:(NSString *)string error:(NSError *)error {
    safeBlock(string);
}

+ (void)callDataResultBlock:(LCDataResultBlock)block data:(NSData *)data error:(NSError *)error {
    safeBlock(data);
}

+ (void)callArrayResultBlock:(LCArrayResultBlock)block array:(NSArray *)array error:(NSError *)error {
    safeBlock(array);
}

+ (void)callSetResultBlock:(LCSetResultBlock)block set:(NSSet *)set error:(NSError *)error {
    safeBlock(set);
}

+ (void)callDictionaryResultBlock:(LCDictionaryResultBlock)block dictionary:(NSDictionary *)dictionary error:(NSError *)error {
    safeBlock(dictionary);
}

+ (void)callIdResultBlock:(LCIdResultBlock)block object:(id)object error:(NSError *)error {
    safeBlock(object);
}

+ (void)callProgressBlock:(LCProgressBlock)block percent:(NSInteger)percent {
    if (block) {
        if ([NSThread isMainThread]) {
            block(percent);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                block(percent);
            });
        }
    }
}

+ (void)callObjectResultBlock:(LCObjectResultBlock)block object:(LCObject *)object error:(NSError *)error {
    safeBlock(object);
}

+ (void)callUserResultBlock:(LCUserResultBlock)block user:(LCUser *)user error:(NSError *)error {
    safeBlock(user);
}

+ (void)callFileResultBlock:(LCFileResultBlock)block file:(LCFile *)file error:(NSError *)error {
    safeBlock(file);
}

+ (void)callCloudQueryCallback:(LCCloudQueryCallback)block result:(LCCloudQueryResult *)result error:(NSError *)error {
    safeBlock(result);
}

@end

// MARK: Base64

//
// Mapping from 6 bit pattern to ASCII character.
//
static unsigned char base64EncodeLookup[65] =
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

//
// Definition for "masked-out" areas of the base64DecodeLookup mapping
//
#define xx 65

//
// Mapping from ASCII character to 6 bit pattern.
//
static unsigned char base64DecodeLookup[256] =
{
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 62, xx, xx, xx, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, xx, xx, xx, xx, xx, xx,
    xx,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, xx, xx, xx, xx, xx,
    xx, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
};

//
// Fundamental sizes of the binary and base64 encode/decode units in bytes
//
#define BINARY_UNIT_SIZE 3
#define BASE64_UNIT_SIZE 4

//
// NewBase64Decode
//
// Decodes the base64 ASCII string in the inputBuffer to a newly malloced
// output buffer.
//
//  inputBuffer - the source ASCII string for the decode
//	length - the length of the string or -1 (to specify strlen should be used)
//	outputLength - if not-NULL, on output will contain the decoded length
//
// returns the decoded buffer. Must be free'd by caller. Length is given by
//	outputLength.
//
void *avNewBase64Decode(
                        const char *inputBuffer,
                        size_t length,
                        size_t *outputLength)
{
	if (length == -1)
	{
		length = strlen(inputBuffer);
	}
	
	size_t outputBufferSize =
    ((length+BASE64_UNIT_SIZE-1) / BASE64_UNIT_SIZE) * BINARY_UNIT_SIZE;
	unsigned char *outputBuffer = (unsigned char *)malloc(outputBufferSize);
	
	size_t i = 0;
	size_t j = 0;
	while (i < length)
	{
		//
		// Accumulate 4 valid characters (ignore everything else)
		//
		unsigned char accumulated[BASE64_UNIT_SIZE];
		size_t accumulateIndex = 0;
		while (i < length)
		{
			unsigned char decode = base64DecodeLookup[inputBuffer[i++]];
			if (decode != xx)
			{
				accumulated[accumulateIndex] = decode;
				accumulateIndex++;
				
				if (accumulateIndex == BASE64_UNIT_SIZE)
				{
					break;
				}
			}
		}
		
		//
		// Store the 6 bits from each of the 4 characters as 3 bytes
		//
		// (Uses improved bounds checking suggested by Alexandre Colucci)
		//
		if(accumulateIndex >= 2)
			outputBuffer[j] = (accumulated[0] << 2) | (accumulated[1] >> 4);
		if(accumulateIndex >= 3)
			outputBuffer[j + 1] = (accumulated[1] << 4) | (accumulated[2] >> 2);
		if(accumulateIndex >= 4)
			outputBuffer[j + 2] = (accumulated[2] << 6) | accumulated[3];
		j += accumulateIndex - 1;
	}
	
	if (outputLength)
	{
		*outputLength = j;
	}
	return outputBuffer;
}

//
// NewBase64Encode
//
// Encodes the arbitrary data in the inputBuffer as base64 into a newly malloced
// output buffer.
//
//  inputBuffer - the source data for the encode
//	length - the length of the input in bytes
//  separateLines - if zero, no CR/LF characters will be added. Otherwise
//		a CR/LF pair will be added every 64 encoded chars.
//	outputLength - if not-NULL, on output will contain the encoded length
//		(not including terminating 0 char)
//
// returns the encoded buffer. Must be free'd by caller. Length is given by
//	outputLength.
//
char *avNewBase64Encode(
                        const void *buffer,
                        size_t length,
                        bool separateLines,
                        size_t *outputLength)
{
	const unsigned char *inputBuffer = (const unsigned char *)buffer;
	
#define MAX_NUM_PADDING_CHARS 2
#define OUTPUT_LINE_LENGTH 64
#define INPUT_LINE_LENGTH ((OUTPUT_LINE_LENGTH / BASE64_UNIT_SIZE) * BINARY_UNIT_SIZE)
#define CR_LF_SIZE 2
	
	//
	// Byte accurate calculation of final buffer size
	//
	size_t outputBufferSize =
    ((length / BINARY_UNIT_SIZE)
     + ((length % BINARY_UNIT_SIZE) ? 1 : 0))
    * BASE64_UNIT_SIZE;
	if (separateLines)
	{
		outputBufferSize +=
        (outputBufferSize / OUTPUT_LINE_LENGTH) * CR_LF_SIZE;
	}
	
	//
	// Include space for a terminating zero
	//
	outputBufferSize += 1;
    
	//
	// Allocate the output buffer
	//
	char *outputBuffer = (char *)malloc(outputBufferSize);
	if (!outputBuffer)
	{
		return NULL;
	}
    
	size_t i = 0;
	size_t j = 0;
	const size_t lineLength = separateLines ? INPUT_LINE_LENGTH : length;
	size_t lineEnd = lineLength;
	
	while (true)
	{
		if (lineEnd > length)
		{
			lineEnd = length;
		}
        
		for (; i + BINARY_UNIT_SIZE - 1 < lineEnd; i += BINARY_UNIT_SIZE)
		{
			//
			// Inner loop: turn 48 bytes into 64 base64 characters
			//
			outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
			outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i] & 0x03) << 4)
                                                   | ((inputBuffer[i + 1] & 0xF0) >> 4)];
			outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i + 1] & 0x0F) << 2)
                                                   | ((inputBuffer[i + 2] & 0xC0) >> 6)];
			outputBuffer[j++] = base64EncodeLookup[inputBuffer[i + 2] & 0x3F];
		}
		
		if (lineEnd == length)
		{
			break;
		}
		
		//
		// Add the newline
		//
		outputBuffer[j++] = '\r';
		outputBuffer[j++] = '\n';
		lineEnd += lineLength;
	}
	
	if (i + 1 < length)
	{
		//
		// Handle the single '=' case
		//
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i] & 0x03) << 4)
                                               | ((inputBuffer[i + 1] & 0xF0) >> 4)];
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i + 1] & 0x0F) << 2];
		outputBuffer[j++] =	'=';
	}
	else if (i < length)
	{
		//
		// Handle the double '=' case
		//
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0x03) << 4];
		outputBuffer[j++] = '=';
		outputBuffer[j++] = '=';
	}
	outputBuffer[j] = 0;
	
	//
	// Set the output length and return the buffer
	//
	if (outputLength)
	{
		*outputLength = j;
	}
	return outputBuffer;
}

@implementation NSData (LCBase64)

+ (NSData *)_lc_dataFromBase64String:(NSString *)string {
    NSData *data = [string dataUsingEncoding:NSASCIIStringEncoding];
    size_t outputLength;
    void *outputBuffer = avNewBase64Decode([data bytes], [data length], &outputLength);
    NSData *result = [NSData dataWithBytes:outputBuffer length:outputLength];
    free(outputBuffer);
    return result;
}

- (NSString *)_lc_base64EncodedString {
    size_t outputLength=0;
    char *outputBuffer =
    avNewBase64Encode([self bytes], [self length], true, &outputLength);
    
    NSString *result =
    [[NSString alloc]
     initWithBytes:outputBuffer
     length:outputLength
     encoding:NSASCIIStringEncoding];
    free(outputBuffer);
    return result;
}

@end

@implementation NSString (LCMD5)

- (NSString *)_lc_MD5String {
    const char *cstr = [self UTF8String];
    unsigned char result[16];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), result);
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];
}

@end

@implementation NSObject (LeanCloudObjcSDK)

+ (BOOL)_lc_isTypeOf:(id)instance {
    return [instance isKindOfClass:self];
}

+ (instancetype)_lc_decoding:(NSDictionary *)dictionary key:(NSString *)key {
    if (!key) {
        return nil;
    }
    id value = dictionary[key];
    return [value isKindOfClass:self] ? value : nil;
}

@end
