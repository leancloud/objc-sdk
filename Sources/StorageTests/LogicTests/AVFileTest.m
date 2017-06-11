//
//  AVFileTest.m
//  paas
//
//  Created by Travis on 14-1-27.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "AVTestBase.h"
#import "AVUtils.h"
#import "AVFile.h"
#import "AVFile_Internal.h"

@interface AVFileTest : AVTestBase

@end

@implementation AVFileTest
    //FIXME:Test Fails
- (void)testFileName {
    NSString *filePath=[[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino" ofType:@"jpg"];
    
    NSError *error;
    AVFile *file=[AVFile fileWithData:[NSData dataWithContentsOfFile:filePath]];
    [file save:&error];
    XCTAssertNil(error);
    
    [AVFile getFileWithObjectId:file.objectId withBlock:^(AVFile *file2, NSError *error) {
        NSString *name = file2.name;
        XCTAssertNil(error);
        NOTIFY
    }];
    WAIT
}

- (void)testVerifyFile {
    NSString *filePath=[[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino" ofType:@"jpg"];
    NSString *fileMD5= [AVUtils MD5ForFile:filePath];
    
    NSString *correctMD5=@"32031c2b2aca6f302dfabe7fb4a561d4";
    
    XCTAssertEqualObjects(fileMD5, correctMD5, @"file md5 not work");

    AVFile *file=[AVFile fileWithName:@"testimage.jpg" contentsAtPath:filePath];
    [file save];
    [self addDeleteFile:file];
    
    [AVFile getFileWithObjectId:file.objectId withBlock:^(AVFile *file2, NSError *error) {
        XCTAssertNotNil(file2, @"no file got");
        if (!file2) {
            NOTIFY
        }
        [file2 getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
            NSString *newMd5= [AVUtils MD5ForFile:file2.localPath];
            XCTAssertEqualObjects(newMd5, correctMD5, @"file md5 not work");
            NOTIFY
        } progressBlock:^(NSInteger percentDone) {
            [self checkPercentDone:percentDone];
        }];
    }];
    
    WAIT_FOREVER
}


-(void)testUploadFile {
    NSString *hello = @"hello world!";
    NSData *data = [hello dataUsingEncoding:NSUTF8StringEncoding];

    AVFile *file = [AVFile fileWithName:@"aa.txt" data:data];
    file.name = @"helloworld.txt";
    
    XCTAssertTrue([file save]);
    [self addDeleteFile:file];

    [AVFile getFileWithObjectId:file.objectId withBlock:^(AVFile *file2, NSError *error) {
        XCTAssertNotNil(file2, @"no file got");
        if (!file2) {
            NOTIFY
        }
        [file2 getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            XCTAssertEqualObjects(hello, result, @"file content not equal");
            NOTIFY
        } progressBlock:^(NSInteger percentDone) {
            [self checkPercentDone:percentDone];
        }];
    }];
    
    WAIT_FOREVER
}

-(void)testUploadLargeFile {
    NSString *filePath = [self generateFileOfMegabytes:32];
    NSString *fileMD5= [AVUtils MD5ForFile:filePath];

    AVFile *file=[AVFile fileWithName:@"32M.bin" contentsAtPath:filePath];
    [file saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        NOTIFY
    } progressBlock:^(NSInteger percentDone) {
        [self checkPercentDone:percentDone];
    }];
    WAIT_FOREVER;
    [self addDeleteFile:file];
    
    [AVFile getFileWithObjectId:file.objectId withBlock:^(AVFile *file2, NSError *error) {
        XCTAssertNotNil(file2, @"no file got");
        if (!file2) {
            NOTIFY
        }
        [file2 getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
            NSString *newMd5= [AVUtils MD5ForFile:file2.localPath];
            XCTAssertEqualObjects(newMd5, fileMD5, @"file md5 not work");
            NOTIFY
        } progressBlock:^(NSInteger percentDone) {
            [self checkPercentDone:percentDone];
        }];
    }];
    
    WAIT_FOREVER
}

