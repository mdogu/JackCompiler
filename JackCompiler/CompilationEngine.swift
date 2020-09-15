//
//  CompilationEngine.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

class CompilationEngine {
    
    struct CompilationError: Error {
        var localizedDescription: String
    }
    
    let tokenizer: JackTokenizer
    let writer: VMWriter
    let symbolTable: SymbolTable
    
    var className: String!
    
    var labelIndex = 0
    
    private var lastToken: Token?
    private var didConsumeLastToken: Bool = true
    var nextToken: Token? {
        if didConsumeLastToken {
            lastToken = tokenizer.nextToken()
            didConsumeLastToken = false
        }
        return lastToken
    }
    
    let typeTokens: [Token] = [.keyword(.int), .keyword(.char), .keyword(.boolean), .identifierType]
    let operationTokens: [Token] = [.symbol(.plus), .symbol(.minus), .symbol(.asterisk), .symbol(.slash), .symbol(.ampersand), .symbol(.pipe), .symbol(.lessThan), .symbol(.greaterThan), .symbol(.equal)]
    let unaryOperationTokens: [Token] = [.symbol(.minus), .symbol(.tilde)]
    let keywordConstants: [Token] = [.keyword(.´true´), .keyword(.´false´), .keyword(.null), .keyword(.this)]
    
    // MARK: Public Methods
    
    init(tokenizer: JackTokenizer, writer: VMWriter, symbolTable: SymbolTable) {
        self.tokenizer = tokenizer
        self.writer = writer
        self.symbolTable = symbolTable
    }
    
    func compile() throws {
        try compileClass()
        closeFile()
    }
    
    // MARK: Compile Methods
    
    func compileClass() throws {
        try expect(tokens: [.keyword(.´class´)])
        try expect(tokens: [.identifierType])
        className = lastToken!.text
        guard className.first!.isUppercase else {
            throw error(message: "Class names should start with uppercase.")
        }
        try expect(tokens: [.symbol(.openingCurlyBrace)])
        while check(nextToken, in: [.keyword(.´static´), .keyword(.field)]) {
            try compileClassVarDec()
        }
        while check(nextToken, in: [.keyword(.constructor), .keyword(.function), .keyword(.method)]) {
            try compileSubroutine()
        }
        try expect(tokens: [.symbol(.closingCurlyBrace)])
    }
    
    func compileClassVarDec() throws {
        try expect(tokens: [.keyword(.´static´), .keyword(.field)])
        let kind: SymbolTable.Data.Kind
        switch lastToken! {
        case .keyword(.´static´):
            kind = .´static´
        case .keyword(.field):
            kind = .field
        default:
            throw error(message: "Data Inconsistency")
        }
        
        try expect(tokens: typeTokens)
        let type = SymbolTable.Data.DataType(rawValue: lastToken!.text)
        
        try expect(tokens: [.identifierType])
        let identifier = lastToken!.text
        
        symbolTable.define(name: identifier, type: type, kind: kind)
        
        while nextToken == .symbol(.comma) {
            try expect(tokens: [.symbol(.comma)])
            try expect(tokens: [.identifierType])
            symbolTable.define(name: lastToken!.text, type: type, kind: kind)
        }
        try expect(tokens: [.symbol(.semicolon)])
    }
    
    func compileSubroutine() throws {
        symbolTable.resetSubroutine()
        try expect(tokens: [.keyword(.constructor), .keyword(.function), .keyword(.method)])
        let subroutineToken = lastToken!
        if case .keyword(.method) = subroutineToken {
            symbolTable.argumentIndex = 1
        }
        try expect(tokens: [.keyword(.void)] + typeTokens)
        try expect(tokens: [.identifierType])
        let functionName = lastToken!.text
        try expect(tokens: [.symbol(.openingParanthesis)])
        try compileParameterList()
        try expect(tokens: [.symbol(.closingParanthesis)])
        try expect(tokens: [.symbol(.openingCurlyBrace)])
        var localVariableCount = 0
        while nextToken == .keyword(.´var´) {
            try compileVarDec(localCount: &localVariableCount)
        }
        
        writer.writeFunction(name: "\(className!).\(functionName)", localCount: localVariableCount)
        
        switch subroutineToken {
        case .keyword(.constructor):
            writer.writePush(segment: .constant, index: symbolTable.fieldIndex)
            writer.writeCall(functionName: "Memory.alloc", argumentCount: 1)
            writer.writePop(segment: .pointer, index: 0)
        case .keyword(.method):
            writer.writePush(segment: .argument, index: 0)
            writer.writePop(segment: .pointer, index: 0)
        default:
            break
        }
        
        try compileStatements()
        try expect(tokens: [.symbol(.closingCurlyBrace)])
    }
    
