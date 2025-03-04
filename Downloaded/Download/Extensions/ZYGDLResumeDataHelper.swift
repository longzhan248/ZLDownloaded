//
//  ZYGDLResumeDataHelper.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

// 用于处理恢复数据。
internal enum ZYGDLResumeDataHelper {
    
    // 恢复数据中的版本键。
    static let infoVersionKey = "NSURLSessionResumeInfoVersion"
    
    // 恢复数据中的当前请求键。
    static let currentRequestKey = "NSURLSessionResumeCurrentRequest"
    
    // 恢复数据中的原始请求键。
    static let originalRequestKey = "NSURLSessionResumeOriginalRequest"
    
    // 恢复数据中的字节范围键。
    static let resumeByteRangeKey = "NSURLSessionResumeByteRange"
    
    // 恢复数据中的临时文件名键。
    static let infoTempFileNameKey = "NSURLSessionResumeInfoTempFileName"
    
    // 恢复数据中的本地路径键。
    static let infoLocalPathKey = "NSURLSessionResumeInfoLocalPath"
    
    // 恢复数据中的已接收字节数键。
    static let bytesReceivedKey = "NSURLSessionResumeBytesReceived"
    
    // 恢复数据中的根对象键。
    static let archiveRootObjectKey = "NSKeyedArchiveRootObjectKey"
    
