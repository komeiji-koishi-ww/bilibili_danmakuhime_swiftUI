//
//  DanmakuSocketRequester.swift
//  bilibili_swiftUI (iOS)
//
//  Created by kijin_seija on 2021/5/10.
//

import Foundation
import Starscream
import Alamofire
import SwiftyJSON
import SWCompression


enum OpreationCode : Int {
    case AUTH = 7
    case HEARTBEAT = 2
}

class DanmakuRequester: NSObject {
    
    //房间ID
    var room_id : Int = 0
    //token, 根据接口获得
    var websocketServerToken : String = ""
    
    //创建socket客户端
    var socket : WebSocket = WebSocket(request: URLRequest(url: URL(string: "wss://broadcastlv.chat.bilibili.com:443/sub")!))
    
    //心跳包定时器
    private var timer : Timer?
    
    //弹幕消息回调
    typealias danmakuMsgCallBack = (DanmakuModel.DanmakuMsg) -> Void
    var DanmakuMsgCallBack: danmakuMsgCallBack?
    
    //进入房间回调
    typealias danmakuEnterCallBack = (DanmakuModel.DanmakuEnter) -> Void
    var DanmakuEnterCallBack : danmakuEnterCallBack?
    
    //投喂礼物回调
    typealias danmakuSendGiftCallBack = (DanmakuModel.DanmakuMsg) -> Void
    var DanmakuSendGiftCallBack : danmakuSendGiftCallBack?
    
    //连击礼物回调
    typealias danmakuComboGiftCallBack = (DanmakuModel.DanmakuGift) -> Void
    var DanmakuComboGiftCallBack : danmakuComboGiftCallBack?
    
    //离开房间回调
    typealias danmakuCloseCallBack = () -> Void
    var DanmakuCloseCallBack : danmakuCloseCallBack?
    
    //单例对象
    static let shared = DanmakuRequester()
    
    override init() {
        super.init()
        self.socket.delegate = self;
    }
    
    //获取真实直播间ID
    func connect(room_id: Int) {
        
        let url = "https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom?room_id=\(room_id)"
        AF.request(url, method: .get).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                let dict = JSON(data)
                
                //真实直播间ID
                self.room_id = dict["data"].dictionaryValue["room_info"]!.dictionaryValue["room_id"]?.intValue ?? 0
                
                //获取websocketServerToken
                self.Danmaku_servers()
                
                break
            case .failure(_):
                break
            }
        }
    }
    
    func Danmaku_servers () {
        
        let hostlist_url = "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?id=\(self.room_id)&type=0"
        
        AF.request(hostlist_url, method: .get).responseJSON { (response) in
            
            switch response.result {
            
            case .success(let data):
                
                let dict = JSON(data)
                
                self.websocketServerToken = dict["data"].dictionaryValue["token"]?.stringValue ?? ""
                
                //连接之前清空可能存在的状态
                self.timer?.invalidate()
                self.DanmakuCloseCallBack!()
                
                //连接socket, 转到starScream代理方法中
                self.socket.connect()
                
                break
            case .failure(_):
                break
            }
        }
        
    }
    
}

extension DanmakuRequester : WebSocketDelegate{
    
    //接收socket事件
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        
        switch event {
        
        //已经连接
        case .connected(let headers):
            print("websocket is connected: \(headers)")
            
            //拼接认证包
            let sendData = self.packet(OpreationCode.AUTH.rawValue)
            
            //发送认证包
            self.socket.write(data: sendData, completion: {
                
                //发送成功, 开始发送心跳包
                self.performSelector(onMainThread: #selector(self.startSendHeartBeat), with: nil, waitUntilDone: false)
            })
            
        case .disconnected(let reason, let code):
            
            print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            print("Received text: \(string)")
        case .binary(let data):
            //处理包
            self.danmakuPacketFilt(data: data)
        case .ping(_),
             .pong(_),
             .viabilityChanged(_),
             .reconnectSuggested(_):
            print("do nothing")
        case .cancelled, .error(_):
            self.timer?.invalidate()
        }
    }
    
    @objc func startSendHeartBeat () {
        
        //数据包定时器
        self.timer = Timer(timeInterval: 15, repeats: true, block: { timer in
            //发送心跳包
            let sendData = self.packet(OpreationCode.HEARTBEAT.rawValue)
            self.socket.write(data: sendData) {
                print("heartBeat")
            }
        })
        
        //添加至runloop
        RunLoop.current.add(self.timer!, forMode: .common)
    }
    
