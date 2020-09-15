//
//  VMWriter.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

class VMWriter {
    
    let outputFile: FileHandle
    
    init(outputFileURL: URL) throws {
        if FileManager.default.fileExists(atPath: outputFileURL.path) == false {
            FileManager.default.createFile(atPath: outputFileURL.path, contents: nil, attributes: nil)
        }
        self.outputFile = try FileHandle(forUpdating: outputFileURL)
    }
    
    enum MemorySegment: String {
        case argument, local, ´static´ = "static", constant, this, that, pointer, temp
    }
    
    enum ArithmeticLogicalCommand: String {
        case add, sub, neg, eq, gt, lt, and, or, not
    }
    
    func writePush(segment: MemorySegment, index: Int) {
        outputFile.write(line: "push \(segment.rawValue) \(index)")
    }
    
    func writePop(segment: MemorySegment, index: Int) {
        outputFile.write(line: "pop \(segment.rawValue) \(index)")
    }
    
    func writeArithmetic(_ command: ArithmeticLogicalCommand) {
        outputFile.write(line: "\(command.rawValue)")
    }
    
    func writeLabel(_ label: String) {
        outputFile.write(line: "label \(label)")
    }
    
    func writeGoTo(label: String) {
        outputFile.write(line: "goto \(label)")
    }
    
    func writeIf(label: String) {
        outputFile.write(line: "if-goto \(label)")
    }
    
    func writeCall(functionName: String, argumentCount: Int) {
        outputFile.write(line: "call \(functionName) \(argumentCount)")
    }
    
    func writeFunction(name: String, localCount: Int) {
        outputFile.write(line: "function \(name) \(localCount)")
    }
    
    func writeReturn() {
        outputFile.write(line: "return")
    }
    
    func closeFile() {
        outputFile.closeFile()
    }
    
}
