//
//  SymbolTable.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

class SymbolTable {
    struct Data {
        enum Kind: String {
            case ´static´ = "static", field, argument, ´var´ = "var"
        }
        
        enum DataType {
            case int, char, boolean, object(String)
            
            init(rawValue: String) {
                switch rawValue {
                case "int":
                    self = .int
                case "char":
                    self = .char
                case "boolean":
                    self = .boolean
                default:
                    self = .object(rawValue)
                }
            }
        }
        
        var type: DataType
        var kind: Kind
        var index: Int
    }
    
    var classLevel: [String : Data] = [:]
    var subroutineLevel: [String : Data] = [:]
    
    var staticIndex: Int = 0
    var fieldIndex: Int = 0
    var argumentIndex: Int = 0
    var varIndex: Int = 0
    
    func index(for kind: Data.Kind) -> Int {
        switch kind {
        case .´static´:
            return staticIndex
        case .field:
            return fieldIndex
        case .argument:
            return argumentIndex
        case .´var´:
            return varIndex
        }
    }
    
    func incrementIndex(for kind: Data.Kind) {
        switch kind {
        case .´static´:
            staticIndex += 1
        case .field:
            fieldIndex += 1
        case .argument:
            argumentIndex += 1
        case .´var´:
            varIndex += 1
        }
    }
    
    func define(name: String, type: Data.DataType, kind: Data.Kind) {
        let index = self.index(for: kind)
        switch kind {
        case .´static´, .field:
            classLevel[name] = Data(type: type, kind: kind, index: index)
        case .argument, .´var´:
            subroutineLevel[name] = Data(type: type, kind: kind, index: index)
        }
        incrementIndex(for: kind)
    }
    
    func data(for identifier: String) -> Data? {
        return subroutineLevel[identifier] ?? classLevel[identifier]
    }
    
    func resetSubroutine() {
        subroutineLevel.removeAll()
        argumentIndex = 0
        varIndex = 0
    }
}
