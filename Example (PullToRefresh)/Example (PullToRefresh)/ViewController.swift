//
//  ViewController.swift
//  Example (PullToRefresh)
//
//  Created by tang dixi on 9/7/2016.
//  Copyright © 2016 Tangdixi. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
	
  @IBOutlet weak var tableView: UITableView!
  var dataSource = [1]
	
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    tableView.dcRefreshControl = DCRefreshControl {
      // do something...
      
	  sleep(3)
      
      self.dataSource = [1, 2, 3, 4, 5 ,6, 7]
      self.tableView.reloadData()
      
    }

    
  }

  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

}

extension ViewController: UITableViewDataSource {
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return dataSource.count
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    cell.textLabel?.text = String(dataSource[indexPath.row])
    return cell
  }
  
}