    func compileParameterList() throws {
        if check(nextToken, in: typeTokens) {
            try expect(tokens: typeTokens)
            var type = SymbolTable.Data.DataType(rawValue: lastToken!.text)
            try expect(tokens: [.identifierType])
            symbolTable.define(name: lastToken!.text, type: type, kind: .argument)
            while check(nextToken, in: [.symbol(.comma)]) {
                try expect(tokens: [.symbol(.comma)])
                try expect(tokens: typeTokens)
                type = SymbolTable.Data.DataType(rawValue: lastToken!.text)
                try expect(tokens: [.identifierType])
                symbolTable.define(name: lastToken!.text, type: type, kind: .argument)
            }
        }
    }
    
    func compileVarDec(localCount: inout Int) throws {
        try expect(tokens: [.keyword(.´var´)])
        try expect(tokens: typeTokens)
        let type = SymbolTable.Data.DataType(rawValue: lastToken!.text)
        try expect(tokens: [.identifierType])
        symbolTable.define(name: lastToken!.text, type: type, kind: .´var´)
        localCount += 1
        while check(nextToken, in: [.symbol(.comma)]) {
            try expect(tokens: [.symbol(.comma)])
            try expect(tokens: [.identifierType])
            symbolTable.define(name: lastToken!.text, type: type, kind: .´var´)
            localCount += 1
        }
        try expect(tokens: [.symbol(.semicolon)])
    }
    
    func compileStatements() throws {
        while check(nextToken, in: [.keyword(.´let´), .keyword(.´if´), .keyword(.´while´), .keyword(.´do´), .keyword(.´return´)]) {
            switch nextToken! {
            case .keyword(.´let´):
                try compileLet()
            case .keyword(.´if´):
                try compileIf()
            case .keyword(.´while´):
                try compileWhile()
            case .keyword(.´do´):
                try compileDo()
            case .keyword(.´return´):
                try compileReturn()
            default:
                break
            }
        }
    }
    
    func compileLet() throws {
        
        func rightHandSide() throws{
            try expect(tokens: [.symbol(.equal)])
            try compileExpression()
            try expect(tokens: [.symbol(.semicolon)])
        }
        
        try expect(tokens: [.keyword(.´let´)])
        try expect(tokens: [.identifierType])
        let data = symbolTable.data(for: lastToken!.text)!
        if nextToken == .symbol(.openingBracket) {
            guard case .object(let className) = data.type, className == "Array" else {
                throw error(message: "Indexing a non-array type")
            }
            writer.writePush(segment: data.kind.memorySegment, index: data.index)
            try expect(tokens: [.symbol(.openingBracket)])
            try compileExpression()
            try expect(tokens: [.symbol(.closingBracket)])
            writer.writeArithmetic(.add)
            try rightHandSide()
            writer.writePop(segment: .temp, index: 0)
            writer.writePop(segment: .pointer, index: 1)
            writer.writePush(segment: .temp, index: 0)
            writer.writePop(segment: .that, index: 0)
        } else {
            try rightHandSide()
            writer.writePop(segment: data.kind.memorySegment, index: data.index)
        }
    }
    
    func compileIf() throws {
        let l1 = getLabelName()
        let l2 = getLabelName()
        try expect(tokens: [.keyword(.´if´)])
        try expect(tokens: [.symbol(.openingParanthesis)])
        try compileExpression()
        writer.writeArithmetic(.not)
        try expect(tokens: [.symbol(.closingParanthesis)])
        writer.writeIf(label: l1)
        try expect(tokens: [.symbol(.openingCurlyBrace)])
        try compileStatements()
        try expect(tokens: [.symbol(.closingCurlyBrace)])
        writer.writeGoTo(label: l2)
        writer.writeLabel(l1)
        if nextToken == .keyword(.´else´) {
            try expect(tokens: [.keyword(.´else´)])
            try expect(tokens: [.symbol(.openingCurlyBrace)])
            try compileStatements()
            try expect(tokens: [.symbol(.closingCurlyBrace)])
        }
        writer.writeLabel(l2)
    }
    
