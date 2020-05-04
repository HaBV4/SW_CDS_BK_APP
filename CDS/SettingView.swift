//
//  SettingView.swift
//  CDS
//
//  Created by Tuan ANh on 4/26/18.
//  Copyright © 2018 Tuan ANh. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class SettingView: UIViewController {

    let bag = DisposeBag()
    
    @IBOutlet weak var tfHost: UITextField!
    @IBOutlet weak var tfPort: UITextField!
    @IBOutlet weak var imgSelected1: UIImageView!
    @IBOutlet weak var imgSelected2: UIImageView!
    @IBOutlet weak var btnConnect: UIButton!
    @IBOutlet weak var lbConnectionStatus: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        updateInfo()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpUI()
        updateInfo()
    }

    fileprivate func setUpUI() {
        
        DataManager.shared.selectedMap.asObservable()
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] mapIndex in
                
                if mapIndex == 1 {
                    self?.imgSelected1.image = #imageLiteral(resourceName: "ic_checked")
                    self?.imgSelected2.image = nil
                } else if mapIndex == 2 {
                    self?.imgSelected1.image = nil
                    self?.imgSelected2.image = #imageLiteral(resourceName: "ic_checked")
                }
            })
            .disposed(by: bag)
        
        DataManager.shared.isConnected.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] isConnected in
                
                self?.lbConnectionStatus.text = isConnected ? "Connected" : ""
                self?.btnConnect.setTitle((isConnected ? "Disconnect" : "Connect"), for: .normal)
            }).disposed(by: bag)
        
    }
    
    fileprivate func updateInfo() {
        self.tfHost.text = DataManager.shared.host
        self.tfPort.text = "\(DataManager.shared.port)"
        
    }
    
    @IBAction func btnChangeStadium(_ sender: UIButton) {
        
        DataManager.shared.selectedMap.value = sender.tag
    }
    
    @IBAction func btnConnectClicked(_ sender: Any) {
        
        if DataManager.shared.isConnected.value == true {
            DataManager.shared.disconnectMQTTClinet()
        } else {
            
            DataManager.shared.host = self.tfHost.text ?? ""
            DataManager.shared.port = Int(self.tfPort.text ?? "1883") ?? 1883
            DataManager.shared.selectedMap.value = self.imgSelected1.image != nil ? 1 : 2
            
            self.lbConnectionStatus.text = "Connecting..."
            
            DataManager.shared.startMQTTClient()
            
        }
        
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