    //拼接数据包
    func packet(_ type:Int) -> Data {
        
        //数据包
        var bodyDatas = Data()
        
        if (type == OpreationCode.AUTH.rawValue){
            
            //认证包
            let str = "{\"uid\": 0,\"roomid\": \(self.room_id),\"protover\": 2,\"platform\": \"web\",\"type\": 2,\"clientver\": \"1.14.3\",\"key\": \"\(self.websocketServerToken)\"}"
            
            bodyDatas = str.data(using: String.Encoding.utf8)!
            
        }else {
            
            //心跳包
            bodyDatas = "{}".data(using: String.Encoding.utf8)!
        }
        
        //header总长度,  body长度+header长度
        var len:UInt32 = CFSwapInt32HostToBig(UInt32(bodyDatas.count + 16))
        let lengthData = Data(bytes: &len, count: 4)
        
        //header长度, 固定16
        var headerLen:UInt16 = CFSwapInt16HostToBig(UInt16(16))
        let headerLenghData = Data(bytes: &headerLen, count: 2)
        
        //协议版本
        var versionLen:UInt16 = CFSwapInt16HostToBig(UInt16(1))
        let versionLenData = Data(bytes: &versionLen, count: 2)
        
        //操作码
        var optionCode:UInt32 = CFSwapInt32HostToBig(UInt32(type))
        let optionCodeData = Data(bytes: &optionCode, count: 4)
        
        //数据包头部长度（固定为 1）
        var bodyHeaderLength:UInt32 = CFSwapInt32HostToBig(UInt32(1))
        let bodyHeaderLengthData = Data(bytes: &bodyHeaderLength, count: 4)
        
        //按顺序添加到数据包中
        var packData = Data()
        packData.append(lengthData)
        packData.append(headerLenghData)
        packData.append(versionLenData)
        packData.append(optionCodeData)
        packData.append(bodyHeaderLengthData)
        packData.append(bodyDatas)
        
        return packData
    }
    
    
    /// 处理字节流
    /// - Parameter data: socket服务器返回的数据包
    ///
    func danmakuPacketFilt(data: Data) {
        
        //数据包头部, 固定16byte
        let headerFrame = data.subdata(in:Range(NSRange(location: 0, length: 16))!)
        
        //操作码, 固定4byte
        let opcode = headerFrame.subdata(in:Range(NSRange(location: 8, length: 4))!).fourbytesToInt()
        
        //切除头部, 获取body, body经过zlib压缩,  需要zlib解压.body中可能包含多段小数据包,
        let zipData = data.subdata(in: Range(NSRange(location: 16, length: data.count-16))!)
        
        if opcode == 5 {
            
            //解压zlib数据包
            guard let unzipData = try?ZlibArchive.unarchive(archive: zipData) else {
                return
            }
            
            //处理解压后的body
            self.subPacketFilt(data: unzipData)
        }
        
    }
    
    func subPacketFilt(data: Data) {
        
        //可能为1个或多个数据包连接在一起, 先获取body长度
        let frameBodyLength = data.subdata(in: Range(NSRange(location: 0, length: 4))!).fourbytesToInt()
        
        //判断是否有长度
        if frameBodyLength != 0 {
            
            //切出本次之后的剩余部分, 继续调用此方法切割
            let restData = data.subdata(in: Range(NSRange(location: frameBodyLength, length: data.count-frameBodyLength))!)
            subPacketFilt(data: restData)
            
            //处理本次数据包
            let subData = data.subdata(in: Range(NSRange(location: 0, length: frameBodyLength))!)
            
            //去除头部
            let subDataBody = subData.subdata(in: Range(NSRange(location: 16, length: subData.count-16))!)
            //转成json
            self.msgHandler(data: JSON(subDataBody))
        }
    }
    
    //处理json 没什么好写的
    func msgHandler (data: JSON) {
        
        print(data["cmd"])
        
        if (data["cmd"].stringValue.contains("DANMU_MSG")){
            
            self.DanmakuMsgCallBack!(
                DanmakuModel.DanmakuMsg(
                    type: DanmakuModel.DanmakuMessageType.normalMessage,
                    name: data["info"].arrayValue[2].arrayValue[1].stringValue ,
                    msg:
                        data["info"].arrayValue[1].stringValue))
            
        } else if (data["cmd"].stringValue == "INTERACT_WORD") {
            
            let model = DanmakuModel.DanmakuEnter(
                name:
                    data["data"].dictionaryValue["uname"]!.stringValue,
                card: data["data"].dictionaryValue["fans_medal"]?.dictionaryValue["medal_name"]?.stringValue ?? "",
                level: data["data"].dictionaryValue["fans_medal"]?.dictionaryValue["medal_level"]?.intValue ?? 0)
            
            self.DanmakuEnterCallBack!(model)
            
        }else if (data["cmd"].stringValue == "SEND_GIFT") {
            let model = DanmakuModel.DanmakuMsg(
                type: DanmakuModel.DanmakuMessageType.singleGift,
                name: "",
                msg: "",
                sinleGift: DanmakuModel.DanmakuGift(
                    name: data["data"].dictionaryValue["uname"]?.stringValue ?? "",
                    action: data["data"].dictionaryValue["action"]?.stringValue ?? "",
                    gift: data["data"].dictionaryValue["giftName"]?.stringValue ?? "",
                    count: data["data"].dictionaryValue["num"]?.stringValue ?? ""
                ))
            
            self.DanmakuSendGiftCallBack!(model)
            
        }else if (data["cmd"].stringValue == "COMBO_SEND") {
            
            let model = DanmakuModel.DanmakuGift(
                name: data["data"].dictionaryValue["uname"]?.stringValue ?? "",
                action: data["data"].dictionaryValue["action"]?.stringValue ?? "",
                gift: data["data"].dictionaryValue["gift_name"]?.stringValue ?? "",
                count: data["data"].dictionaryValue["total_num"]?.stringValue ?? "")
            
            self.DanmakuComboGiftCallBack!(model)
        }
    }
}

extension Data {
    //4bytes转Int
    func fourbytesToInt() -> Int {
        var value : UInt32 = 0
        let data = NSData(bytes: [UInt8](self), length: self.count)
        data.getBytes(&value, length: self.count)
        value = UInt32(bigEndian: value)
        return Int(value)
    }
}