    func compileWhile() throws {
        let l1 = getLabelName()
        let l2 = getLabelName()
        try expect(tokens: [.keyword(.´while´)])
        try expect(tokens: [.symbol(.openingParanthesis)])
        writer.writeLabel(l1)
        try compileExpression()
        writer.writeArithmetic(.not)
        try expect(tokens: [.symbol(.closingParanthesis)])
        writer.writeIf(label: l2)
        try expect(tokens: [.symbol(.openingCurlyBrace)])
        try compileStatements()
        try expect(tokens: [.symbol(.closingCurlyBrace)])
        writer.writeGoTo(label: l1)
        writer.writeLabel(l2)
    }
    
    func compileDo() throws {
        try expect(tokens: [.keyword(.´do´)])
        try expect(tokens: [.identifierType])
        let identifier = lastToken!.text
        let data = symbolTable.data(for: identifier)
        try expect(tokens: [.symbol(.openingParanthesis), .symbol(.dot)])
        var argumentCount = 0
        if lastToken == .symbol(.openingParanthesis) {
            argumentCount = 1
            writer.writePush(segment: .pointer, index: 0)
            try compileExpressionList(&argumentCount)
            try expect(tokens: [.symbol(.closingParanthesis)])
            writer.writeCall(functionName: "\(className!).\(identifier)", argumentCount: argumentCount)
        } else if lastToken == .symbol(.dot) {
            let className: String
            if data != nil, case .object(let name) = data!.type {
                writer.writePush(segment: data!.kind.memorySegment, index: data!.index)
                argumentCount = 1
                className = name
            } else {
                guard identifier.first!.isUppercase else {
                    throw error(message: "Class names should start with uppercase.")
                }
                className = identifier
            }
            try expect(tokens: [.identifierType])
            let functionName = lastToken!.text
            try expect(tokens: [.symbol(.openingParanthesis)])
            try compileExpressionList(&argumentCount)
            try expect(tokens: [.symbol(.closingParanthesis)])
            writer.writeCall(functionName: "\(className).\(functionName)", argumentCount: argumentCount)
        }
        try expect(tokens: [.symbol(.semicolon)])
        writer.writePop(segment: .temp, index: 0)
    }

    func compileReturn() throws {
        try expect(tokens: [.keyword(.´return´)])
        if check(nextToken, in: [.integerConstantType, .stringConstantType, .identifierType, .symbol(.openingParanthesis)] + keywordConstants + unaryOperationTokens) {
            try compileExpression()
        } else {
            writer.writePush(segment: .constant, index: 0)
        }
        try expect(tokens: [.symbol(.semicolon)])
        writer.writeReturn()
    }
    
    func compileExpression() throws {
        try compileTerm()
        if check(nextToken, in: operationTokens) {
            try expect(tokens: operationTokens)
            let operation = lastToken!
            
            try compileTerm()
            
            switch operation {
            case .symbol(.plus):
                writer.writeArithmetic(.add)
            case .symbol(.minus):
                writer.writeArithmetic(.sub)
            case .symbol(.asterisk):
                writer.writeCall(functionName: "Math.multiply", argumentCount: 2)
            case .symbol(.slash):
                writer.writeCall(functionName: "Math.divide", argumentCount: 2)
            case .symbol(.ampersand):
                writer.writeArithmetic(.and)
            case .symbol(.pipe):
                writer.writeArithmetic(.or)
            case .symbol(.lessThan):
                writer.writeArithmetic(.lt)
            case .symbol(.greaterThan):
                writer.writeArithmetic(.gt)
            case .symbol(.equal):
                writer.writeArithmetic(.eq)
            default:
                break
            }
        }
    }
    
