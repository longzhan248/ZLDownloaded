//
//  FileManager+AvailableCapacity.swift
//  ZLDownloaded
//
//  Created by zhanlong on 2025/9/4.
//

import Foundation

extension FileManager: ZYGDLCompatible {}

extension ZYGDLWrapper where Base: FileManager {
    
    public var freeDiskSpaceInBytes: Int64 {
        if let space = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [
                URLResourceKey.volumeAvailableCapacityForImportantUsageKey
            ]).volumeAvailableCapacityForImportantUsage
        {
            return space
        } else {
            return 0
        }
    }
    
}
