//
//  MatchView.swift
//  CDS
//
//  Created by Tuan ANh on 4/27/18.
//  Copyright © 2018 Tuan ANh. All rights reserved.
//

import UIKit
import Moscapsule
import RxSwift
import RxCocoa

class MatchView: UIViewController {

    let bag = DisposeBag()
    
    // MARK: Outlets
    
    @IBOutlet weak var lbConnectStatus: UILabel!
    
    @IBOutlet weak var rightView: UIView!
    
    @IBOutlet weak var map1View: UIView!
    @IBOutlet weak var map2View: UIView!
    
    @IBOutlet weak var btnConnect: UIButton!
    
    
    @IBOutlet var btnsSensor: [UIButton]!
    @IBOutlet var lbsSensor: [UILabel]!
    
    @IBOutlet var btnsSensor0: [UIButton]!
    @IBOutlet var lbsSensor0: [UILabel]!
    
    @IBOutlet weak var smStadium: UISegmentedControl!
    @IBOutlet weak var lbCountDown: UILabel!
    @IBOutlet weak var btnStart: UIButton!
    
    @IBOutlet var lbStopCountDown: [UILabel]!
    @IBOutlet var lbBestResult: [UILabel]!

    @IBOutlet weak var tvLogs: UITextView!
    @IBOutlet weak var deviceControlView: UIView!
    
    // MARK: Properties
    let clientId = "cid"
    let sensorPayloadString = "{\"stadium\":\"%@\", \"channel\":\"%@\", \"runtime\":\"%@\"}"
    let servoPayloadString  = "{\"stadium\":\"%@\", \"random\":\"%@\"}"
//    let sensorStopPayloadString  = "{\"stadium\":\"%@\", \"channel\":\"0\", \"isStop\":\"%@\"}"
    let payloadRetryString = "{\"stadium\":\"%@\", \"state\":\"%@\"}"
    
    let payloadDeviceParkingString = "{\"team\":\"%@\", \"command\":\"%@\"}"
    
    let messageStopDevicePayloadString  = "{\"team\":\"%@\", \"command\":\"%@\"}"
    
    var mqttClient: MQTTClient!
    
    // Timer
    var seconds: Float = 180 //
    var endRoundTime: Float = 0
    var timer = Timer()
    var isTimerRunning = false
    static let stepTime: Float = 0.01
    
    // Trường hợp xe đi hết một vòng gặp biển stop
    var stopSeconds: Int = 0
    var stopTimer = Timer()
    var isStopTimerRunning = false
    var isStop = false
    
    // Ghi nhận thời gian tốt nhất đi hết vòng
    var bestResult: Variable<Float> = Variable(0)
    
    // MARK: Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let savedSecond = UserDefaults.standard.float(forKey: SECOND_COUNT_DOWN_KEY)
        seconds =  savedSecond > 0 ? savedSecond : 180
        
