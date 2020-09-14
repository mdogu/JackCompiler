//
//  main.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

guard CommandLine.argc == 2 else {
    Console.error("Usage: JackCompiler source")
    exit(0)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let inputFiles: [URL]
let workingFolder: URL
let outputFolder: URL

if inputURL.lastPathComponent.ends(with: ".jack") {
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
        Console.error("File does not exist")
        exit(0)
    }
    inputFiles = [inputURL]
    workingFolder = inputURL.deletingLastPathComponent()
} else {
    if FileManager.default.isDirectory(url: inputURL) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: inputURL, includingPropertiesForKeys: [])
            guard files.count > 0 else {
                Console.error("Empty Directory")
                exit(0)
            }
            let inputs = files.filter { $0.lastPathComponent.ends(with: ".jack") }
            guard inputs.count > 0 else {
                Console.error("Directory contains no .jack files")
                exit(0)
            }
            inputFiles = inputs
            workingFolder = inputURL
        } catch {
            Console.error(error.localizedDescription)
            exit(0)
        }
    } else {
        Console.error("Argument should be a Jack file or a directory containing Jack file(s)")
        exit(0)
    }
}

// MARK: Symbol Table Test

outputFolder = workingFolder.appendingPathComponent("output")
if FileManager.default.fileExists(atPath: outputFolder.path) == false {
    do {
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
    } catch {
        Console.error(error.localizedDescription)
        exit(0)
    }
}

do {
    for inputFile in inputFiles {
        let tokenizer = try JackTokenizer(inputFileURL: inputFile)
        let outputFileName = inputFile.lastPathComponent.replacingOccurrences(of: ".jack", with: ".xml")
        let outputFile = outputFolder.appendingPathComponent(outputFileName)
        let xmlWriter = try XMLWriter(outputFileURL: outputFile)
        let compiler = CompilationEngine(tokenizer: tokenizer, writer: xmlWriter)
        try compiler.compile()
    }
} catch {
    Console.error(error.localizedDescription)
    exit(0)
}


// MARK: Code Generation Test




