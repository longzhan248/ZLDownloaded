//
//  ZYGDLBGURLConvertible.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/3/4.
//

import Foundation

@objc public protocol ZYGDLBGURLConvertible {
    
    func bg_asURL() throws -> URL
    
}

internal func asURLConvertible(_ url: ZYGDLBGURLConvertible) -> ZYGDLURLConvertible {
    if let temp = url as? NSString {
        return temp as String
    } else if let temp = url as? NSURL {
        return temp as URL
    } else {
        return url as! URLComponents
    }
}

extension NSString: ZYGDLBGURLConvertible {
    
    internal func asURLConvertible() -> ZYGDLURLConvertible {
        return self as String
    }
    
    public func bg_asURL() throws -> URL {
        return try self.asURLConvertible().asURL()
    }
    
}

extension NSURL: ZYGDLBGURLConvertible {
    
    internal func asURLConvertible() -> ZYGDLURLConvertible {
        return self as URL
    }
    
    public func bg_asURL() throws -> URL {
        return try self.asURLConvertible().asURL()
    }
}

extension NSURLComponents: ZYGDLBGURLConvertible {
    
    internal func asURLConvertible() -> ZYGDLURLConvertible {
        return self as URLComponents
    }
    
    public func bg_asURL() throws -> URL {
        return try self.asURLConvertible().asURL()
    }
}
