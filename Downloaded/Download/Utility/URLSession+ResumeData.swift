//
//  URLSession+ResumeData.swift
//  ZygoteNetwork
//
//  Created by zhanlong on 2025/2/27.
//

import Foundation

extension URLSession {
    
    /// 把有bug的resumeData修复，然后创建task
    internal func correctedDownloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask {
        let task = downloadTask(withResumeData: resumeData)
        
        if let resumeDictionary = ZYGDLResumeDataHelper.getResumeDictionary(resumeData) {
            if task.originalRequest == nil,
                let originalReqData = resumeDictionary[ZYGDLResumeDataHelper.originalRequestKey] as? Data,
               let originalRequest = NSKeyedUnarchiver.unarchiveObject(with: originalReqData) as? NSURLRequest {
                task.setValue(originalRequest, forKey: "originalRequest")
            }
            if task.currentRequest == nil,
               let currentReqData = resumeDictionary[ZYGDLResumeDataHelper.currentRequestKey] as? Data,
               let currentRequest = NSKeyedUnarchiver.unarchiveObject(with: currentReqData) as? NSURLRequest {
                task.setValue(currentRequest, forKey: "currentRequest")
            }
        }
        
        return task
    }
    
}
