//
//  StringExtension.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

extension String {
    
    func ends(with suffix: String) -> Bool {
        guard count > suffix.count else { return false }
        let index = self.index(endIndex, offsetBy: -suffix.count)
        let end = self[index...]
        return end == suffix
    }
    
    func trimmingFirstCharacter() -> String? {
        guard self.count > 1 else { return nil }
        let index = self.index(after: startIndex)
        return String(self[index...])
    }
    
    mutating func add(line: String) {
        self += "\n" + line
    }
    
    init(_ value: Int, radix: Int, length: Int) {
        let binary = String(value, radix: radix)
        if binary.count <= length {
            let padding = String(repeating: "0", count: length - binary.count)
            self.init(padding + binary)
        } else {
            let index = binary.index(binary.endIndex, offsetBy: -length)
            self.init(binary[index...])
        }
    }
    
}
