//
//  LiveQueryTestViewController.swift
//  RuntimeTestDemo
//
//  Created by zapcannon87 on 2018/12/19.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import Foundation
import UIKit
import AVOSCloud
import AVOSCloudIM
import AVOSCloudLiveQuery

class LiveQueryTestViewController: UIViewController {
    
    var liveQuery: AVLiveQuery!
    
    var query: AVQuery!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.query = AVQuery(className: "Todo")
        self.query.whereKeyExists("objectId")
        
        self.liveQuery = AVLiveQuery(query: query)
        self.liveQuery.delegate = self
        
        self.liveQuery.subscribe { (succeeded, error) in
            
        }
    }
    
    @IBAction func buttonAction(_ sender: UIButton) {
        let object = AVObject(className: "Todo")
        object.save()
    }
    
}

extension LiveQueryTestViewController: AVLiveQueryDelegate {
    
    func liveQuery(_ liveQuery: AVLiveQuery, objectDidCreate object: Any) {
        print("\(liveQuery) objectDidCreate: \(object)")
    }
    
}
