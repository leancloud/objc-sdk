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
    
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var reopenButton: UIButton!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    @IBAction func login() {
        
        self.activityIndicatorView.startAnimating()
        self.loginButton.isEnabled = false
        self.reopenButton.isEnabled = false
        
        self.client.open { (success: Bool, error: Error?) in
            
            self.activityIndicatorView.stopAnimating()
            self.loginButton.isEnabled = true
            self.reopenButton.isEnabled = true
            
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
    
    @IBAction func reopen() {
        
        self.activityIndicatorView.startAnimating()
        self.loginButton.isEnabled = false
        self.reopenButton.isEnabled = false
        
        self.client.open(with: [.reopen]) { (success: Bool, error: Error?) in
            
            self.activityIndicatorView.stopAnimating()
            self.loginButton.isEnabled = true
            self.reopenButton.isEnabled = true
            
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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        AVInstallation.current().deviceToken = UUID().uuidString
        
        self.client = AVIMClient(clientId: "RuntimeTestDemo", tag: "test")
        self.client.delegate = self
        
        assert(self.client.status == .none)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
