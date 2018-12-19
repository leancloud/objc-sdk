//
//  ViewController.swift
//  RuntimeTestDemo
//
//  Created by zapcannon87 on 18/01/2018.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "IM Test"
        case 1:
            cell.textLabel?.text = "Live Query Test"
        default:
            fatalError()
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "IMTestViewController")
            self.navigationController?.pushViewController(vc, animated: true)
        case 1:
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "LiveQueryTestViewController")
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            fatalError()
        }
    }
    
}
