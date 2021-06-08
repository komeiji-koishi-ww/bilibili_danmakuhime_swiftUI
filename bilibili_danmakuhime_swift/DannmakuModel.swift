//
//  DanmakuModel.swift
//  bilibili_swiftUI (iOS)
//
//  Created by kijin_seija on 2021/5/28.
//

import SwiftUI
import Combine

class DanmakuModel: ObservableObject {
    
    enum DanmakuMessageType: Int {
        case normalMessage
        case singleGift
    }
    
    //单条投喂在弹幕消息列表里
    struct DanmakuMsg : Identifiable {
        var id = UUID()
        var type : DanmakuMessageType
        var name : String
        var msg : String
        var sinleGift : DanmakuGift?
    }
    
    //连击礼物显示在屏幕下方
    struct DanmakuGift : Identifiable {
        var id = UUID()
        var name : String
        var action : String
        var gift : String
        var count : String
    }
    
    struct DanmakuEnter : Identifiable {
        var id = UUID()
        var name : String
        var card : String
        var level : Int
    }
    
    @Published var msgList : [DanmakuMsg] = []
    @Published var enterRoomList : [DanmakuEnter] = []
    @Published var comboGiftList : [DanmakuGift] = []
    
    private var tempEnterList : [DanmakuEnter] = []
    private var enterRoomIndex : Int = 0
    
    private var tempComboGiftList : [DanmakuGift] = []
    private var comboGiftIndex : Int = 0
    
    private var enterRoomTimer : Timer? = nil
    private var comboGiftTimer : Timer? = nil
    
    private let requester = DanmakuRequester.shared
    
    func connectRoom(room_id: String) {
        
        if room_id.count == 0 || Int(room_id) == 0 {
            return
        }
        
        //加入房间
        requester.connect(room_id: Int(room_id) ?? 0)
        
        //接收弹幕消息
        requester.DanmakuMsgCallBack = {(msg: DanmakuMsg) in
            self.msgList.insert(msg, at: 0)
        }
        
        //加入房间记录先append到临时集合, 延时处理
        requester.DanmakuEnterCallBack = {(enter: DanmakuEnter) in
            self.tempEnterList.append(enter)
        }
        
        //同一时间append多条进入房间数据UI来不及刷新, 延时读取temp数组保证UI显示.  如果短时间内进入过多观众未处理
        enterRoomTimer = Timer(timeInterval: 0.5, repeats: true, block: { timer in
            
            self.enterRoomList.removeAll()
            
            if self.tempEnterList.count == 0 || self.enterRoomIndex >= self.tempEnterList.count {
                return
            }
            
            self.enterRoomList.append(self.tempEnterList[self.enterRoomIndex])
            self.enterRoomIndex += 1
        })
        
        RunLoop.current.add(enterRoomTimer!, forMode: .common)
        
        //连击礼物, 显示到页面底部
        requester.DanmakuComboGiftCallBack = { comboGift in
            self.tempComboGiftList.append(comboGift)
        }
        
        //打赏礼物控制显示时间, 与enterRoom一样处理
        comboGiftTimer = Timer(timeInterval: 1.5, repeats: true, block: { timer in
            
            self.comboGiftList.removeAll()
            
            if self.tempComboGiftList.count == 0 || self.comboGiftIndex >= self.tempComboGiftList.count {
                return
            }
            
            self.comboGiftList.append(self.tempComboGiftList[self.comboGiftIndex])
            self.comboGiftIndex += 1
        })
        
        RunLoop.current.add(comboGiftTimer!, forMode: .common)
        
        //投喂礼物, insert到弹幕列表
        requester.DanmakuSendGiftCallBack = { gift in
            self.msgList.insert(gift, at: 0)
        }
        
        //重置数据
        requester.DanmakuCloseCallBack = {
            self.enterRoomList.removeAll()
            self.tempEnterList.removeAll()
            self.msgList.removeAll()
            self.enterRoomIndex = 0
            self.comboGiftIndex = 0
        }
        
    }
    
}
