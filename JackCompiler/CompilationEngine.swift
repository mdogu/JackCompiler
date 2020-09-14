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
    let writer: XMLWriter
    
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
    
    init(tokenizer: JackTokenizer, writer: XMLWriter) {
        self.tokenizer = tokenizer
        self.writer = writer
    }
    
    func compile() throws {
        try compileClass()
    }
    
    // MARK: Compile Methods
    
    func compileClass() throws {
        try writer.write(element: "class") {
            try expect(tokens: [.keyword(.´class´)])
            try expect(tokens: [.identifierType])
            try expect(tokens: [.symbol(.openingCurlyBrace)])
            while check(nextToken, in: [.keyword(.´static´), .keyword(.field)]) {
                try compileClassVarDec()
            }
            while check(nextToken, in: [.keyword(.constructor), .keyword(.function), .keyword(.method)]) {
                try compileSubroutine()
            }
            try expect(tokens: [.symbol(.closingCurlyBrace)])
        }
    }
    
    func compileClassVarDec() throws {
        try writer.write(element: "classVarDec") {
            try expect(tokens: [.keyword(.´static´), .keyword(.field)])
            try expect(tokens: typeTokens)
            try expect(tokens: [.identifierType])
            while nextToken == .symbol(.comma) {
                try expect(tokens: [.symbol(.comma)])
                try expect(tokens: [.identifierType])
            }
            try expect(tokens: [.symbol(.semicolon)])
        }
    }
    
    func compileSubroutine() throws {
        try writer.write(element: "subroutineDec") {
            try expect(tokens: [.keyword(.constructor), .keyword(.function), .keyword(.method)])
            try expect(tokens: [.keyword(.void)] + typeTokens)
            try expect(tokens: [.identifierType])
            try expect(tokens: [.symbol(.openingParanthesis)])
            try compileParameterList()
            try expect(tokens: [.symbol(.closingParanthesis)])
            try writer.write(element: "subroutineBody") {
                try expect(tokens: [.symbol(.openingCurlyBrace)])
                while nextToken == .keyword(.´var´) {
                    try compileVarDec()
                }
                try compileStatements()
                try expect(tokens: [.symbol(.closingCurlyBrace)])
            }
        }
    }
    
    func compileParameterList() throws {
        try writer.write(element: "parameterList") {
            if check(nextToken, in: typeTokens) {
                try expect(tokens: typeTokens)
                try expect(tokens: [.identifierType])
                while check(nextToken, in: [.symbol(.comma)]) {
                    try expect(tokens: [.symbol(.comma)])
                    try expect(tokens: typeTokens)
                    try expect(tokens: [.identifierType])
                }
            }
        }
    }
    
    func compileVarDec() throws {
        try writer.write(element: "varDec") {
            try expect(tokens: [.keyword(.´var´)])
            try expect(tokens: typeTokens)
            try expect(tokens: [.identifierType])
            while check(nextToken, in: [.symbol(.comma)]) {
                try expect(tokens: [.symbol(.comma)])
                try expect(tokens: [.identifierType])
            }
            try expect(tokens: [.symbol(.semicolon)])
        }
    }
    
    func compileStatements() throws {
        try writer.write(element: "statements") {
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
    }
    
    func compileLet() throws {
        try writer.write(element: "letStatement") {
            try expect(tokens: [.keyword(.´let´)])
            try expect(tokens: [.identifierType])
            if nextToken == .symbol(.openingBracket) {
                try expect(tokens: [.symbol(.openingBracket)])
                try compileExpression()
                try expect(tokens: [.symbol(.closingBracket)])
            }
            try expect(tokens: [.symbol(.equal)])
            try compileExpression()
            try expect(tokens: [.symbol(.semicolon)])
        }
    }
    
    func compileIf() throws {
        try writer.write(element: "ifStatement") {
            try expect(tokens: [.keyword(.´if´)])
            try expect(tokens: [.symbol(.openingParanthesis)])
            try compileExpression()
            try expect(tokens: [.symbol(.closingParanthesis)])
            try expect(tokens: [.symbol(.openingCurlyBrace)])
            try compileStatements()
            try expect(tokens: [.symbol(.closingCurlyBrace)])
            if nextToken == .keyword(.´else´) {
                try expect(tokens: [.keyword(.´else´)])
                try expect(tokens: [.symbol(.openingCurlyBrace)])
                try compileStatements()
                try expect(tokens: [.symbol(.closingCurlyBrace)])
            }
        }
    }
    
    func compileWhile() throws {
        try writer.write(element: "whileStatement") {
            try expect(tokens: [.keyword(.´while´)])
            try expect(tokens: [.symbol(.openingParanthesis)])
            try compileExpression()
            try expect(tokens: [.symbol(.closingParanthesis)])
            try expect(tokens: [.symbol(.openingCurlyBrace)])
            try compileStatements()
            try expect(tokens: [.symbol(.closingCurlyBrace)])
        }
    }
    
    func compileDo() throws {
        try writer.write(element: "doStatement") {
            try expect(tokens: [.keyword(.´do´)])
            try expect(tokens: [.identifierType])
            try expect(tokens: [.symbol(.openingParanthesis), .symbol(.dot)])
            if lastToken == .symbol(.openingParanthesis) {
                try compileExpressionList()
                try expect(tokens: [.symbol(.closingParanthesis)])
            } else if lastToken == .symbol(.dot) {
                try expect(tokens: [.identifierType])
                try expect(tokens: [.symbol(.openingParanthesis)])
                try compileExpressionList()
                try expect(tokens: [.symbol(.closingParanthesis)])
            }
            try expect(tokens: [.symbol(.semicolon)])
        }
    }

    func compileReturn() throws {
        try writer.write(element: "returnStatement") {
            try expect(tokens: [.keyword(.´return´)])
            if check(nextToken, in: [.integerConstantType, .stringConstantType, .identifierType, .symbol(.openingParanthesis)] + keywordConstants + unaryOperationTokens) {
                try compileExpression()
            }
            try expect(tokens: [.symbol(.semicolon)])
        }
    }
    
    func compileExpression() throws {
        try writer.write(element: "expression") {
            try compileTerm()
            if check(nextToken, in: operationTokens) {
                try expect(tokens: operationTokens)
                try compileTerm()
            }
        }
    }
    
    func compileTerm() throws {
        try writer.write(element: "term") {
            try expect(tokens: [.integerConstantType, .stringConstantType, .identifierType, .symbol(.openingParanthesis)] + keywordConstants + unaryOperationTokens)
            if case .identifier = lastToken! {
                if nextToken == .symbol(.openingBracket) {
                    try expect(tokens: [.symbol(.openingBracket)])
                    try compileExpression()
                    try expect(tokens: [.symbol(.closingBracket)])
                } else if nextToken == .symbol(.openingParanthesis) {
                    try expect(tokens: [.symbol(.openingParanthesis)])
                    try compileExpressionList()
                    try expect(tokens: [.symbol(.closingParanthesis)])
                } else if nextToken == .symbol(.dot) {
                    try expect(tokens: [.symbol(.dot)])
                    try expect(tokens: [.identifierType])
                    try expect(tokens: [.symbol(.openingParanthesis)])
                    try compileExpressionList()
                    try expect(tokens: [.symbol(.closingParanthesis)])
                }
            } else if check(lastToken, in: unaryOperationTokens) {
                try compileTerm()
            } else if lastToken == .symbol(.openingParanthesis) {
                try compileExpression()
                try expect(tokens: [.symbol(.closingParanthesis)])
            }
        }
    }
    
    func compileExpressionList() throws {
        try writer.write(element: "expressionList") {
            if check(nextToken, in: [.integerConstantType, .stringConstantType, .identifierType, .symbol(.openingParanthesis)] + keywordConstants + unaryOperationTokens) {
                try compileExpression()
                while nextToken == .symbol(.comma) {
                    try expect(tokens: [.symbol(.comma)])
                    try compileExpression()
                }
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
        writer.write(token: receivedToken)
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
    
    func error(message: String) -> CompilationError {
        closeFile()
        return CompilationError(localizedDescription: message)
    }
    
    func closeFile() {
        writer.closeFile()
    }
    
}
