//
//  ViewController.swift
//  RuntimeTestDemo
//
//  Created by zapcannon87 on 18/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import UIKit
import AVOSCloud
import AVOSCloudIM
import AVOSCloudLiveQuery

class ViewController: UIViewController {
    
    var client: AVIMClient!
    
    var liveQuery: AVLiveQuery!
    var isShowFileCallbackAlert: Bool = false
    
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        AVInstallation.default().deviceToken = UUID().uuidString
        
        let query: AVQuery = AVQuery.init(className: "_File")
        query.whereKeyExists("objectId")
        self.liveQuery = AVLiveQuery(query: query)
        self.liveQuery.delegate = self
    }
    
    func showAlert(title: String, message: String) {
        
        let alert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
        
        alert.addAction(action)
        
        self.present(alert, animated: true, completion: nil)
    }

}

extension ViewController {
    
    @objc func IM_open() {
        if self.client == nil {
            let clientId: String = "\(#function)\(#line)"
            let tag: String = "\(#function)\(#line)"
            self.client = AVIMClient(clientId: clientId, tag: tag)
            self.client.delegate = self
        }
        self.client.open(with: .forceOpen) { (succeeded: Bool, error: Error?) in
            if let err: Error = error {
                self.showAlert(title: "error", message: "\(err)")
            } else {
                self.showAlert(title: "ok", message: "\(#function)")
            }
        }
    }
    
    @objc func IM_close() {
        if self.client == nil {
            return
        }
        self.client.close { (succeeded: Bool, error: Error?) in
            if let err: Error = error {
                self.showAlert(title: "error", message: "\(err)")
            } else {
                self.showAlert(title: "ok", message: "\(#function)")
                self.client = nil
            }
        }
    }
    
    @objc func IM_changeDeviceToken() {
        AVInstallation.default().deviceToken = UUID().uuidString
    }
    
    func liveQuerySubscribeFile() {
        
        self.liveQuery.subscribe { (succeeded: Bool, error: Error?) in
            
            guard succeeded else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
                
                return
            }
            
            self.isShowFileCallbackAlert = false
            self.showAlert(title: "Live Query", message: "Subscribe Succeeded")
        }
    }
    
    func createFile() {
        
        let file: AVFile = AVFile.init(remoteURL: URL(string: "http://ac-jmbpc7y4.clouddn.com/d40e9cf44dc5dadf1577.m4a")!)
        
        file.upload { (succeeded: Bool, error: Error?) in
            
            guard succeeded else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
                
                return
            }
            
            if self.isShowFileCallbackAlert {
                
                self.showAlert(title: "Succeeded", message: "Create File")
            }
        }
    }
    
    func deleteFile(with objectId: String) {
        
        AVFile.getWithObjectId(objectId) { (file: AVFile?, error: Error?) in
            
            guard let file: AVFile = file else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
                
                return
            }
            
            file.delete(completionHandler: { (succeeded: Bool, error: Error?) in
                
                guard succeeded else {
                    
                    self.showAlert(title: "Error", message: "\(String(describing: error))")
                    
                    return
                }
                
                if self.isShowFileCallbackAlert {
                    
                    self.showAlert(title: "Succeeded", message: "Delete File")
                }
            })
        }
    }
    
    func liveQueryUnsubscribeFile() {
        
        self.liveQuery.unsubscribe { (succeeded: Bool, error: Error?) in
            
            guard succeeded else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
                
                return
            }
            
            self.isShowFileCallbackAlert = true
            self.showAlert(title: "Live Query", message: "Unsubscribe Succeeded")
        }
    }
    
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 7
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "\(#selector(self.IM_open))"
        case 1:
            cell.textLabel?.text = "\(#selector(self.IM_close))"
        case 2:
            cell.textLabel?.text = "\(#selector(self.IM_changeDeviceToken))"
        case 3:
            cell.textLabel?.text = "Live Query Subscribe _File"
        case 4:
            cell.textLabel?.text = "Create a File"
        case 5:
            cell.textLabel?.text = "Delete a File"
        case 6:
            cell.textLabel?.text = "Live Query Unsubscribe _File"
        default:
            fatalError()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.row {
        case 0:
            self.IM_open()
        case 1:
            self.IM_close()
        case 2:
            self.IM_changeDeviceToken()
        case 3:
            self.liveQuerySubscribeFile()
        case 4:
            self.createFile()
        case 5:
            let alert: UIAlertController = UIAlertController(title: "Input", message: "objectId of deleting file", preferredStyle: .alert)
            
            alert.addTextField(configurationHandler: { _ in })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] _ in
                
                if let text: String = alert?.textFields?.first?.text {
                    
                   self.deleteFile(with: text)
                }
            }))
            
            self.present(alert, animated: true, completion: nil)
        case 6:
            self.liveQueryUnsubscribeFile()
        default:
            fatalError()
        }
    }
}

extension ViewController: AVIMClientDelegate {
    
    func imClientPaused(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
        
        let status: AVIMClientStatus = imClient.status
        if status != .paused {
            print("❤️ Error: \(#function)\(#line)")
        } else {
            print("💙 Info: \(#function)")
        }
    }
    
    func imClientResuming(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
        
        let status: AVIMClientStatus = imClient.status
        if status != .resuming {
            print("❤️ Error: \(#function)\(#line)")
        } else {
            print("💙 Info: \(#function)")
        }
    }
    
    func imClientResumed(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
        
        let status: AVIMClientStatus = imClient.status
        if status != .opened {
            print("❤️ Error: \(#function)\(#line)")
        } else {
            print("💙 Info: \(#function)")
        }
    }
    
    func imClientClosed(_ imClient: AVIMClient, error: Error?) {
        
        assert(Thread.isMainThread)
        
        let status: AVIMClientStatus = imClient.status
        if status != .closed {
            print("❤️ Error: \(#function)\(#line)")
        } else {
            print("💙 Info: \(#function)")
        }
    }
    
    func client(_ client: AVIMClient, didOfflineWithError error: Error?) {
        
        assert(Thread.isMainThread)
        
        print("💛 Debug: \(client)")
        print("💛 Debug: \(String(describing: error))")
    }
    
}

extension ViewController: AVLiveQueryDelegate {
    
    func liveQuery(_ liveQuery: AVLiveQuery, objectDidCreate object: Any) {
        
        assert(self.isShowFileCallbackAlert == false)
        
        self.showAlert(title: "Object Did Create", message: "\(object)")
    }
    
    func liveQuery(_ liveQuery: AVLiveQuery, objectDidDelete object: Any) {
        
        assert(self.isShowFileCallbackAlert == false)
        
        self.showAlert(title: "Object Did Delete", message: "\(object)")
    }
    
}
