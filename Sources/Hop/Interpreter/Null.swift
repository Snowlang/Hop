//
//  Null.swift
//  TestLexer
//
//  Created by poisson florent on 29/06/2018.
//  Copyright © 2018 poisson florent. All rights reserved.
//

import Foundation

class Null: Evaluable {
    var debugInfo: DebugInfo?

    static let shared = Null()
    
    var description: String {
        return "Null"
    }
    
    func evaluate(context: Scope,
                  session: Session) throws -> Evaluable? {
        return self
    }
    
}