        setupUI()
    }
    
    fileprivate func setupUI() {
        
        self.smStadium.rx.selectedSegmentIndex.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] index in
                let redColor = UIColor(red: 255.0/255.0, green: 71.0/255.0, blue: 87.0/255.0, alpha: 1.0)
                let greenColor = UIColor(red: 46.0/255.0, green: 213.0/255.0, blue: 115.0/255.0, alpha: 1.0)
                
                self?.rightView.backgroundColor = index == 0 ? redColor : greenColor
                self?.map2View.isHidden = index == 0
                self?.map1View.isHidden = index == 1
            })
            .disposed(by: bag)
        
        self.bestResult.asObservable()
            .filter { $0 > 0 }
            .map { value -> String in
                let result = MatchView.parseTimeWithTotalSecond(totalSeconds: value)
                
                return "\(result.0) : \(result.1).\(result.2)"
            }
            .subscribe(onNext: { [weak self] stValue in
                self?.lbBestResult.forEach { $0.text = stValue}
            })
            .disposed(by: bag)
        
        //
        DataManager.shared.isConnected.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] isConnected in
                
                self?.btnConnect.setTitle((isConnected ? "Disconnect" : "Connect"), for: .normal)
                self?.lbConnectStatus.text = isConnected ? "Connected" : "Disconnect"
                self?.lbConnectStatus.textColor = isConnected ? .green : .black
            }).disposed(by: bag)
        // Nhận lệnh start từ server
        DataManager.shared.matchCommand.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] matchCommand in

                switch matchCommand {
                case .START_STADIUM_1:
                    if self.isTimerRunning == false {

                        self.startTimer()
                        self.btnStart.setTitle("Reset", for: .normal)
                    }

                    break
                case .RESET_STADIUM_1:
                    self.resetTimmer()

                    // reset stop timer
                    self.isStop = false
                    self.btnStart.backgroundColor = .red
                    self.btnStart.setTitle("Stop", for: .normal)
                    
//                    DataManager.shared.mqttPublishMessage(message: payload, withTopic: SENSOR_TOPIC)
                    break
                case .NONE:
                    break
                }
            })
            .disposed(by: bag)
        // log value
        self.tvLogs.rx.text
            .asObservable()
            .subscribe(onNext: { log in
                DataManager.shared.logs.value = log ?? ""
            })
            .disposed(by: bag)
    }
    
    // MARK: Action
    
    @IBAction func btnConnectClicked(_ sender: Any) {
        
        if DataManager.shared.isConnected.value == true {
            DataManager.shared.disconnectMQTTClinet()
        } else {
            DataManager.shared.startMQTTClient()
        }
    }
    
    @IBAction func btnEndTurnClicked(_ sender: Any) {
        
        self.endTurn()
    }
    
    fileprivate func endTurn() {
        endRoundTime = totalTime - seconds
        
        for btn in btnsSensor {
            btn.backgroundColor = .clear
            btn.setTitleColor(.blue, for: .normal)
        }
        
        isStop = false
        //self.btnParking.forEach({ btn in
          //  btn.backgroundColor = .red
           // btn.setTitle("Stop", for: .normal)
        //})
        self.tvLogs.text += "\n------end------\n"
        
        self.btnsSensor0.forEach { btn in
            btn.backgroundColor = .clear
            btn.setTitleColor(.blue, for: .normal)
        }
    }
    
    @IBAction func btnSensor0Clicked(_ sender: UIButton) {
        if isTimerRunning == false {
            return
        }
        // Send to server
        let stadium = self.smStadium.selectedSegmentIndex == 0 ? "R" : "G"
        let chanel = "0"
        let time = "\(totalTime - seconds - endRoundTime)"
        let payload = String(format: self.sensorPayloadString, stadium, chanel, time)
        print(payload)
//        let currentTime = MatchView.parseTimeWithTotalSecond(totalSeconds: Float(totalTime - seconds - endRoundTime))
        
        DataManager.shared.mqttPublishMessage(message: payload, withTopic: SENSOR_TOPIC)
        self.btnsSensor0.forEach { btn in
                btn.backgroundColor = .blue
                btn.setTitleColor(.white, for: .normal)
        }
        self.lbsSensor0
            .forEach { $0.text = time }
//        self.tvLogs.text += "\n\(stadium)-S\(chanel): 0:\(time.2)"
    }
    
    @IBAction func btnStartClicked(_ sender: UIButton) {
        if isTimerRunning == false {
            startTimer()
            self.btnStart.setTitle("Reset", for: .normal)
        } else {
            resetTimmer()
        }
    }
    
    @IBAction func btnSensorClicked(_ sender: UIButton) {
        semiFinalSensorInforWhenClickButton(selecButton: sender)
    }
    
    @IBAction func btnCleanLogClicked(_ sender: Any) {
        self.tvLogs.text = ""
    }
    
    
    // MARK: Function
    
    // Timer
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(MatchView.stepTime), target: self, selector: (#selector(self.updateTimer)), userInfo: nil, repeats: true)
        isTimerRunning = true
    }
    
    fileprivate func resetTimmer() {
        timer.invalidate()
        seconds = DataManager.shared.second
        endRoundTime = 0
        let time = MatchView.parseTimeWithTotalSecond(totalSeconds: seconds)
        self.lbCountDown.text = "\(time.0) : \(time.1).\(time.2)"
        
        self.btnStart.setTitle("Start", for: .normal)
        
        for btn in btnsSensor {
            btn.backgroundColor = .clear
            btn.setTitleColor(.blue, for: .normal)
        }
        
        isTimerRunning = false
        
        bestResult.value = 0
        self.lbBestResult.forEach {$0.text = ""}
//        self.tvLogs.text = ""
        self.btnsSensor0.forEach { btn in
            btn.backgroundColor = .clear
            btn.setTitleColor(.blue, for: .normal)
        }
    }
    
    @objc func updateTimer() {
        seconds -= MatchView.stepTime     //This will decrement(count down)the seconds.
        
        let result = MatchView.parseTimeWithTotalSecond(totalSeconds: seconds)
        
        self.lbCountDown.text = "\(result.0) : \(result.1).\(result.2)"
        
        if seconds <= 0 {
            isTimerRunning = !isTimerRunning
            resetTimmer()
        }
    }
    
    // MARK: Timer for stop/play
    func beginStopTimer() {
        stopSeconds = 0
        stopTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.updateStopTimer)), userInfo: nil, repeats: true)
        isStopTimerRunning = true
    }
    
    fileprivate func resetStopTimer() {
        stopTimer.invalidate()
        isStopTimerRunning = false
    }
    
    @objc func updateStopTimer() {
        stopSeconds += 1     //This will decrement(count down)the seconds.

        let mins = stopSeconds / 60
        let secs = stopSeconds % 60
        self.lbStopCountDown.forEach {$0.text = "\(mins):\(secs)"}
        
        if stopSeconds == 5 {
            resetStopTimer()
        }
    }

    static func parseTimeWithTotalSecond(totalSeconds: Float) -> (Int, Int, Int) {
        
        var time = TimeInterval(totalSeconds)
        // calculate minutes
        let min = Int(time / 60.0)
        time -= (TimeInterval(min) * 60)
        
        // Calculate seconds
        let sec = Int(time)
        time -= TimeInterval(sec)
        
        // calculate miliseconds
        let milisec = Int(time * 1000)
        
        return (min, sec, milisec)
    }
    
    // MARK: Thông tin bán kết
    fileprivate func semiFinalSensorInforWhenClickButton(selecButton: UIButton) {
        
        if isTimerRunning == true {
            let stadium = self.smStadium.selectedSegmentIndex == 0 ? "R" : "G"
            let chanel = "\(selecButton.tag)"
            let time = "\(totalTime - seconds - endRoundTime)"
            let payload = String(format: self.sensorPayloadString, stadium, chanel, time)
            print(payload)
            DataManager.shared.mqttPublishMessage(message: payload, withTopic: SENSOR_TOPIC)
            
            // Note time to label
            let noteTime = MatchView.parseTimeWithTotalSecond(totalSeconds: Float(totalTime - seconds - endRoundTime))
            let currentLabel = self.lbsSensor.filter { $0.tag == selecButton.tag }
            currentLabel.forEach { $0.text = "\(noteTime.0):\(noteTime.1).\(noteTime.2)"}
            
            self.tvLogs.text += "\n\(stadium)-S\(selecButton.tag): \(noteTime.0):\(noteTime.1).\(noteTime.2)"
            
            // ......
            self.btnsSensor.filter { $0.tag == selecButton.tag }
                .forEach { btn in
                    btn.backgroundColor = .blue
                    btn.setTitleColor(.white, for: .normal)
            }
            
            if selecButton.tag == 5 {        // Trướng hợp đi hết vòng hợp lệ, ghi nhận kết quả
//                self.tvLogs.text += "\n-----------------\n"
                var isPassAllSensor = true  // check đã đi qua đủ sensor
                for button in self.btnsSensor {
                    if button.tag != 5 && button.backgroundColor != .blue {
                        isPassAllSensor = false
                    }
                }
                
//                if (isPassAllSensor == true) && (isStop == true && stopSeconds >= 4 ) {  // check xem đã đi đủ các biển và đã dừng đủ 5s nếu chưa đi đủ ko ghi nhận kết quả
                if (isPassAllSensor == true) {              // 2019: năm nay ko bắt dừng 5 
                    let timeToFinishARound = totalTime - seconds - endRoundTime
                    if self.bestResult.value == 0 {
                        self.bestResult.value = timeToFinishARound
                    } else {
                        self.bestResult.value = timeToFinishARound < self.bestResult.value ? timeToFinishARound : self.bestResult.value
                    }
                }
                
                self.endTurn()
            }
        }
    }
    
    
    // MARK: Thông tin chung kết
    fileprivate func finalSensorInforWhenClickButton(selecButton: UIButton) {
        if isTimerRunning == true {
            
            
            if selecButton.tag == 6 {        // Trướng hợp đi hết vòng hợp lệ, ghi nhận kết quả

//                var isPassAllSensor = true  // check đã đi qua đủ sensor
//                for button in self.btnFinalSensor {
//                    if button.tag != 5 && button.backgroundColor != .blue {
//                        isPassAllSensor = false
//                    }
//                }

//                self.tvLogs.text += "\n-----------------\n"
                 resetTimmer()
            } else {
                
                let stadium = self.smStadium.selectedSegmentIndex == 0 ? "R" : "G"
                let chanel = "\(selecButton.tag)"
                let time = "\(totalTime - seconds - endRoundTime)"
                let payload = String(format: self.sensorPayloadString, stadium, chanel, time)
                print(payload)
                DataManager.shared.mqttPublishMessage(message: payload, withTopic: SENSOR_FINAL_TOPIC)
                
                selecButton.backgroundColor = .blue
                selecButton.setTitleColor(.white, for: .normal)
                
                
                // Note time to label
                let noteTime = MatchView.parseTimeWithTotalSecond(totalSeconds: Float(totalTime - seconds - endRoundTime))
                
                self.tvLogs.text += "\n\(stadium)-S\(selecButton.tag): \(noteTime.0):\(noteTime.1).\(noteTime.2)"
            }
        }
    }
}

// Creat Countdown Timer Paked

