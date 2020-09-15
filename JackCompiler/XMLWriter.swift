//
//  XMLWriter.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

class XMLWriter {
    
    let outputFile: FileHandle
    var indentationLevel: Int = 0
    var padding: String {
        return String(repeating: " ", count: indentationLevel)
    }
    
    init(outputFileURL: URL) throws {
        if FileManager.default.fileExists(atPath: outputFileURL.path) == false {
            FileManager.default.createFile(atPath: outputFileURL.path, contents: nil, attributes: nil)
        }
        self.outputFile = try FileHandle(forUpdating: outputFileURL)
    }
    
    func write(element: String, body: () throws -> ()) throws {
        outputFile.write(line: padding + "<\(element)>")
        indentationLevel += 2
        try body()
        indentationLevel -= 2
        outputFile.write(line: padding + "</\(element)>")
    }
    
    func write(token: Token) {
        let output: String
        switch token {
        case .keyword(let keyword):
            output = "<keyword> \(keyword.rawValue) </keyword>"
        case .symbol(let symbol):
            let acceptableSymbol: String
            switch symbol {
            case .greaterThan:
                acceptableSymbol = "&gt;"
            case .lessThan:
                acceptableSymbol = "&lt;"
            case .ampersand:
                acceptableSymbol = "&amp;"
            default:
                acceptableSymbol = symbol.rawValue
            }
            output = "<symbol> \(acceptableSymbol) </symbol>"
        case .identifier(let identifier):
            output = "<identifier> \(identifier) </identifier>"
        case let .integerConstant(integerConstant):
            output = "<integerConstant> \(integerConstant) </integerConstant>"
        case let .stringConstant(stringConstant):
            output = "<stringConstant> \(stringConstant) </stringConstant>"
        }
        outputFile.write(line: padding + output)
    }
    
    func write(tag: String, value: String) {
        let output = "<\(tag)> \(value) </\(tag)>"
        outputFile.write(line: padding + output)
    }
    
    func closeFile() {
        outputFile.closeFile()
    }
}
