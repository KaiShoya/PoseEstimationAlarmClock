//
//  SecondViewController.swift
//  PosingAlarmClock
//
//  Created by 甲斐翔也 on 2019/09/22.
//  Copyright © 2019 甲斐翔也. All rights reserved.
//

import UIKit

class SecondViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var alarmList = [
        "「フィットネスNEO」1日無料体験チケット",
        "ダンベル専門ショップ「ダンベラー」10%オフチケット",
        "サバスプロテイン500円オフチケット"
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
        cell.textLabel!.text = alarmList[indexPath.row]
        return cell
    }
}
