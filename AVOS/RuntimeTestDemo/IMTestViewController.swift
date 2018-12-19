//
//  IMTestViewController.swift
//  RuntimeTestDemo
//
//  Created by zapcannon87 on 2018/12/19.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import Foundation
import UIKit
import AVOSCloud
import AVOSCloudIM

class IMTestViewController: UIViewController {
    
    var client: AVIMClient!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        client = AVIMClient(clientId: "test")
        client.delegate = self
        client.open { (succeeded, error) in
            if let error = error {
                self.label.text = "\(error)"
            } else {
                self.label.text = "Opened"
            }
        }
    }
    
}

extension IMTestViewController: AVIMClientDelegate {
    
    func imClientPaused(_ imClient: AVIMClient) {
        label.text = "Paused"
    }
    
    func imClientResuming(_ imClient: AVIMClient) {
        label.text = "Resuming"
    }
    
    func imClientResumed(_ imClient: AVIMClient) {
        label.text = "Resumed"
    }
    
    func imClientClosed(_ imClient: AVIMClient, error: Error?) {
        label.text = "\(String(describing: error))"
    }
    
}
