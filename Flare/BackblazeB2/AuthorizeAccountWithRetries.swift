//
//  AuthorizeAccountWithRetries.swift
//  Flare
//
//  Created by Chris on 25/4/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

// This calls AuthorizeAccount and retries if the internet is disconnected.
// This helps because launchd launches us immediately on wake, but the internet needs to connect.
enum AuthorizeAccountWithRetries {
    static func send(accountId: String, applicationKey: String) throws -> AuthorizeAccountResponse {
        
        for i in 0..<4 {
            if i>0 {
                Thread.sleep(forTimeInterval: 5)
                print("Authorise retry \(i)")
            }
            
            do {
                return try AuthorizeAccount.send(accountId: accountId,
                                                 applicationKey: applicationKey)
            } catch (let error) {
                let nsError = error as NSError
                let isRetriable = nsError.domain == NSURLErrorDomain &&
                    nsError.code == NSURLErrorNotConnectedToInternet
                if !isRetriable {
                    throw error
                }
            }
        }
        
        throw Errors.couldNotAuthoriseTooManyRetries
    }
    
    enum Errors: Error {
        case couldNotAuthoriseTooManyRetries
    }
}
