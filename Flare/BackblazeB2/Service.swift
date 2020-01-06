//
//  Service.swift
//  Flare
//
//  Created by Chris on 4/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

class Service {
    static let shared = Service()
    
    let session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: nil) // Nil queue means it makes its own serial queue, so we don't block the current or main threads.
    
    /// GETs an endpoint. Token is the auth token.
    func get(url: URL, token: String?, queryItems: [URLQueryItem] = [], timeoutInterval: TimeInterval? = nil) throws -> ([AnyHashable: Any], Data) {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw Errors.urlComponents
        }
        components.queryItems = queryItems
        guard let urlWithQuery = components.url else {
            throw Errors.urlComponents
        }
        let request = URLRequest.request(url: urlWithQuery, token: token, timeoutInterval: timeoutInterval)
        return try make(request: request)
    }
    
    /// POST (eg insert) or PUT (eg update) to a backend endpoint.
    /// Token is your auth token, can only be nil for pre-login endpoints.
    func post(url: URL, payload: Any, headers: [String: String] = [:], token: String?, timeoutInterval: TimeInterval? = nil) throws -> ([AnyHashable: Any], Data) {
        return try postOrPut(httpMethod: "POST", url: url, payload: payload, headers: headers, token: token, timeoutInterval: timeoutInterval)
    }
    func put(url: URL, payload: Any, headers: [String: String] = [:], token: String?, timeoutInterval: TimeInterval? = nil) throws -> ([AnyHashable: Any], Data) {
        return try postOrPut(httpMethod: "PUT", url: url, payload: payload, headers: headers, token: token, timeoutInterval: timeoutInterval)
    }
    
    private func postOrPut(httpMethod: String, url: URL, payload: Any, headers: [String: String], token: String?, timeoutInterval: TimeInterval?) throws -> ([AnyHashable: Any], Data) {
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw Errors.couldNotSerialiseJson
        }
        
        var newHeaders = headers
        newHeaders["Content-Type"] = "application/json"
        
        return try postOrPutRaw(httpMethod: httpMethod, url: url, body: body, headers: newHeaders, token: token, timeoutInterval: timeoutInterval)
    }
    
    func postOrPutRaw(httpMethod: String, url: URL, body: Data, headers: [String: String], token: String?, timeoutInterval: TimeInterval? = nil) throws -> ([AnyHashable: Any], Data) {
        var request = URLRequest.request(url: url, token: token, timeoutInterval: timeoutInterval)
        request.httpMethod = httpMethod
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpBody = body
        
        return try make(request: request)
    }
    
    /// Helper for making get/post requests to the backend.
    /// This parses the json response.
    /// This throws Errors.not200 on non-200s.
    func make(request: URLRequest) throws -> ([AnyHashable: Any], Data) {
        let (data, response) = try session.dataTaskSync(request: request)
        #if DEBUG
        if let s = data.asString { print(s) }
        #endif
        guard 200 <= response.statusCode && response.statusCode < 300 else {
            let json = data.asJson
            let code = json?["code"] as? String // eg "bad_request"
            let message = json?["message"] as? String // eg "Invalid bucketId: 967fa9f24082154465d30c12x"
            throw Errors.not200(response.statusCode, code, message)
        }
        guard let json = data.asJson else {
            throw Errors.couldNotParseJson
        }
        return (json, data)
    }
    
    enum Errors: Error {
        case badApiUrl
        case urlComponents
        case couldNotSerialiseJson
        case unauthorized401
        case not200(Int, String?, String?) // HTTP code, code, message
        case missingResponseData
        case couldNotParseJson
        case notLoggedIn
        case invalidResponse
        case timedOut
    }
    
}

private extension URLSession {
    // Because Swift doesn't have anything as nice as 'async await' (NSOperation, GCD, Combine aren't easy to use),
    // I'm running everything synchronously. This gives us the ease of using swift 'throws' for errors.
    // This works just as well as async use if it's off the main thread, IMO.
    // This blocks the current thread, as intended.
    // This is the barest wrapper on URLSession, and as such doesn't unwrap/throw errors.
    func dataTaskSyncOptionals(request: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)
        dataTask(with: request, completionHandler: { newData, newResponse, newError in
            data = newData
            response = newResponse
            error = newError
            semaphore.signal()
        }).resume()
        // Block the current thread until the callback happens on the URLSession thread.
        _ = semaphore.wait(timeout: .distantFuture) // Can safely ignore the return, because it cannot timeout with distantFuture.
        return (data, response, error)
    }
    
    /// This wraps dataTaskSyncBasic, throwing on errors, unwrapping the optionals.
    /// 4/500 responses are considered success (well, they are a 'successful' conversation with the server).
    func dataTaskSync(request: URLRequest) throws -> (Data, HTTPURLResponse) {
        enum Errors: Error {
            case nilData
            case nilResponse
        }
        let (data, response, error) = dataTaskSyncOptionals(request: request)
        if let error = error { throw error }
        guard let data2 = data else { throw Errors.nilData }
        guard let response2 = response as? HTTPURLResponse else { throw Errors.nilResponse }
        return (data2, response2)
    }
    
}

private extension Data {
    var asJson: [AnyHashable: Any]? {
        let json = try? JSONSerialization.jsonObject(with: self, options: [])
        return json as? [AnyHashable: Any]
    }
}

private extension URLRequest {
    static func request(url: URL, token: String?, timeoutInterval: TimeInterval?) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        if let timeoutInterval = timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        return request
    }
}
