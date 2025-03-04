//
//  CodingUserInfoKey+Cache.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/20.
//

import Foundation

extension CodingUserInfoKey {
    
    internal static let cache = CodingUserInfoKey(rawValue: "com.ZYG.Downloaded.CodingUserInfoKey.cache")!
    
    internal static let operationQueue = CodingUserInfoKey(rawValue: "com.ZYG.Downloaded.CodingUserInfoKey.operationQueue")!
    
}
