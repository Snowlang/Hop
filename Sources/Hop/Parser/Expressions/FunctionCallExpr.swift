//
//  FunctionCallExpr.swift
//  TestLexer
//
//  Created by poisson florent on 05/06/2018.
//  Copyright © 2018 poisson florent. All rights reserved.
//

import Foundation

struct FunctionCallExpr : Evaluable {
    var debugInfo: DebugInfo?

    let name: String
    let hashId: Int     // Used for class constructor search
    let arguments: [FunctionCallArgument]?
    let argumentNames: [String]?    // Used for instance method hashId computation
    let signatureHashId: Int        // Used directly for function or static method access

    init(name: String,
         arguments: [FunctionCallArgument]?) {
        self.name = name
        self.hashId = name.hashValue
        self.arguments = arguments
        self.argumentNames = arguments?.map { (argument) -> String in
            return argument.name ?? ""
        }
        self.signatureHashId = Closure.getFunctionSignatureHashId(name: name,
                                                                  argumentNames: argumentNames)
    }

    var description: String {
        var description = "\(name)("

        if let arguments = arguments {
            for (index, arg) in arguments.enumerated() {
                description += arg.description + (index < arguments.count - 1 ? "," : "")
            }
        }

        description += ")"
        return description
    }

    func evaluateMethod(ofClass class: Class,
                        context: Scope,
                        session: Session) throws -> Evaluable? {

        // First: search for method
        if let closure = `class`.getClassMember(for: signatureHashId) as? Closure {
            return try closure.evaluate(arguments: arguments,
                                        context: context,
                                        session: session)
        }

        // Then: search for class initializer
        if let innerClass = `class`.getClassMember(for: hashId) as? Class {
            // Instance variable creation
            // --------------------------

            return try createInstance(of: innerClass,
                                      context: context,
                                      session: session)
        }
        throw ProgramError(errorType: InterpreterError.classMemberNotDeclared, debugInfo: debugInfo)
    }

    func evaluateMethod(ofInstance instance: Instance,
                        inspectedClass: Class,
                        context: Scope,
                        session: Session) throws -> Evaluable? {

        // Add self parameter
        var arguments = [FunctionCallArgument]()
        arguments.append(FunctionCallArgument(name: SelfParameter.name,
                                              expr: Variable(type: instance.class.type,
                                                             isConstant: true,
                                                             value: instance)))
        if self.arguments != nil {
            arguments.append(contentsOf: self.arguments!)
        }

        let methodCallExpr = FunctionCallExpr(name: name,
                                              arguments: arguments)

        guard let closure = inspectedClass.getClassMember(for: methodCallExpr.signatureHashId) as? Closure else {
            throw ProgramError(errorType: InterpreterError.functionNotDeclared, debugInfo: debugInfo)
        }

        return try closure.evaluate(arguments: arguments,
                                    context: context,
                                    session: session)
    }

    func evaluateFunction(ofModule module: Module,
                          context: Scope,
                          session: Session) throws -> Evaluable? {
        return try evaluateFunction(context: context,
                                    parent: module.scope,
                                    session: session)
    }

    func evaluate(context: Scope, session: Session) throws -> Evaluable? {
        return try evaluateFunction(context: context,
                                    parent: context,
                                    session: session)
    }

    private func evaluateFunction(context: Scope,
                                  parent: Scope!,
                                  session: Session) throws -> Evaluable? {

        if let closure = (parent ?? context).getSymbolValue(for: signatureHashId) as? Closure {
            return try closure.evaluate(arguments: arguments,
                                        context: context,
                                        session: session)
        }

        // Then: search for class initializer
        if let `class` = (parent ?? context).getSymbolValue(for: hashId) as? Class {
            // Instance variable creation
            // --------------------------

            return try createInstance(of: `class`,
                                      context: context,
                                      session: session)
        }

        throw ProgramError(errorType: InterpreterError.functionNotDeclared, debugInfo: debugInfo)

    }

    private func createInstance(of class: Class,
                                context: Scope,
                                session: Session) throws -> Evaluable? {
        // Instance scope filled with instance property variables
        let instanceScope = Scope(parent: `class`.scope)

        // Get all instance property declarations across the class hierarchy,
        // and evaluate these declarations in the instance scope
        var instancePropertyDeclarations = [VariableDeclarationStmt]()
        `class`.getHierarchyInstanceProperties(&instancePropertyDeclarations)

        if instancePropertyDeclarations.count > 0 {
            for instancePropertyDeclaration in instancePropertyDeclarations {
                _ = try instancePropertyDeclaration.evaluate(context: instanceScope,
                                                             session: session)
            }
        }

        // Instantiate class
        let instance = Instance(class: `class`,
                                scope: instanceScope)
        let instanceVariable = Variable(type: `class`.type,
                                        isConstant: true,
                                        value: instance)

        // Create & evaluate class instance initializer
        let initializerCall = FunctionCallExpr(name: ClassInitializer.name,
                                               arguments: arguments)
        do {
        _ = try initializerCall.evaluateMethod(ofInstance: instance,
                                               inspectedClass: instance.class,
                                               context: context,
                                               session: session)
        } catch  (let error as ProgramError){
            if let errorType = error.errorType as? InterpreterError {
                if errorType != InterpreterError.functionNotDeclared && arguments != nil {
                    throw error
                }
            }
        }

        // Return new initialized instance
        return instanceVariable
    }

}
