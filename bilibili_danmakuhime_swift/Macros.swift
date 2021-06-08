//
//  Macros.swift
//  bilibili_swiftUI
//
//  Created by kijin_seija on 2021/5/8.
//

import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
