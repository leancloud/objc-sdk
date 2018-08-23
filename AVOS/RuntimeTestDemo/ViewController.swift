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
    
    var liveQuery1: AVLiveQuery!
    var liveQuery2: AVLiveQuery!
    var query: AVQuery!
    var isShowFileCallbackAlert: Bool = false
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        AVInstallation.default().deviceToken = UUID().uuidString
        
        self.client = AVIMClient(clientId: "RuntimeTestDemo", tag: "test")
        self.client.delegate = self
        
        AVUser.loginAnonymously { (_, _) in
            
        }
        
        let query: AVQuery = AVQuery.init(className: "_File")
        query.whereKeyExists("objectId")
        self.query = query
        self.liveQuery1 = AVLiveQuery(query: query)
        self.liveQuery1.delegate = self
        self.liveQuery2 = AVLiveQuery(query: query)
        self.liveQuery2.delegate = self
        
        self.tableView.reloadData()
    }
    
    func showAlert(title: String, message: String) {
        
        let alert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
        
        alert.addAction(action)
        
        self.present(alert, animated: true, completion: nil)
    }

}

extension ViewController {
    
    @objc func liveQuery2SubscribeFile() {
        
        self.liveQuery2.subscribe { (succeeded: Bool, error: Error?) in
            
            guard succeeded else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
                
                return
            }
            
            self.isShowFileCallbackAlert = false
            self.showAlert(title: "Live Query", message: "Subscribe Succeeded")
        }
    }
    
    @objc func liveQuery2UnsubscribeFile() {
        
        self.liveQuery2.unsubscribe { (succeeded: Bool, error: Error?) in
            
            guard succeeded else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
                
                return
            }
            
            self.isShowFileCallbackAlert = true
            self.showAlert(title: "Live Query", message: "Unsubscribe Succeeded")
        }
    }
    
    @objc func userLogout() {
        AVUser.logOut()
        AVUser.loginAnonymously { (_, _) in
            
        }
    }
    
    @objc func liveQuery1SubscribeFile() {
        
        self.liveQuery1.subscribe { (succeeded: Bool, error: Error?) in
            
            guard succeeded else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
                
                return
            }
            
            self.isShowFileCallbackAlert = false
            self.showAlert(title: "Live Query", message: "Subscribe Succeeded")
        }
    }
    
    @objc func createFile() {
        
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
    
    @objc func deleteFile(with objectId: String) {
        
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
    
    @objc func liveQuery1UnsubscribeFile() {
        
        self.liveQuery1.unsubscribe { (succeeded: Bool, error: Error?) in
            
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
            cell.textLabel?.text = "\(#selector(self.liveQuery2SubscribeFile))"
        case 1:
            cell.textLabel?.text = "\(#selector(self.liveQuery2UnsubscribeFile))"
        case 2:
            cell.textLabel?.text = "\(#selector(self.userLogout))"
        case 3:
            cell.textLabel?.text = "\(#selector(self.liveQuery1SubscribeFile))"
        case 4:
            cell.textLabel?.text = "\(#selector(self.createFile))"
        case 5:
            cell.textLabel?.text = "\(#selector(self.deleteFile(with:)))"
        case 6:
            cell.textLabel?.text = "\(#selector(self.liveQuery1UnsubscribeFile))"
        default:
            fatalError()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.row {
        case 0:
            self.liveQuery2SubscribeFile()
        case 1:
            self.liveQuery2UnsubscribeFile()
        case 2:
            self.userLogout()
        case 3:
            self.liveQuery1SubscribeFile()
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
            self.liveQuery1UnsubscribeFile()
        default:
            fatalError()
        }
    }
}

extension ViewController: AVIMClientDelegate {
    
    func imClientPaused(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
    }
    
    func imClientResuming(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
    }
    
    func imClientResumed(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
    }
    
    func imClientClosed(_ imClient: AVIMClient, error: Error?) {
        
        assert(Thread.isMainThread)
    }
    
    func client(_ client: AVIMClient, didOfflineWithError error: Error?) {
        
        assert(Thread.isMainThread)
        
        let alert: UIAlertController = UIAlertController(title: "Offline", message: "\(String(describing: error))", preferredStyle: .alert)
        
        let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
        
        alert.addAction(action)
        
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension ViewController: AVLiveQueryDelegate {
    
    func liveQuery(_ liveQuery: AVLiveQuery, objectDidCreate object: Any) {
        
        assert(self.isShowFileCallbackAlert == false)
        
        if liveQuery == self.liveQuery1 {
            self.showAlert(title: "1. Object Did Create", message: "\(object)")
        } else if liveQuery == self.liveQuery2 {
            self.showAlert(title: "2. Object Did Create", message: "\(object)")
        }
    }
    
    func liveQuery(_ liveQuery: AVLiveQuery, objectDidDelete object: Any) {
        
        assert(self.isShowFileCallbackAlert == false)
        
        self.showAlert(title: "Object Did Delete", message: "\(object)")
        if liveQuery == self.liveQuery1 {
            self.showAlert(title: "1. Object Did Delete", message: "\(object)")
        } else if liveQuery == self.liveQuery2 {
            self.showAlert(title: "2. Object Did Delete", message: "\(object)")
        }
    }
    
}
