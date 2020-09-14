//
//  Console.swift
//  JackCompiler
//
//  Created by Murat Dogu on 14.09.2020.
//  Copyright © 2020 Murat Dogu. All rights reserved.
//

import Foundation

class Console {
    
    static func print(_ message: String) {
        Swift.print(message)
    }
    
    static func error(_ message: String) {
        fputs("\u{001B}[0;31m\(message)\u{001B}[;m\n", stderr)
    }
    
}
