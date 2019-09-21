//
//  PoseEstimationViewController.swift
//  PosingAlarmClock
//
//  Created by 甲斐翔也 on 2019/09/22.
//  Copyright © 2019 甲斐翔也. All rights reserved.
//

import UIKit

class PoseEstimationViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var jointView: DrawingJointView!
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = UIImage(named: "pose01")
    }

    @IBAction func unwindToRootViewController(segue: UIStoryboardSegue) {
    }
}
