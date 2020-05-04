//
//  LogViewController.swift
//  CDS
//
//  Created by The New Macbook on 4/2/19.
//  Copyright © 2019 Tuan ANh. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class LogViewController: UIViewController {

    @IBOutlet weak var tvLog: UITextView!
    let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        DataManager.shared.logs.asObservable().bind(to: self.tvLog.rx.text).disposed(by: bag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
