//
//  FirstViewController.swift
//  PosingAlarmClock
//
//  Created by 甲斐翔也 on 2019/09/22.
//  Copyright © 2019 甲斐翔也. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var alarmList = [
        ["7:00", true],
        ["8:00", false]
    ]

    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return alarmList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        label.text = alarmList[indexPath.row][0] as! String
        let uiSwitch = cell.viewWithTag(2) as! UISwitch
        uiSwitch.isOn = alarmList[indexPath.row][1] as! Bool
        return cell
    }
}
