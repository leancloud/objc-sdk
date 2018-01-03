//
//  LCSSLChallenger.m
//  AVOS
//
//  Created by Tang Tianyong on 6/30/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import "LCSSLChallenger.h"
#import "AVHelpers.h"
#import "AVUtils.h"
#import <Security/Security.h>
#import <AssertMacros.h>

static NSString * const kLCDomainSuffix_leancloud_cn = @"leancloud.cn";

static NSString * const kLCCertificate_DomainSuffix_leancloud_cn = @"MIIFDzCCA/egAwIBAgIQECg10GmSYWMKtzx/By5NMTANBgkqhkiG9w0BAQsFADBEMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEdMBsGA1UEAxMUR2VvVHJ1c3QgU1NMIENBIC0gRzMwHhcNMTQxMTI4MDAwMDAwWhcNMTYwOTI0MjM1OTU5WjCBjDELMAkGA1UEBhMCQ04xEDAOBgNVBAgTB0JlaWppbmcxEDAOBgNVBAcUB0JlaWppbmcxMjAwBgNVBAoUKU1laSBXZWkgU2h1IFFpYW4gKCBCZWlqaW5nICkgSVQgQ28uLCBMdGQuMQwwCgYDVQQLFANPUFMxFzAVBgNVBAMUDioubGVhbmNsb3VkLmNuMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzHX5I4zHZcHerO3x0l5pScvqKE8MlK/6hzrDONDsBuMnfkAPRpkPPGB6HfaAAGjyStsi5hZrPgOA3r+6lActiapjnRnfTSo57tJyF/5XexLOdzU45fhNO41mJYiSlGAK0L+EUQSlnSClxixPDIwkkpbF8XYrrpPnZeSCzm62Jk38Lx6GUheZH3UzmC5JPmcqBgmAidmi36wFk7UWT2c6fmmDA+DWJBxdt5+/MhLG7OcFEP0YeiSDXwirnSlQphMswIn1d+XprX/BHqnvlQgnTPZeIrYraVmTlA2qjOWZLKlZExhLaSnOqT/XLQN9q0fAHrKswhrBAzOycvvbt/9HswIDAQABo4IBsjCCAa4wJwYDVR0RBCAwHoIOKi5sZWFuY2xvdWQuY26CDGxlYW5jbG91ZC5jbjAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIFoDArBgNVHR8EJDAiMCCgHqAchhpodHRwOi8vZ24uc3ltY2IuY29tL2duLmNybDCBoQYDVR0gBIGZMIGWMIGTBgpghkgBhvhFAQc2MIGEMD8GCCsGAQUFBwIBFjNodHRwczovL3d3dy5nZW90cnVzdC5jb20vcmVzb3VyY2VzL3JlcG9zaXRvcnkvbGVnYWwwQQYIKwYBBQUHAgIwNQwzaHR0cHM6Ly93d3cuZ2VvdHJ1c3QuY29tL3Jlc291cmNlcy9yZXBvc2l0b3J5L2xlZ2FsMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAfBgNVHSMEGDAWgBTSb/eW9IU/cjwwfSPahXibo3xafDBXBggrBgEFBQcBAQRLMEkwHwYIKwYBBQUHMAGGE2h0dHA6Ly9nbi5zeW1jZC5jb20wJgYIKwYBBQUHMAKGGmh0dHA6Ly9nbi5zeW1jYi5jb20vZ24uY3J0MA0GCSqGSIb3DQEBCwUAA4IBAQDdrrEg1t+LtyE5Roy5dhe7yM0tb5pcy+hEP1ZXncwv4SMldTWPejuomwF5vt2lX0FEhzrd1k9Ndk5LJq5x5SrCHos1kTO/MxkRvg7eUkErOYM0AK3j3I37xZv/rRN4UOJVKh1i4e88hgrAXhxLLQn96d8zzMJbpRYiBz3cW6I8w+bR5BtwVpgzJU5Z3gLDDJLVqwSDUjNpFrlmBor0kh7izPc5WAg5xkZ5ovQgp5Mwc1l9FByIqNZvY/pfGZBkEzeSP73rfccWg3Y7vz+mORgHDpSxAqmyna2hXn8aiEl3FW1v0w1PgJAskNmxt8zNAg38Jpuv7I1sDNjX/tyC1je0";

static NSString * const kLCDomainSuffix_lncld_net = @"lncld.net";

