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
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        AVInstallation.default().deviceToken = UUID().uuidString
        
        self.client = AVIMClient(clientId: "RuntimeTestDemo", tag: "test")
        self.client.delegate = self
        
        assert(self.client.status == .none)
        
        self.liveQuery = AVLiveQuery(query: AVQuery.init(className: "_File"))
        self.liveQuery.delegate = self
    }
    
    func enableUserInteraction() {
        self.activityIndicatorView.stopAnimating()
        self.view.isUserInteractionEnabled = true
    }
    
    func disableUserInteraction() {
        self.activityIndicatorView.startAnimating()
        self.view.isUserInteractionEnabled = false
    }
    
    func showAlert(title: String, message: String) {
        
        let alert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
        
        alert.addAction(action)
        
        self.present(alert, animated: true, completion: nil)
    }

}

extension ViewController {
    
    func imLogin() {
        
        self.disableUserInteraction()
        
        self.client.open { (success: Bool, error: Error?) in
            
            self.enableUserInteraction()
            
            if success {
                
                self.showAlert(title: "Success", message: "Login")
                
            } else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
            }
        }
    }
    
    func imReopen() {
        
        self.disableUserInteraction()
        
        self.client.open(with: .reopen) { (success: Bool, error: Error?) in
            
            self.enableUserInteraction()
            
            if success {
                
                self.showAlert(title: "Success", message: "Login")
                
            } else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
            }
        }
    }
    
    func changeDeviceToken() {
        AVInstallation.default().deviceToken = UUID().uuidString
    }
    
    func liveQuerySubscribe() {
        self.liveQuery.subscribe { (succeeded: Bool, error: Error?) in
            
            guard succeeded else {
                
                self.showAlert(title: "Error", message: "\(String(describing: error))")
                
                return
            }
            
            self.showAlert(title: "Live Query", message: "Subscribe Succeeded")
        }
    }
    
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "IM Login"
        case 1:
            cell.textLabel?.text = "IM Reopen"
        case 2:
            cell.textLabel?.text = "Change Device Token"
        case 3:
            cell.textLabel?.text = "Live Query"
        default:
            fatalError()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        switch indexPath.row {
        case 0:
            self.imLogin()
        case 1:
            self.imReopen()
        case 2:
            self.changeDeviceToken()
        case 3:
            self.liveQuerySubscribe()
        default:
            fatalError()
        }
    }
}

extension ViewController: AVIMClientDelegate {
    
    func imClientPaused(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
        
        assert(imClient.status == .paused)
    }
    
    func imClientResuming(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
        
        assert(imClient.status == .resuming)
    }
    
    func imClientResumed(_ imClient: AVIMClient) {
        
        assert(Thread.isMainThread)
        
        assert(imClient.status == .opened)
    }
    
    func imClientClosed(_ imClient: AVIMClient, error: Error?) {
        
        assert(Thread.isMainThread)
        
        assert(imClient.status == .closed)
    }
    
    func client(_ client: AVIMClient, didOfflineWithError error: Error?) {
        
        assert(Thread.isMainThread)
        
        assert(client.status == .closed)
        
        let alert: UIAlertController = UIAlertController(title: "Offline", message: "\(String(describing: error))", preferredStyle: .alert)
        
        let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
        
        alert.addAction(action)
        
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension ViewController: AVLiveQueryDelegate {
    
}
