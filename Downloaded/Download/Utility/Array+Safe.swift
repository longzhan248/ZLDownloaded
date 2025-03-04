//
//  Array+Safe.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/27.
//

import Foundation

extension Array {
    
    public func safeObject(at index: Int) -> Element? {
        if (0..<count).contains(index) {
            return self[index]
        } else {
            return nil
        }
    }
    
}