static NSString * const kLCCertificate_DomainSuffix_lncld_net = @"MIIFpzCCBI+gAwIBAgIRAPK8zg+g1SZe/3JFlLGHw68wDQYJKoZIhvcNAQELBQAwgZAxCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoTEUNPTU9ETyBDQSBMaW1pdGVkMTYwNAYDVQQDEy1DT01PRE8gUlNBIERvbWFpbiBWYWxpZGF0aW9uIFNlY3VyZSBTZXJ2ZXIgQ0EwHhcNMTcwMjIyMDAwMDAwWhcNMTkwMjIxMjM1OTU5WjBhMSEwHwYDVQQLExhEb21haW4gQ29udHJvbCBWYWxpZGF0ZWQxITAfBgNVBAsTGFBvc2l0aXZlU1NMIE11bHRpLURvbWFpbjEZMBcGA1UEAxMQYXBpLmxlYW5jbG91ZC5jbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK87NYGsrbi2YWzL8nDGRDiGlF1E5Ge12Mu2cJ5QKISGZaMv5obQTsDMlsph60QCkd3m7Q3EwBg7HVZD0UeLIXXalUePwgTkomDdUeEX1gD3xW0Jve7Wj+pFf1mq9Cf8sqSzc5Vh3AkU+wTEGScHt3P1fDLZQqgsrMCYNeAFAhPJ8yvK/gWcRlzJo0AYOdb/0WNNSZoBoMTmDdo+463mP6A2tX0O1hb3gY/oDfBpzETyBgB9YK4TmrbahalqzefHywl6iLKIq3c7sNThRHKoO1e057m2Kt+TwiCf8JiM5lCCqTGeIKzCyucst9OCM8l3MWDwzxSMi4W6DqHBZhsnjvkCAwEAAaOCAigwggIkMB8GA1UdIwQYMBaAFJCvajqUWgvYkOoSVnPfQ7Q6KNrnMB0GA1UdDgQWBBTqy0r3zgdlsyr9JboIQ05zIkGZHTAOBgNVHQ8BAf8EBAMCBaAwDAYDVR0TAQH/BAIwADAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwTwYDVR0gBEgwRjA6BgsrBgEEAbIxAQICBzArMCkGCCsGAQUFBwIBFh1odHRwczovL3NlY3VyZS5jb21vZG8uY29tL0NQUzAIBgZngQwBAgEwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL2NybC5jb21vZG9jYS5jb20vQ09NT0RPUlNBRG9tYWluVmFsaWRhdGlvblNlY3VyZVNlcnZlckNBLmNybDCBhQYIKwYBBQUHAQEEeTB3ME8GCCsGAQUFBzAChkNodHRwOi8vY3J0LmNvbW9kb2NhLmNvbS9DT01PRE9SU0FEb21haW5WYWxpZGF0aW9uU2VjdXJlU2VydmVyQ0EuY3J0MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wdgYDVR0RBG8wbYIQYXBpLmxlYW5jbG91ZC5jboIPKi5hcGkubG5jbGQubmV0ghIqLmVuZ2luZS5sbmNsZC5uZXSCECoucHVzaC5sbmNsZC5uZXSCDyoucnRtLmxuY2xkLm5ldIIRKi5zdGF0cy5sbmNsZC5uZXQwDQYJKoZIhvcNAQELBQADggEBADYw3GKsC/xA9U1J6nJ6jZQcvT+8HJqEEJSO5si+nh72dN3WyLkl4vbCt37zQEX+OlAYqdKnqKTXS+b4XStneSMdvVwbJoZwZ3sv7QNVLbQefMoQ5P5LcpZ7cag+bXcgy5zG1g4GN+bWARmqEflm1p4B/IZ9WWXMRCYot8iCj/PL/DpLCIMxVoLnqcmd5JtlL62uwthu4dE79qQTAoQ3bYRTjeqnDMpvexddonC2O8KijXPIm1azD0qKvRTshiljWGLqw0h/5KgTpgvDN/eGTFqBu6Pr4AL97THRUdgbgBTjkaSf1tGSX9tTYSl8eEtuoPCbW7QcHuiF/HHkK4j0wAQ=";

static id publicKeyForCertificate(NSData *certificate) {
    id allowedPublicKey = nil;
    SecCertificateRef allowedCertificate;
    SecCertificateRef allowedCertificates[1];
    CFArrayRef tempCertificates = nil;
    SecPolicyRef policy = nil;
    SecTrustRef allowedTrust = nil;
    SecTrustResultType result;

    allowedCertificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificate);
    __Require_Quiet(allowedCertificate != NULL, _out);

    allowedCertificates[0] = allowedCertificate;
    tempCertificates = CFArrayCreate(NULL, (const void **)allowedCertificates, 1, NULL);

    policy = SecPolicyCreateBasicX509();
    __Require_noErr_Quiet(SecTrustCreateWithCertificates(tempCertificates, policy, &allowedTrust), _out);
    __Require_noErr_Quiet(SecTrustEvaluate(allowedTrust, &result), _out);

    allowedPublicKey = (__bridge_transfer id)SecTrustCopyPublicKey(allowedTrust);