- (void)testUploadManyFiles {
    NSString *filePath=[[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino" ofType:@"jpg"];
    int count = 10;
    __block int uploaded = 0;
    for (int i = 0; i < count; ++i) {
        AVFile *file = [AVFile fileWithName:@"avatar" contentsAtPath:filePath];
        [file saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            XCTAssertTrue(succeeded, @"%@", error);
            ++uploaded;
            if (uploaded == count) {
                NOTIFY;
            }
        } progressBlock:^(NSInteger percentDone) {
            
        }];
        [self addDeleteFile:file];
    }
    WAIT_FOREVER;
}

-(void)testObjectWithLargeFileAttribute {
    NSString *filePath=[[NSBundle bundleForClass:[self class]] pathForResource:@"TestRelation" ofType:@"json"];
    NSString *fileMD5= [AVUtils MD5ForFile:filePath];
    
    AVFile *file1 = [AVFile fileWithName:@"TestRelation.json" contentsAtPath:filePath];
    AVFile *file2 = [AVFile fileWithName:@"TestRelation.json" contentsAtPath:filePath];
    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
    [object setObject:file1 forKey:@"file1"];
    [object setObject:file2 forKey:@"file2"];
    [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        NOTIFY
    }];
    NSLog(@"reached");
    WAIT_FOREVER;
    [self addDeleteFile:file1];
    [self addDeleteFile:file2];
    [self addDeleteObject:object];
    
}

- (void)testFileArray {
    
    NSString *filePath1=[[NSBundle bundleForClass:[self class]] pathForResource:@"TestRelation" ofType:@"json"];
    NSString *filePath2=[[NSBundle bundleForClass:[self class]] pathForResource:@"alpacino" ofType:@"jpg"];
    NSString *fieldName = NSStringFromSelector(_cmd);
    
    AVFile *file1 = [AVFile fileWithName:@"TestRelation.json" contentsAtPath:filePath1];
    [file1 save];
    AVFile *file2 = [AVFile fileWithName:@"avatar.jpg" contentsAtPath:filePath2];
    [file2 save];
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject:file1];
    [array addObject:file2];
    AVObject *object = [AVObject objectWithClassName:NSStringFromClass([self class])];
    [object setObject:array forKey:fieldName];
    [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded, @"%@", error);
        NOTIFY;
    }];
    NSLog(@"reached");
    WAIT_FOREVER;
    AVObject *object2 = [AVObject objectWithoutDataWithClassName:NSStringFromClass([self class]) objectId:object.objectId];
    [object2 fetch];
    NSArray *a = [object2 objectForKey:fieldName];
    NSLog(@"%@", a);
    XCTAssertEqual(a.count, 2, @"the array should have 2 file objects");
    if (a.count > 0) {
        id file = [a objectAtIndex:0];
        XCTAssertEqualObjects([file class], [AVFile class], @"the object should be a AVFile object");
    }
    [self addDeleteFile:file1];
    [self addDeleteFile:file2];
    [self addDeleteObject:object];
}

- (NSString *)generateFileOfMegabytes:(NSInteger)megabytes {
    unsigned long long size = megabytes * 1024 * 1024;

    NSString *dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *filePath = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@~%ldM", [AVUtils generateUUID], (long)megabytes]];

    [[NSFileManager defaultManager] createFileAtPath:filePath contents:[NSData data] attributes:nil];
    NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    [fh seekToFileOffset:size-1];
    [fh writeData:[@"\x00" dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];

    return filePath;
}

- (void)testDownloadFileSimultaneous {
    NSString *filePath = [self generateFileOfMegabytes:1];

    AVFile *file = [AVFile fileWithName:@"1M.bin" contentsAtPath:filePath];
    [file save];
    int64_t s = file.size;
    [file clearCachedFile];
    __block NSInteger callbackCount = 0;
    
    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        if (!error) {
            XCTAssertEqual(data.length, s);
        }
        callbackCount++;
        if (callbackCount == 2) {
            NOTIFY;
        }
    } progressBlock:^(NSInteger percentDone) {
        NSLog(@"percent1:%ld", percentDone);
        XCTAssertTrue(percentDone >= 0 && percentDone <= 100);
    }];
    
    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        if (!error) {
            XCTAssertEqual(data.length, s);
        }
        callbackCount++;
        if (callbackCount == 2) {
            NOTIFY;
        }
    } progressBlock:^(NSInteger percentDone) {
        NSLog(@"percent2:%ld", percentDone);
        XCTAssertTrue(percentDone >= 0 && percentDone <= 100);
    }];
    WAIT;
}

- (void)testDownloadSameFileSerialize {
    NSString *filePath = [self generateFileOfMegabytes:1];

    NSError *error;
    AVFile *file = [AVFile fileWithName:@"1M.bin" contentsAtPath:filePath];
    [file save:&error];
    XCTAssertNil(error);
    int64_t s = file.size;

    AVFile *file2 = [AVFile fileWithName:@"1M.bin" contentsAtPath:filePath];
    [file2 save];
    [file2 clearCachedFile];

    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        if (!error) {
            XCTAssertEqual(data.length, s);
        }
        NOTIFY;
    } progressBlock:^(NSInteger percentDone) {
        NSLog(@"percent1:%ld", percentDone);
        XCTAssertTrue(percentDone >= 0 && percentDone <= 100);
    }];
    WAIT;
    [file2 getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        if (!error) {
            XCTAssertEqual(data.length, s);
        }
        NOTIFY;
    } progressBlock:^(NSInteger percentDone) {
        NSLog(@"percent2:%ld", percentDone);
        XCTAssertTrue(percentDone >= 0 && percentDone <= 100);
    }];
    WAIT;
}

