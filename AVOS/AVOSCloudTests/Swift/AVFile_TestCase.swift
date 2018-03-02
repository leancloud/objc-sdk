//
//  AVFile_TestCase.swift
//  AVOS
//
//  Created by zapcannon87 on 22/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVFile_TestCase: LCTestBase {
    
    let remoteURL: URL = URL(string: "http://ac-jmbpc7y4.clouddn.com/d40e9cf44dc5dadf1577.m4a")!
    
    lazy var smallData: Data = {
        
        let filePath: String = Bundle(for: type(of: self)).path(forResource: "alpacino", ofType: "jpg")!
        
        let url: URL = URL.init(fileURLWithPath: filePath)
        
        let data: Data = try! Data.init(contentsOf: url)
        
        return data
    }()
    
    lazy var bigData: Data = {
        
        let filePath: String = Bundle(for: type(of: self)).path(forResource: "_10_MB_", ofType: "png")!
        
        let url: URL = URL.init(fileURLWithPath: filePath)
        
        let data: Data = try! Data.init(contentsOf: url)
        
        return data
    }()
    
    func test_upload_URL() {
        
        let t1 = {
            
            let remoteURL: URL = self.remoteURL
            
            let file: AVFile = AVFile(remoteURL: remoteURL)
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    XCTAssertEqual(file.url(), remoteURL.absoluteString)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t1()
        
        let t2 = {
            
            let remoteURL: URL = self.remoteURL
            
            var hasProgress: Bool = false
            
            let file: AVFile = AVFile(remoteURL: remoteURL)
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: { (number: Int) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(number >= 0 && number <= 100)
                    
                    hasProgress = true
                    
                }, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    XCTAssertEqual(file.url(), remoteURL.absoluteString)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            XCTAssertTrue(hasProgress)
        }
        
        t2()
    }
    
    func test_upload_data() {
        
        let t1 = {
            
            let uploadData: Data = self.smallData
            
            let file: AVFile = AVFile(data: uploadData, name: "image.jpg")
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    guard let cachedPath: String = file.persistentCachePath() else {
                        XCTFail()
                        return
                    }
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploadData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t1()
        
        let t2 = {
            
            let uploadData: Data = self.bigData
            
            let file: AVFile = AVFile(data: uploadData, name: "image.png")
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    guard let cachedPath: String = file.persistentCachePath() else {
                        XCTFail()
                        return
                    }
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploadData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t2()
        
        let t3 = {
            
            var hasProgress = false
            
            let uploaData: Data = self.smallData
            
            let file: AVFile = AVFile(data: uploaData, name: "image.jpg")
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: { (number: Int) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(number >= 0 && number <= 100)
                    
                    hasProgress = true
                    
                }, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    guard let cachedPath: String = file.persistentCachePath() else {
                        XCTFail()
                        return
                    }
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploaData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            XCTAssertTrue(hasProgress)
        }
        
        t3()
        
        let t4 = {
            
            let uploaData: Data = self.smallData
            
            let file: AVFile = AVFile(data: uploaData, name: "image.jpg")
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [.ignoringCachingData], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    guard let cachedPath: String = file.persistentCachePath() else {
                        XCTFail()
                        return
                    }
                    
                    XCTAssertFalse(FileManager.default.fileExists(atPath: cachedPath))
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t4()
    }
    
    func test_upload_filePath() {
        
        let documentsDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let filePath: URL = documentsDirectory.appendingPathComponent("_10_MB_.png")
        
        let uploadData: Data = self.bigData
        
        do {
            
            try uploadData.write(to: filePath, options: [.atomic])
            
        } catch let err {
            
            XCTFail("\(err)")
        }
        
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            
            return
        }
        
        let t1 = {
            
            var file: AVFile! = nil
            
            do {
                
                file = try AVFile(localPath: filePath.path)
                
            } catch let err {
                
                XCTFail("\(err)")
            }
            
            guard file != nil else { return }
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    guard let cachedPath: String = file.persistentCachePath() else {
                        XCTFail()
                        return
                    }
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploadData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t1()
        
        let t2 = {
            
            var file: AVFile! = nil
            
            do {
                
                file = try AVFile(localPath: filePath.path)
                
            } catch let err {
                
                XCTFail("\(err)")
            }
            
            guard file != nil else { return }
            
            var hasProgress: Bool = false
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: { (number: Int) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(number >= 0 && number <= 100)
                    
                    hasProgress = true
                    
                }, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    guard let cachedPath: String = file.persistentCachePath() else {
                        XCTFail()
                        return
                    }
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploadData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            XCTAssertTrue(hasProgress)
        }
        
        t2()
        
        let t3 = {
            
            var file: AVFile! = nil
            
            do {
                
                file = try AVFile(localPath: filePath.path)
                
            } catch let err {
                
                XCTFail("\(err)")
            }
            
            guard file != nil else { return }
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [.ignoringCachingData], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    guard let cachedPath: String = file.persistentCachePath() else {
                        XCTFail()
                        return
                    }
                    
                    XCTAssertFalse(FileManager.default.fileExists(atPath: cachedPath))
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t3()
    }
    
    func test_download_file() {
        
        var downloadFile: AVFile!
        
        let uploadData: Data = self.bigData
        
        let removeItemAtPath: (String) -> Bool = { (path: String) in
            
            if FileManager.default.fileExists(atPath: path) {
                do {
                    
                    try FileManager.default.removeItem(atPath: path)
                    
                    return true
                    
                } catch let err {
                    
                    XCTFail("\(err)")
                    
                    return false
                }
            } else {
                
                return true
            }
        }
        
        let t1 = {
            
            let file: AVFile = AVFile(data: uploadData, name: "image.jpg")
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [.ignoringCachingData], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    guard let cachedPath: String = file.persistentCachePath() else {
                        XCTFail()
                        return
                    }
                    
                    if removeItemAtPath(cachedPath) {
                        
                        downloadFile = file
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t1()
        
        guard downloadFile != nil,
            let cachedPath: String = downloadFile.persistentCachePath() else {
            
            XCTFail()
            
            return
        }
        
        let t2 = {
            
            let _ = removeItemAtPath(cachedPath)
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                downloadFile.download(with: [], progress: nil, completionHandler: { (filePath: URL?, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(filePath?.path, cachedPath)
                    XCTAssertNil(error)
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploadData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t2()
        
        let t3 = {
            
            let _ = removeItemAtPath(cachedPath)
            
            var hasProgress: Bool = false
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                downloadFile.download(with: [], progress: { (number: Int) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(number >= 0 && number <= 100)
                    
                    hasProgress = true
                    
                }, completionHandler: { (filePath: URL?, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(filePath?.path, cachedPath)
                    XCTAssertNil(error)
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploadData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            XCTAssertTrue(hasProgress)
        }
        
        t3()
        
        let t4 = {
            
            var hasProgress: Bool = false
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                downloadFile.download(with: [], progress: { (number: Int) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(number == 100)
                    
                    hasProgress = true
                    
                }, completionHandler: { (filePath: URL?, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(filePath?.path, cachedPath)
                    XCTAssertNil(error)
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploadData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            XCTAssertTrue(hasProgress)
        }
        
        t4()
        
        let t5 = {
            
            var not_100_progress_count: Int = 0
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                downloadFile.download(with: [.ignoringCachedData], progress: { (number: Int) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    if number >= 0 && number != 100 {
                        
                        not_100_progress_count += 1
                    }
                    
                }, completionHandler: { (filePath: URL?, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertEqual(filePath?.path, cachedPath)
                    XCTAssertNil(error)
                    
                    if FileManager.default.fileExists(atPath: cachedPath) {
                        
                        do {
                            
                            let data: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: cachedPath))
                            XCTAssertEqual(uploadData.count, data.count)
                            
                        } catch let err {
                            
                            XCTFail("\(err)")
                        }
                    } else {
                        
                        XCTFail()
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            XCTAssertTrue(not_100_progress_count > 0)
        }
        
        t5()
        
        let t6 = {
            
            downloadFile.clearPersistentCache()
            
            XCTAssertFalse(FileManager.default.fileExists(atPath: cachedPath))
            
            AVFile.clearAllPersistentCache()
            
            XCTAssertFalse(FileManager.default.fileExists(atPath: URL.init(fileURLWithPath: cachedPath).deletingLastPathComponent().path))
        }
        
        t6()
    }
    
    func test_download_externalURL() {
        
        let removeItemAtPath: (String) -> Bool = { (path: String) in
            
            if FileManager.default.fileExists(atPath: path) {
                do {
                    
                    try FileManager.default.removeItem(atPath: path)
                    
                    return true
                    
                } catch let err {
                    
                    XCTFail("\(err)")
                    
                    return false
                }
            } else {
                
                return true
            }
        }
        
        var externalURLFile: AVFile!
        
        let remoteURL: URL = self.remoteURL
        
        let t1 = {
            
            let file: AVFile = AVFile(remoteURL: remoteURL)
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    XCTAssertEqual(file.url(), remoteURL.absoluteString)
                    
                    if succeeded {
                        
                        externalURLFile = file
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t1()
        
        guard externalURLFile != nil,
            let cachedPath: String = externalURLFile.persistentCachePath() else {
            XCTFail()
            return
        }
        
        let t2 = {
            
            let _ = removeItemAtPath(cachedPath)
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                externalURLFile.download(with: [], progress: nil, completionHandler: { (filePath: URL?, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNotNil(filePath)
                    XCTAssertNil(error)
                    
                    if let path: String = filePath?.path {
                        
                        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t2()
        
        let t3 = {
            
            externalURLFile.clearPersistentCache()
            
            XCTAssertFalse(FileManager.default.fileExists(atPath: cachedPath))
            
            AVFile.clearAllPersistentCache()
            
            XCTAssertFalse(FileManager.default.fileExists(atPath: URL.init(fileURLWithPath: cachedPath).deletingLastPathComponent().deletingLastPathComponent().path))
        }
        
        t3()
    }
    
    func test_cancel_task() {
        
        let t1 = {
            
            let uploadData: Data = self.bigData
            
            let file: AVFile = AVFile(data: uploadData, name: "image.png")
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: { (number: Int) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    file.cancelUploading()
                    
                }, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertFalse(succeeded)
                    XCTAssertNotNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t1()
        
        var downloadCancelFile: AVFile!
        
        let t2 = {
            
            let uploadData: Data = self.bigData
            
            let file: AVFile = AVFile(data: uploadData, name: "image.png")
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [.ignoringCachingData], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    
                    if succeeded {
                        
                        downloadCancelFile = file
                    }
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t2()
        
        guard downloadCancelFile != nil else {
            XCTFail()
            return
        }
        
        let t3 = {
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                downloadCancelFile.download(with: [.ignoringCachedData], progress: { (number: Int) in
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    downloadCancelFile.cancelDownloading()
                    
                }, completionHandler: { (filePath: URL?, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertNil(filePath)
                    XCTAssertNotNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t3()
    }
    
    func test_delete_fileObject() {
        
        let uploadedFile = { () -> AVFile? in
            
            let remoteURL: URL = self.remoteURL
            
            let file: AVFile = AVFile(remoteURL: remoteURL)
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    XCTAssertEqual(file.url(), remoteURL.absoluteString)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            if (file.objectId() != nil) {
                
                return file
                
            } else {
                
                return nil
            }
        }
        
        let t1 = {
            
            guard let file: AVFile = uploadedFile() else {
                XCTFail()
                return
            }
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.delete(completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t1()
        
        let t2 = {
            
            var array: [AVFile] = []
            
            for _ in 0..<5 {
                
                guard let file: AVFile = uploadedFile() else {
                    continue
                }
                
                array.append(file)
            }
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                AVFile.delete(with: array, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
        }
        
        t2()
    }
    
    func test_get_fileObject() {
        
        let uploadedFile = { () -> AVFile? in
            
            let remoteURL: URL = self.remoteURL
            
            let file: AVFile = AVFile(remoteURL: remoteURL)
            
            self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
                
                semaphore.increment()
                
                file.upload(with: [], progress: nil, completionHandler: { (succeeded: Bool, error: Error?) in
                    
                    semaphore.decrement()
                    
                    XCTAssertTrue(Thread.isMainThread)
                    
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(file.objectId())
                    XCTAssertNotNil(file.url())
                    XCTAssertEqual(file.url(), remoteURL.absoluteString)
                })
                
            }, failure: {
                
                XCTFail("timeout")
            })
            
            if (file.objectId() != nil) {
                
                return file
                
            } else {
                
                return nil
            }
        }
        
        guard let objectId: String = uploadedFile()?.objectId() else {
            XCTFail()
            return
        }
        
        self.runloopTestingAsync(async: { (semaphore: RunLoopSemaphore) in
            
            semaphore.increment()
            
            AVFile.getWithObjectId(objectId, completionHandler: { (file: AVFile?, error: Error?) in
                
                semaphore.decrement()
                
                XCTAssertTrue(Thread.isMainThread)
    
                XCTAssertNotNil(file)
                XCTAssertEqual(file?.objectId(), objectId)
                XCTAssertNil(error)
            })
            
        }, failure: {
            
            XCTFail("timeout")
        })
    }
    
}
