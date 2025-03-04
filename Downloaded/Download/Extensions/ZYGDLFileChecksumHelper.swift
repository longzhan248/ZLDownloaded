//
//  ZYGDLFileChecksumHelper.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/19.
//

import Foundation

// 文件校验
public enum ZYGDLFileChecksumHelper {
    
    // 表示校验和的类型
    public enum VerificationType: Int {
        // MD5 校验和。
        case md5
        // SHA1 校验和。
        case sha1
        // SHA256 校验和。
        case sha256
        // SHA512 校验和。
        case sha512
    }
    
    // 表示文件校验和的错误类型。
    public enum FileVerificationError: Error {
        // 校验码为空的错误。
        case codeEmpty
        // 校验码不匹配的错误，包含校验码。
        case codeMismatch(code: String)
        // 文件不存在的错误，包含文件路径。
        case fileDoesnotExist(path: String)
        // 读取数据失败的错误，包含文件路径。
        case readDataFailed(path: String)
    }
    
    // 用于执行文件校验和操作。
    private static let ioQueue: DispatchQueue = DispatchQueue(label: "com.ZYG.Downloaded.FileChecksumHelper.ioQueue", attributes: .concurrent)
    
    // 公开的静态方法 validateFile，用于验证文件的校验和。
    // 参数 filePath 是文件路径，code 是校验码，type 是校验和类型，completion 是验证结果的回调。
    public static func validateFile(_ filePath: String,
                                    code: String,
                                    type: VerificationType,
                                    completion: @escaping (Result<Bool, FileVerificationError>) -> ()) {
        // 如果校验码为空，调用回调返回 codeEmpty 错误，并返回。
        if code.isEmpty {
            completion(.failure(FileVerificationError.codeEmpty))
            return
        }
        
        ioQueue.async {
            // 在 ioQueue 队列中异步执行文件校验和操作。
            guard FileManager.default.fileExists(atPath: filePath) else {
                completion(.failure(FileVerificationError.fileDoesnotExist(path: filePath)))
                return
            }
            
            // 创建文件的 URL。
            let url = URL(fileURLWithPath: filePath)
            
            do {
                // 尝试读取文件数据。
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                
                // 用于存储计算的校验和。
                var string: String
                
                // 根据校验和类型计算文件的校验和。
                switch type {
                case .md5:
                    string = data.tr.md5
                case .sha1:
                    string = data.tr.sha1
                case .sha256:
                    string = data.tr.sha256
                case .sha512:
                    string = data.tr.sha512
                }
                
                // 比较计算的校验和和提供的校验码是否匹配。
                let isCorrect = string.lowercased() == code.lowercased()
                
                // 如果匹配，调用回调返回成功，否则返回 codeMismatch 错误。
                if isCorrect {
                    completion(.success(true))
                } else {
                    completion(.failure(FileVerificationError.codeMismatch(code: code)))
                }
                
            } catch {
                // 如果读取数据失败，调用回调返回 readDataFailed 错误。
                completion(.failure(FileVerificationError.readDataFailed(path: filePath)))
            }
        }
    }
    
}

// 扩展 FileVerificationError 以实现 LocalizedError 协议。
extension ZYGDLFileChecksumHelper.FileVerificationError: LocalizedError {
    
    // 提供本地化的错误描述。
    public var errorDescription: String? {
        
        switch self {
        case .codeEmpty:
            // 返回校验码为空的错误描述。
            return "verification code is empty"
            
        case let .codeMismatch(code):
            // 返回校验码不匹配的错误描述。
            return "verification code mismatch, code: \(code)"
            
        case let .fileDoesnotExist(path):
            // 返回文件不存在的错误描述。
            return "file does not exist, path: \(path)"
            
        case let .readDataFailed(path):
            // 返回读取数据失败的错误描述。
            return "read data failed, path: \(path)"
        }
        
    }
    
}