- (void)testFileLocalPath {
    NSData *data = [@"hello world!" dataUsingEncoding:NSUTF8StringEncoding];
    AVFile *file = [AVFile fileWithData:data];
    NSError *error;
    [file save:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(file.localPath);
}

- (void)testFileWithAVObject {
    AVFile *file=[AVFile fileWithName:@"Attention" data:[@"PHP is the best language." dataUsingEncoding:NSUTF8StringEncoding]];
    [file save];
    AVQuery *query = [AVQuery queryWithClassName:@"_File"];
    [query whereKey:@"objectId" equalTo:file.objectId];
    AVObject *fileObject = [query getFirstObject];
    AVFile *queriedFile = [AVFile fileWithAVObject:fileObject];
    XCTAssertEqualObjects(queriedFile.name, @"Attention");
    NSData *data = [queriedFile getData];
    XCTAssertEqualObjects(@"PHP is the best language.",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

- (void)testAVFileQuery {
    AVFile *file=[AVFile fileWithName:@"Attention" data:[@"PHP is the best language." dataUsingEncoding:NSUTF8StringEncoding]];
    [file save];
    
    AVFileQuery *query = [AVFile query];
    [query whereKey:@"objectId" equalTo:file.objectId];
    NSError *error;
    NSArray *foundFiles = [query findFiles:&error];
    XCTAssertNil(error);
    XCTAssertEqual(foundFiles.count, 1);
    AVFile *foundFile = foundFiles[0];
    XCTAssertTrue([file isKindOfClass:[AVFile class]]);
    XCTAssertEqualObjects(foundFile.name, @"Attention");
    
    [query findFilesInBackgroundWithBlock:^(NSArray *foundFiles, NSError *error) {
        XCTAssertEqual(foundFiles.count, 1);
        AVFile *foundFile = foundFiles[0];
        XCTAssertEqualObjects(foundFile.name, @"Attention");
        NOTIFY
    }];
    WAIT

    AVFileQuery *query1 = [AVFileQuery query];
    id foundObject = [query1 getFileWithId:file.objectId error:nil];
    XCTAssertTrue([foundObject isKindOfClass:[AVFile class]]);
    XCTAssertEqualObjects(((AVFile*)foundObject).name, @"Attention");
    
    AVFileQuery *query2 = [AVFileQuery query];
    [query2 getFileInBackgroundWithId:file.objectId block:^(AVFile *file, NSError *error) {
        XCTAssertEqualObjects(file.name, @"Attention");
        NOTIFY
    }];
    WAIT
    
    AVFileQuery *query3 = [AVFileQuery query];
    NSError *theError;
    [query3 getFileWithId:@"53234" error:&theError];
    XCTAssertEqual(theError.code, kAVErrorObjectNotFound);
    XCTAssertEqualObjects(theError.localizedDescription, @"No object with that objectId 53234 was found.");
}

- (void)testProgress {
    NSString *filePath = [self generateFileOfMegabytes:1];
    AVFile *file=[AVFile fileWithData:[NSData dataWithContentsOfFile:filePath]];
    [file save];
    NSInteger size = file.size;
    
    [file clearCachedFile];
    
    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        XCTAssertNil(error);
        XCTAssertTrue(data.length == size);
        NOTIFY
    } progressBlock:^(NSInteger percentDone) {
        [self checkPercentDone:percentDone];
    }];
    WAIT
}

- (void)testProgressWhenNoContentLength {
    AVFile *file = [AVFile fileWithURL:@"http://ac-3k995jpi.clouddn.com/XN1xKPyC3MuIdmSzOhLo5sIsujvLiPuLNCsvbJqc.zip"];
    file.bucket = @"3k995jpi";
    [file clearCachedFile];
    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        XCTAssertNil(error);
        XCTAssertTrue(data.length == 2224413);
        NOTIFY
    } progressBlock:^(NSInteger percentDone) {
        [self checkPercentDone:percentDone];
    }];
    WAIT
}

- (void)checkPercentDone:(NSInteger)percentDone {
    NSLog(@"percentDone: %ld%%", percentDone);
    XCTAssertTrue(percentDone >= 0 && percentDone <= 100);
}

@end