    func compileTerm() throws {
        try expect(tokens: [.integerConstantType, .stringConstantType, .identifierType, .symbol(.openingParanthesis)] + keywordConstants + unaryOperationTokens)
        switch lastToken! {
        case let .integerConstant(value):
            writer.writePush(segment: .constant, index: value)
        case let .stringConstant(string):
            writer.writePush(segment: .constant, index: string.count)
            writer.writeCall(functionName: "String.new", argumentCount: 1)
            for character in string {
                writer.writePush(segment: .constant, index: Int(character.asciiValue!))
                writer.writeCall(functionName: "String.appendChar", argumentCount: 2)
            }
        case _ where keywordConstants.contains(lastToken!):
            switch lastToken! {
            case .keyword(.´true´):
                writer.writePush(segment: .constant, index: 1)
                writer.writeArithmetic(.neg)
            case .keyword(.´false´), .keyword(.null):
                writer.writePush(segment: .constant, index: 0)
            case .keyword(.this):
                writer.writePush(segment: .pointer, index: 0)
            default:
                break
            }
        case let .identifier(identifier):
            let data = symbolTable.data(for: identifier)
            switch nextToken! {
            case .symbol(.openingBracket):
                guard let type = data?.type, case .object(let className) = type, className == "Array" else {
                    throw error(message: "Indexing a non-array type")
                }
                writer.writePush(segment: data!.kind.memorySegment, index: data!.index)
                try expect(tokens: [.symbol(.openingBracket)])
                try compileExpression()
                try expect(tokens: [.symbol(.closingBracket)])
                writer.writeArithmetic(.add)
                writer.writePop(segment: .pointer, index: 1)
                writer.writePush(segment: .that, index: 0)
            case .symbol(.openingParanthesis):
                var argumentCount = 1
                writer.writePush(segment: .pointer, index: 0)
                try expect(tokens: [.symbol(.openingParanthesis)])
                try compileExpressionList(&argumentCount)
                try expect(tokens: [.symbol(.closingParanthesis)])
                writer.writeCall(functionName: "\(className!).\(identifier)", argumentCount: argumentCount)
            case .symbol(.dot):
                var argumentCount = 0
                let className: String
                if data != nil, case .object(let name) = data!.type {
                    writer.writePush(segment: data!.kind.memorySegment, index: data!.index)
                    argumentCount = 1
                    className = name
                } else {
                    guard identifier.first!.isUppercase else {
                        throw error(message: "Class names should start with uppercase.")
                    }
                    className = identifier
                }
                try expect(tokens: [.symbol(.dot)])
                try expect(tokens: [.identifierType])
                let functionName = lastToken!.text
                try expect(tokens: [.symbol(.openingParanthesis)])
                try compileExpressionList(&argumentCount)
                try expect(tokens: [.symbol(.closingParanthesis)])
                writer.writeCall(functionName: "\(className).\(functionName)", argumentCount: argumentCount)
            default:
                writer.writePush(segment: data!.kind.memorySegment, index: data!.index)
            }
        case _ where unaryOperationTokens.contains(lastToken!):
            let unaryOperation = lastToken!
            try compileTerm()
            switch unaryOperation {
            case .symbol(.minus):
                writer.writeArithmetic(.neg)
            case .symbol(.tilde):
                writer.writeArithmetic(.not)
            default:
                break
            }
        case .symbol(.openingParanthesis):
            try compileExpression()
            try expect(tokens: [.symbol(.closingParanthesis)])
        default:
            break
        }
    }
    
    func compileExpressionList(_ argumentCount: inout Int) throws {
        if check(nextToken, in: [.integerConstantType, .stringConstantType, .identifierType, .symbol(.openingParanthesis)] + keywordConstants + unaryOperationTokens) {
            try compileExpression()
            argumentCount += 1
            while nextToken == .symbol(.comma) {
                try expect(tokens: [.symbol(.comma)])
                try compileExpression()
                argumentCount += 1
            }
        }
    }
    
    // MARK: Helper Methods
    
    func expect(tokens: [Token]) throws {
        guard let receivedToken = nextToken else {
            throw error(message: "Expected \(tokens), received none.")
        }
        guard check(receivedToken, in: tokens) else {
            throw error(message: "Expected \(tokens), received \(receivedToken)")
        }
        didConsumeLastToken = true
    }
    
    func check(_ token: Token?, in tokens: [Token]) -> Bool {
        guard let receivedToken = token else { return false }
        var isIn = false
        switch receivedToken {
        case .keyword, .symbol:
            for option in tokens {
                if receivedToken == option {
                    isIn = true
                    break
                }
            }
        case .identifier:
            for option in tokens {
                if case .identifier = option {
                    isIn = true
                    break
                }
            }
        case .integerConstant:
            for option in tokens {
                if case .integerConstant = option {
                    isIn = true
                    break
                }
            }
        case .stringConstant:
            for option in tokens {
                if case .stringConstant = option {
                    isIn = true
                    break
                }
            }
        }
        return isIn
    }
    
    func getLabelName() -> String {
        let name = "\(className!)LBL\(labelIndex)"
        labelIndex += 1
        return name
    }
    
    func error(message: String) -> CompilationError {
        closeFile()
        return CompilationError(localizedDescription: message)
    }
    
    func closeFile() {
        writer.closeFile()
    }
    
}

extension SymbolTable.Data.Kind {
    
    var memorySegment: VMWriter.MemorySegment {
        switch self {
        case .´static´:
            return .´static´
        case .field:
            return .this
        case .argument:
            return .argument
        case .´var´:
            return .local
        }
    }
    
}