_out:
    if (allowedTrust) {
        CFRelease(allowedTrust);
    }

    if (policy) {
        CFRelease(policy);
    }

    if (tempCertificates) {
        CFRelease(tempCertificates);
    }

    if (allowedCertificate) {
        CFRelease(allowedCertificate);
    }
    
    return allowedPublicKey;
}

static NSArray * publicKeysForServerTrust(SecTrustRef serverTrust) {
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];
    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);

        SecCertificateRef someCertificates[] = {certificate};
        CFArrayRef certificates = CFArrayCreate(NULL, (const void **)someCertificates, 1, NULL);

        SecTrustRef trust;
        __Require_noErr_Quiet(SecTrustCreateWithCertificates(certificates, policy, &trust), _out);

        SecTrustResultType result;
        __Require_noErr_Quiet(SecTrustEvaluate(trust, &result), _out);

        [trustChain addObject:(__bridge_transfer id)SecTrustCopyPublicKey(trust)];

    _out:
        if (trust) {
            CFRelease(trust);
        }

        if (certificates) {
            CFRelease(certificates);
        }

        continue;
    }
    CFRelease(policy);
    
    return [NSArray arrayWithArray:trustChain];
}

#if !TARGET_OS_IOS && !TARGET_OS_WATCH && !TARGET_OS_TV
static NSData * LCSecKeyGetData(SecKeyRef key) {
    CFDataRef data = NULL;

    __Require_noErr_Quiet(SecItemExport(key, kSecFormatUnknown, kSecItemPemArmour, NULL, &data), _out);

    return (__bridge_transfer NSData *)data;

_out:
    if (data) {
        CFRelease(data);
    }

    return nil;
}
#endif

static BOOL LCSecKeyIsEqualToKey(SecKeyRef key1, SecKeyRef key2) {
#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
    return [(__bridge id)key1 isEqual:(__bridge id)key2];
#else
    return [LCSecKeyGetData(key1) isEqual:LCSecKeyGetData(key2)];
#endif
}

@implementation LCSSLChallenger {
    
    id _publicKey_DomainSuffix_leancloud_cn;
    
    id _publicKey_DomainSuffix_lncld_net;
}

+ (instancetype)sharedInstance
{
    static LCSSLChallenger *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[LCSSLChallenger alloc] init];
    });

    return instance;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        NSData *certData = nil;
        
        certData = [NSData AVdataFromBase64String:kLCCertificate_DomainSuffix_leancloud_cn];
        _publicKey_DomainSuffix_leancloud_cn = publicKeyForCertificate(certData);
        
        certData = [NSData AVdataFromBase64String:kLCCertificate_DomainSuffix_lncld_net];
        _publicKey_DomainSuffix_lncld_net = publicKeyForCertificate(certData);
    }
    
    return self;
}

- (BOOL)shouldTrustServerTrust:(SecTrustRef)serverTrust
               pinnedPublicKey:(id)pinnedPublicKey
{
    NSArray *publicKeys = publicKeysForServerTrust(serverTrust);
    
    for (id publicKey in publicKeys) {
        
        if (LCSecKeyIsEqualToKey((__bridge SecKeyRef)publicKey, (__bridge SecKeyRef)pinnedPublicKey)) {
            
            return true;
        }
    }
    
    return false;
}

- (void)acceptChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSString *host = challenge.protectionSpace.host;
    
    SecTrustRef secTrustRef = challenge.protectionSpace.serverTrust;
    
    void(^validateWithPublicKey_block)(id) = ^(id pinnedPublicKey) {
        
        if ([self shouldTrustServerTrust:secTrustRef pinnedPublicKey:pinnedPublicKey]) {
            
            NSURLCredential *credential = [NSURLCredential credentialForTrust:secTrustRef];
            
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
            
        } else {
            
            AVLoggerError(AVLoggerDomainNetwork, @"Request to Host: '%@' is rejected because SSL validation did fail.", host);
            
            [[challenge sender] cancelAuthenticationChallenge:challenge];
        }
    };
    
    if ([host hasSuffix:kLCDomainSuffix_leancloud_cn]) {
        
        validateWithPublicKey_block(_publicKey_DomainSuffix_leancloud_cn);
        
    } else if ([host hasSuffix:kLCDomainSuffix_lncld_net]) {
        
        validateWithPublicKey_block(_publicKey_DomainSuffix_lncld_net);
    }
}

@end
