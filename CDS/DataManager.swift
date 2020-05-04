//
//  DataManager.swift
//  CDS
//
//  Created by Tuan ANh on 4/26/18.
//  Copyright © 2018 Tuan ANh. All rights reserved.
//

import Foundation
import Moscapsule
import RxSwift

let SELECTED_MAP_KEY = "kSelected_map"
let SELECTED_STADIUM_KEY = "kSelected_stadium"
let HOST_KEY = "kHost"
let PORT_KEY = "kPort"
let TOPIC_KEY = "kPort"
let SECOND_COUNT_DOWN_KEY = "kSecondCountDown"

let clientID = UIDevice.current.identifierForVendor!.uuidString

// MARK: Static
let totalTime: Float = 180.0
let payloadString = "{\"stadium\":\"%@\", \"channel\":\"%@\", \"runtime\":\"%@\"}"

let SENSOR_TOPIC = "cds/sensor_mobile"
let SENSOR_FINAL_TOPIC = "cds/sensor/final"
let SENSOR_STOP_TOPIC = "cds/server/sensor6"
let SERVO_TOPIC = "cds/random_mobile"
let COMMAND_TOPIC = "cds/command"
let END_TURN_TOPIC = "cds/case"
let SENSOR_RESUME_FINAL_TOPIC = "cds/retry/final"
let DEVICE_PARKING_TOPIC = "esp32/output"
let DEVICE_CONTROL_TOPIC = "esp32/control"

enum MatchCommand: String {
    case START_STADIUM_1  = "RACE_MASTER_START"
    case RESET_STADIUM_1  = "RACE_MASTER_RESET"
    case NONE
}

enum ServoState: String {
    
    case LEFT   = "LEFT"
    case RIGHT  = "RIGHT"
    case NONE   = "NONE"
}

class DataManager {
    
    let bag = DisposeBag()
    
    // MARK: -  Singleton
    static let shared = DataManager()
    
    let standardUserDefault = UserDefaults.standard
    
    // MARK: - Properties
    var selectedMap: Variable<Int> = Variable(1)
    
    var selectedStadium: Int {
        didSet {
            standardUserDefault.set(selectedStadium, forKey: SELECTED_STADIUM_KEY)
        }
    }
    
    var host: String {
        didSet {
            standardUserDefault.set(host, forKey: HOST_KEY)
        }
    }
    
    var port: Int {
        didSet {
            standardUserDefault.set(port, forKey: PORT_KEY)
        }
    }
    
    var second: Float {
        didSet {
            standardUserDefault.set(second, forKey: SECOND_COUNT_DOWN_KEY)
        }
    }
    
    var isConnected: Variable<Bool> = Variable(false)           // Connection status
    var matchCommand: Variable<MatchCommand> = Variable(.NONE) // Match Status
    var endTurnCommandAtStadium: Variable<String> = Variable("")    // Tín hiệu hết turn ở sân nào
    
    var mqttClient: MQTTClient!
    
    var logs: Variable<String> = Variable("")
    
    // MARK: - Initialization
    init() {
        
        selectedMap.value = standardUserDefault.integer(forKey: SELECTED_MAP_KEY)
        selectedMap.asObservable()
        
        selectedStadium = standardUserDefault.integer(forKey: SELECTED_STADIUM_KEY)
        host = standardUserDefault.string(forKey: HOST_KEY) ?? ""
        port = standardUserDefault.integer(forKey: PORT_KEY) ?? 1883
        
        let savedSecond = standardUserDefault.float(forKey: SECOND_COUNT_DOWN_KEY)
        second =  savedSecond > 0 ? savedSecond : 180
    }
    
    func startMQTTClient() {
        
//        disconnectMQTTClinet()
        
        let host = self.host
        let port = Int32(self.port)
        
        let mqttConfig = MQTTConfig(clientId: clientID, host: host, port: port, keepAlive: 10)
        
        mqttConfig.onConnectCallback = { [unowned self] returnCode in
            
            if returnCode == .success && self.isConnected.value == false {
                // something to do in case of successful connection
                print("Connected")
                self.isConnected.value = true
            } else if returnCode != .success {
                // error handling for connection failure
                print("Return Code is \(returnCode.description)")
                self.isConnected.value = false
            }
        }
        
        mqttConfig.onMessageCallback = { mqttMessage in
            print("MQTT Message received: payload=\(mqttMessage.payloadString)")
            
            // Parse string json to dict
            guard let stJson = mqttMessage.payloadString ,
                let jsonDict = DataManager.convertToDictionary(text: stJson)
                else { return }
            
            if let stCommand = jsonDict["command"] as? String, let match = MatchCommand(rawValue: stCommand) {
                self.matchCommand.value = match
            }
            
            if let stEndTurnCommandAtStadium = jsonDict["stadium"] as? String {
                self.endTurnCommandAtStadium.value = stEndTurnCommandAtStadium
            }
        }
        
        mqttConfig.onSubscribeCallback = { (messageId, grantedQos) in
            NSLog("subscribed (mid=\(messageId),grantedQos=\(grantedQos))")
        }
        
        // create connection
        mqttClient = MQTT.newConnection(mqttConfig)
        
        //  set subscribe
        mqttClient.subscribe(COMMAND_TOPIC, qos: 1)
        mqttClient.subscribe(END_TURN_TOPIC, qos: 1)
//        mqttClient.subscribe(SENSOR_TOPIC, qos: 1)
        
    }
    
    func disconnectMQTTClinet() {
        self.isConnected.value = false
        mqttClient?.disconnect()
    }
    
    static func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    // Subscribe & Public
    
    func mqttPublishMessage(message: String, withTopic topic: String) {
        
        if self.mqttClient == nil {
            return
        }
        self.mqttClient.publish(string: message, topic: topic, qos: 2, retain: false)
    }
}
