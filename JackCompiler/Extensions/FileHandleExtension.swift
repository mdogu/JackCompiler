//
//  FileHandleExtensions.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

extension FileHandle {
    
    func readLine() -> String? {
        var line: String?
        let delimeter = "\n"
        let delimeterData = delimeter.data(using: .utf8)!
        let chunkSize = 4096
        var buffer = Data(capacity: chunkSize)
        
        while true {
            let data = readData(ofLength: chunkSize)
            if let range = data.range(of: delimeterData) {
                // Delimeter found, get the string up to the delimeter
                let dataBeforeDelimeter = data.subdata(in: 0..<range.lowerBound)
                buffer.append(dataBeforeDelimeter)
                line = String(data: buffer, encoding: .utf8)
                // Find the offset after the delimeter and set the offset
                let remainderDataCount = data.count - range.upperBound
                if remainderDataCount > 0 {
                    seek(toFileOffset: offsetInFile - UInt64(remainderDataCount))
                }
                break
            } else {
                if data.count == chunkSize {
                    // Delimeter not found, continue to next chunk
                    continue
                } else {
                    // Last line or EOF
                    if data.count > 0 {
                        buffer.append(data)
                    }
                    if buffer.count > 0 {
                        line = String(data: buffer, encoding: .utf8)
                    }
                    break
                }
            }
        }
        // Text files created in Windows have \r (carriage return) before \n (line feed)
        return line?.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
    }
    
    func write(line: String) {
        let data = (line + "\n").data(using: .ascii)!
        write(data)
    }
    
}
