//
//  String+Hash.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

extension String: ZYGDLCompatible {
    
}

extension ZYGDLWrapper where Base == String {
    
    public var md5: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        return data.tr.md5
    }
    
    public var sha1: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        return data.tr.sha1
    }
    
    public var sha256: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        return data.tr.sha256
    }
    
    public var sha512: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        return data.tr.sha512
    }
    
}
