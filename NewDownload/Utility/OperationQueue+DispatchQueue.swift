//
//  OperationQueue+DispatchQueue.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/27.
//

import Foundation

extension OperationQueue {
    
    convenience init(qualityOfService: QualityOfService = .default,
                     maxConCurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount,
                     underlyingQueue: DispatchQueue? = nil,
                     name: String? = nil) {
        self.init()
        self.qualityOfService = qualityOfService
        self.maxConcurrentOperationCount = maxConCurrentOperationCount
        self.underlyingQueue = underlyingQueue
        self.name = name
    }
    
}
