//
//  JackTokenizer.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

class JackTokenizer {
    
    let inputFile: FileHandle
    
    var tokens = [Token]()
    var currentToken: Token?
    var isInComment = false
    
    init(inputFileURL: URL) throws {
        self.inputFile = try FileHandle(forReadingFrom: inputFileURL)
    }
    
    func nextToken() -> Token? {
        if tokens.count > 0 {
            return tokens.remove(at: 0)
        } else {
            if let line = inputFile.readLine() {
                var commentLess = line
                if isInComment {
                    if let range = commentLess.range(of: "*/") {
                        commentLess.removeSubrange(..<range.upperBound)
                        isInComment = false
                    } else {
                        return nextToken()
                    }
                }
                if let range = commentLess.range(of: "//") {
                    commentLess.removeSubrange(range.lowerBound...)
                }
                if let openingRange = commentLess.range(of: "/*") {
                    if let closingRange = commentLess.range(of: "*/") {
                        commentLess.removeSubrange(openingRange.lowerBound ..< closingRange.upperBound)
                    } else {
                        commentLess.removeSubrange(openingRange.lowerBound...)
                        isInComment = true
                    }
                }
                if let openingRange = commentLess.range(of: "/**") {
                    if let closingRange = commentLess.range(of: "*/") {
                        commentLess.removeSubrange(openingRange.lowerBound ..< closingRange.upperBound)
                    } else {
                        commentLess.removeSubrange(openingRange.lowerBound...)
                        isInComment = true
                    }
                }
                var trimmed = commentLess.trimmingCharacters(in: .whitespaces)
                guard trimmed.count > 0 else { return nextToken() }
                
                do {
                    while let token = try trimmed.consumeToken() {
                        tokens.append(token)
                    }
                } catch {
                    Console.error(error.localizedDescription)
                    exit(0)
                }
                
                if tokens.count > 0 {
                    return tokens.remove(at: 0)
                } else {
                    return nextToken()
                }
            } else {
                closeFile()
                return nil
            }
        }
    }
    
    func closeFile() {
        inputFile.closeFile()
    }
    
}

enum Token {
    enum Keyword: String {
        case ´class´ = "class", method, function, constructor, int, boolean, char, void, ´var´ = "var", ´static´ = "static", field, ´let´ = "let", ´do´ = "do", ´if´ = "if", ´else´ = "else", ´while´ = "while", ´return´ = "return", ´true´ = "true", ´false´ = "false", null, this
    }
    
    enum Symbol: String {
        case openingCurlyBrace = "{", closingCurlyBrace = "}", openingParanthesis = "(", closingParanthesis = ")", openingBracket = "[", closingBracket = "]", dot = ".", comma = ",", semicolon = ";", plus = "+", minus = "-", asterisk = "*", slash = "/", ampersand = "&", pipe = "|", lessThan = "<", greaterThan = ">", equal = "=", tilde = "~"
    }
    
    case keyword(Keyword)
    case symbol(Symbol)
    case identifier(String)
    case integerConstant(Int)
    case stringConstant(String)
    
    static var identifierType: Token { return Token.identifier("") }
    static var integerConstantType: Token { return Token.integerConstant(0) }
    static var stringConstantType: Token { return Token.stringConstant("") }
    
    var text: String {
        switch self {
        case let .keyword(keyword):
            return keyword.rawValue
        case let .symbol(symbol):
            return symbol.rawValue
        case let .identifier(identifier):
            return identifier
        case let .integerConstant(integer):
            return "\(integer)"
        case let .stringConstant(string):
            return string
        }
    }
}

extension Token: Equatable {
    public static func ==(lhs: Token, rhs: Token) -> Bool {
        switch (lhs, rhs) {
        case let (.keyword(leftKeyword), .keyword(rightKeyword)):
            return leftKeyword == rightKeyword
        case let (.symbol(leftSymbol), .symbol(rightSymbol)):
            return leftSymbol == rightSymbol
        case let (.identifier(leftIdentifier), .identifier(rightIdentifier)):
            return leftIdentifier == rightIdentifier
        case let (.integerConstant(leftInt), .integerConstant(rightInt)):
            return leftInt == rightInt
        case let (.stringConstant(leftString), .stringConstant(rightString)):
            return leftString == rightString
        default:
            return false
        }
    }
}

extension String {
    
    mutating func consumeToken() throws -> Token? {
        self = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard count > 0 else { return nil }
        return try consumeSymbol() ??
            consumeStringConstant() ??
            consumeIntegerConstant() ??
            consumeKeyword() ??
            consumeIdentifier()
    }
    
    
    
    mutating func consumeSymbol() throws -> Token? {
        let regex = try NSRegularExpression(pattern: "^\\{|\\}|\\(|\\)|\\[|]|\\.|,|;|\\+|-|\\*|\\/|&|\\||<|>|=|~")
        let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: 1))
        if let nsRange = match?.range, let range = Range(nsRange, in: self) {
            if let token = Token.Symbol(rawValue: String(self[range])) {
                removeSubrange(range)
                return .symbol(token)
            }
        }
        return nil
    }
    
    mutating func consumeStringConstant() throws -> Token? {
        let regex = try NSRegularExpression(pattern: "^\"([^\"]*)\"")
        let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: count))
        if let nsRange = match?.range(at: 1),
            let range = Range(nsRange, in: self),
            let nsWholeRange = match?.range,
            let wholeRange = Range(nsWholeRange, in: self) {
            let constant = String(self[range])
            removeSubrange(wholeRange)
            return .stringConstant(constant)
        }
        return nil
    }
    
    mutating func consumeIntegerConstant() throws -> Token? {
        let regex = try NSRegularExpression(pattern: "^\\d+")
        let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: count))
        if let nsRange = match?.range, let range = Range(nsRange, in: self) {
            guard let constant = Int(self[range]) else {
                removeSubrange(range)
                return nil
            }
            removeSubrange(range)
            return .integerConstant(constant)
        }
        return nil
    }
    
    mutating func consumeKeyword() throws -> Token? {
        let regex = try NSRegularExpression(pattern: "^(class|method|function|constructor|int|boolean|char|void|var|static|field|let|do|if|else|while|return|true|false|null|this)\\b")
        let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: count))
        if let nsRange = match?.range(at: 1), let range = Range(nsRange, in: self) {
            if let token = Token.Keyword(rawValue: String(self[range])) {
                removeSubrange(range)
                return .keyword(token)
            }
        }
        return nil
    }
    
    mutating func consumeIdentifier() throws -> Token? {
        let regex = try NSRegularExpression(pattern: "^[a-zA-Z_][a-zA-Z_0-9]*")
        let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: count))
        if let nsRange = match?.range, let range = Range(nsRange, in: self) {
            let identifier = String(self[range])
            removeSubrange(range)
            return .identifier(identifier)
        }
        return nil
    }

}