    // 用于处理恢复数据。
    internal static func handleResumeData(_ data: Data) -> Data? {
        
        if #available(iOS 11.3, *) {
            return data
        } else if #available(iOS 11.0, *) {
            // 修复 iOS 11.0 - 11.2 的恢复数据 bug。
            return deleteResumeByteRange(data)
        } else if #available(iOS 10.2, *) {
            return data
        } else if #available(iOS 10.0, *) {
            // 修复 iOS 10.0 - 10.1 的恢复数据 bug。
            return correctResumeData(data)
        } else {
            return data
        }
        
    }
    
    // 用于删除恢复数据中的字节范围。
    private static func deleteResumeByteRange(_ data: Data) -> Data? {
        // 获取恢复数据字典，如果失败则返回 nil。
        guard let resumeDictionary = getResumeDictionary(data) else {
            return nil
        }
        
        // 删除字节范围键。
        resumeDictionary.removeObject(forKey: resumeByteRangeKey)
        
        // 将修改后的字典重新编码为数据并返回。
        return try? PropertyListSerialization.data(fromPropertyList: resumeDictionary,
                                                   format: PropertyListSerialization.PropertyListFormat.xml,
                                                   options: PropertyListSerialization.WriteOptions())
    }
    
    // 用于修复恢复数据。
    private static func correctResumeData(_ data: Data) -> Data? {
        // 获取恢复数据字典，如果失败则返回 nil。
        guard let resumeDictionary = getResumeDictionary(data) else {
            return nil
        }
        
        // 修复当前请求数据。
        if let currentRequest = resumeDictionary[currentRequestKey] as? Data {
            resumeDictionary[currentRequestKey] = correct(with: currentRequest)
        }
        
        // 修复原始请求数据。
        if let originalRequest = resumeDictionary[originalRequestKey] as? Data {
            resumeDictionary[originalRequestKey] = correct(with: originalRequest)
        }
        
        // 将修改后的字典重新编码为数据并返回。
        return try? PropertyListSerialization.data(fromPropertyList: resumeDictionary,
                                                   format: PropertyListSerialization.PropertyListFormat.xml,
                                                   options: PropertyListSerialization.WriteOptions())
    }
    
    // 用于将恢复数据解析为字典。
    internal static func getResumeDictionary(_ data: Data) -> NSMutableDictionary? {
        
        // 定义一个可选的 NSDictionary 对象。
        var object: NSDictionary?
        
        if #available(OSX 10.11, iOS 9.0, *) {
            // 使用 NSKeyedUnarchiver 解码数据。
            let keyedUnarchiver = NSKeyedUnarchiver(forReadingWith: data)
            
            // 尝试解码顶级对象。
            do {
                object = try keyedUnarchiver.decodeTopLevelObject(of: NSDictionary.self, forKey: archiveRootObjectKey)
                if object == nil {
                    object = try keyedUnarchiver.decodeTopLevelObject(of: NSDictionary.self, forKey: NSKeyedArchiveRootObjectKey)
                }
            } catch {
                
            }
            
            // 完成解码。
            keyedUnarchiver.finishDecoding()
        }
        
        // 如果解码失败，尝试使用 PropertyListSerialization 解析数据。
        if object == nil {
            do {
                object = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? NSDictionary
            } catch {
                
            }
        }
        
        // 如果解析结果是 NSMutableDictionary，直接返回。
        if let resumeDictionary = object as? NSMutableDictionary {
            return resumeDictionary
        }
        
        // 否则将 NSDictionary 转换为 NSMutableDictionary 并返回。
        guard let resumeDictionary = object else { return nil }
        return NSMutableDictionary(dictionary: resumeDictionary)
        
    }
    
    // 根据版本号获取临时文件名或本地路径的最后一个路径组件。
    internal static func getTmpFileName(_ data: Data) -> String? {
        guard let resumeDictionary = ZYGDLResumeDataHelper.getResumeDictionary(data),
            let version = resumeDictionary[infoVersionKey] as? Int
        else {
            return nil
        }
        if version > 1 {
            return resumeDictionary[infoTempFileNameKey] as? String
        } else {
            guard let path = resumeDictionary[infoLocalPathKey] as? String else {
                return nil
            }
            let url = URL(fileURLWithPath: path)
            return url.lastPathComponent
        }
    }
    
    // 用于修复恢复数据中的请求数据。
    private static func correct(with data: Data) -> Data? {
        // 如果数据可以直接解码，返回数据。
        if NSKeyedUnarchiver.unarchiveObject(with: data) != nil {
            return data
        }
        
        // 尝试将数据解析为 NSMutableDictionary，如果失败则返回 nil。
        guard let resumeDictionary = try? PropertyListSerialization.propertyList(from: data,
                                                                                 options: .mutableContainersAndLeaves,
                                                                                 format: nil) as? NSMutableDictionary else {
            return nil
        }
        
        // 修正 __nsurlrequest_proto_props 对象为 $number 模式。
        var k = 0
        while ((resumeDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "$\(k)") != nil {
            k += 1
        }
        
        // 修正 __nsurlrequest_proto_prop_obj 对象。
        var i = 0
        while ((resumeDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_prop_obj_\(i)") != nil {
            let arr = resumeDictionary["$objects"] as? NSMutableArray
            if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_prop_obj_\(i)"] {
                dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                dic.removeObject(forKey: "__nsurlrequest_proto_prop_obj_\(i)")
                arr?[1] = dic
                resumeDictionary["$objects"] = arr
            }
            i += 1
        }
        
        // 修正 __nsurlrequest_proto_props 对象。
        if ((resumeDictionary["$objects"] as? NSArray)?[1] as? NSDictionary)?.object(forKey: "__nsurlrequest_proto_props") != nil {
            let arr = resumeDictionary["$objects"] as? NSMutableArray
            if let dic = arr?[1] as? NSMutableDictionary, let obj = dic["__nsurlrequest_proto_props"] {
                dic.setObject(obj, forKey: "$\(i + k)" as NSString)
                dic.removeObject(forKey: "__nsurlrequest_proto_props")
                arr?[1] = dic
                resumeDictionary["$objects"] = arr
            }
        }
        
        // 修正顶级对象键。
        if let obj = (resumeDictionary["$top"] as? NSMutableDictionary)?.object(forKey: archiveRootObjectKey) as AnyObject? {
            (resumeDictionary["$top"] as? NSMutableDictionary)?.setObject(obj, forKey: NSKeyedArchiveRootObjectKey as NSString)
            (resumeDictionary["$top"] as? NSMutableDictionary)?.removeObject(forKey: archiveRootObjectKey)
        }
        
        // 将修正后的字典重新编码为数据并返回。
        return try? PropertyListSerialization.data(fromPropertyList: resumeDictionary,
                                                   format: PropertyListSerialization.PropertyListFormat.binary,
                                                   options: PropertyListSerialization.WriteOptions())
    }
}
