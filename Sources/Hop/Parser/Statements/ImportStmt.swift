//
//  ImportStmt.swift
//  TestLexer
//
//  Created by poisson florent on 17/06/2018.
//  Copyright © 2018 poisson florent. All rights reserved.
//

import Foundation

class ImportStmt: Evaluable {

    var name: String
    var hashId: Int
    var debugInfo: DebugInfo?

    init(name: String) {
        self.name = name
        self.hashId = name.hashValue
    }
    
    var description: String {
        return "import \(name)"
    }
        
    func evaluate(context: Scope,
                  session: Session) throws -> Evaluable? {
        // Check if module has already been imported in global context
        let module: Module! = session.globalScope.symbolTable[hashId] as? Module
        
        if module != nil {
            context.symbolTable[hashId] = module
            return nil
        }
        
        // Try to import from native modules
        if let nativeModule = getNativeModule(name: name) {
            session.globalScope.symbolTable[hashId] = nativeModule
            context.symbolTable[hashId] = nativeModule
            return nil
        }
        
        throw ProgramError(errorType: ImporterError.moduleNotFound, debugInfo: debugInfo)

    }
}
