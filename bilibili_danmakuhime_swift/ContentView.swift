//
//  ContentView.swift
//  bilibili_danmakuhime_swift
//
//  Created by kijin_seija on 2021/6/8.
//

import SwiftUI

struct ContentView: View {
    
    @State var searchKey = ""
    @ObservedObject private var model = DanmakuModel()
    
    var body: some View  {
        VStack {
            HStack {
                TextField("请输入直播间号码", text: $searchKey)
                    .frame(height: 40)
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.leading)
                    .keyboardType(.numberPad)
                
                Button(action: {
                    hideKeyboard()
                    model.connectRoom(room_id: searchKey)
                }, label: {
                    Text("搜索")
                        .padding()
                        .foregroundColor(.blue)
                })
                .buttonStyle(PlainButtonStyle())
            }
            .background(Color.black.opacity(0.2))
            .padding()
            
            List {
                ForEach(model.msgList) { message in
                    
                    if message.type == DanmakuModel.DanmakuMessageType.normalMessage {
                        Text("\(message.name) : \(message.msg)")
                    }else {
                        Text("\(message.sinleGift?.name ?? "") \(message.sinleGift?.action ?? "") \(message.sinleGift?.gift ?? "") × \(message.sinleGift?.count ?? "")")
                            .font(.headline)
                            .foregroundColor(Color(#colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)))
                    }
                }
            }
            .animation(.easeInOut)
            Spacer()
            
            //只有一条, 展示一段时间后会删除
            ForEach (model.comboGiftList) {gift in
                Text("\(gift.name)\(gift.action)\(gift.gift) 共 \(gift.count)个")
                    .font(.headline)
                    .foregroundColor(Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)))
                    .padding()
            }
            
            Text("\(model.enterRoomList.last?.name ?? "-----") 进入直播间")
                .background(Color.white)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
