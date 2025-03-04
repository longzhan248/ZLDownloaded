//
//  ZYGDLURLConvertible.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

public protocol ZYGDLURLConvertible {
    
    // 实现一个方法 asURL，用于将对象转换为 URL。
    func asURL() throws -> URL
    
}

// 扩展 String 以实现 ZYGDLURLConvertible 协议。
extension String: ZYGDLURLConvertible {
    
    public func asURL() throws -> URL {
        // 尝试将字符串转换为 URL，如果失败则抛出 invalidURL 错误。
        guard let url = URL(string: self) else { throw ZYGDLError.invalidURL(url: self) }
        
        // 返回转换后的 URL。
        return url
    }
    
}

// 扩展 URL 以实现 URLConvertible 协议。
extension URL: ZYGDLURLConvertible {
    
    public func asURL() throws -> URL {
        return self
    }
    
}

// 扩展 URLComponents 以实现 URLConvertible 协议。
extension URLComponents: ZYGDLURLConvertible {
    
    public func asURL() throws -> URL {
        // 尝试将 URLComponents 转换为 URL，如果失败则抛出 invalidURL 错误。
        guard let url = url else { throw ZYGDLError.invalidURL(url: self) }
        
        // 返回转换后的 URL。
        return url
    }
    
}
