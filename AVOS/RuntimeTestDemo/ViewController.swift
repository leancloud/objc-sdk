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
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        AVInstallation.default().deviceToken = UUID().uuidString
        
        self.client = AVIMClient(clientId: "RuntimeTestDemo", tag: "test")
        self.client.delegate = self
        
        assert(self.client.status == .none)
    }
    
    func enableUserInteraction() {
        self.activityIndicatorView.stopAnimating()
        self.view.isUserInteractionEnabled = true
    }
    
    func disableUserInteraction() {
        self.activityIndicatorView.startAnimating()
        self.view.isUserInteractionEnabled = false
    }

}

extension ViewController {
    
    func login() {
        
        self.disableUserInteraction()
        
        self.client.open { (success: Bool, error: Error?) in
            
            self.enableUserInteraction()
            
            if success {
                
                let alert: UIAlertController = UIAlertController(title: "Success", message: "Login", preferredStyle: .alert)
                
                let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
                
                alert.addAction(action)
                
                self.present(alert, animated: true, completion: nil)
                
            } else {
                
                let alert: UIAlertController = UIAlertController(title: "Error", message: "\(String(describing: error))", preferredStyle: .alert)
                
                let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
                
                alert.addAction(action)
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func reopen() {
        
        self.disableUserInteraction()
        
        self.client.open(with: .reopen) { (success: Bool, error: Error?) in
            
            self.enableUserInteraction()
            
            if success {
                
                let alert: UIAlertController = UIAlertController(title: "Success", message: "Login", preferredStyle: .alert)
                
                let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
                
                alert.addAction(action)
                
                self.present(alert, animated: true, completion: nil)
                
            } else {
                
                let alert: UIAlertController = UIAlertController(title: "Error", message: "\(String(describing: error))", preferredStyle: .alert)
                
                let action: UIAlertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
                
                alert.addAction(action)
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func changeDeviceToken() {
        AVInstallation.default().deviceToken = UUID().uuidString
    }
    
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Login"
        case 1:
            cell.textLabel?.text = "Reopen"
        case 2:
            cell.textLabel?.text = "Change Device Token"
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
            self.login()
        case 1:
            self.reopen()
        case 2:
            self.changeDeviceToken()
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
