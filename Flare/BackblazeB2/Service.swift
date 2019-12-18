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
    
    let session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: .main)
    
    /// GETs an endpoint. Completion is main thread. Token is the auth token.
    func get(url: URL, token: String?, queryItems: [URLQueryItem] = [], timeoutInterval: TimeInterval? = nil, completion: @escaping (Result<([AnyHashable: Any], Data), Error>) -> ()) {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            completion(.failure(Errors.urlComponents))
            return
        }
        components.queryItems = queryItems
        guard let urlWithQuery = components.url else {
            completion(.failure(Errors.urlComponents))
            return
        }
        let request = URLRequest.request(url: urlWithQuery, token: token, timeoutInterval: timeoutInterval)
        make(request: request, completion: completion)
    }
    
    /// POST (eg insert) or PUT (eg update) to a backend endpoint. Completion is on the main thread.
    /// Token is your auth token, can only be nil for pre-login endpoints.
    func post(url: URL, payload: Any, headers: [String: String] = [:], token: String?, timeoutInterval: TimeInterval? = nil, completion: @escaping (Result<([AnyHashable: Any], Data), Error>) -> ()) {
        postOrPut(httpMethod: "POST", url: url, payload: payload, headers: headers, token: token, timeoutInterval: timeoutInterval, completion: completion)
    }
    func put(url: URL, payload: Any, headers: [String: String] = [:], token: String?, timeoutInterval: TimeInterval? = nil, completion: @escaping (Result<([AnyHashable: Any], Data), Error>) -> ()) {
        postOrPut(httpMethod: "PUT", url: url, payload: payload, headers: headers, token: token, timeoutInterval: timeoutInterval, completion: completion)
    }
    
    private func postOrPut(httpMethod: String, url: URL, payload: Any, headers: [String: String], token: String?, timeoutInterval: TimeInterval?, completion: @escaping (Result<([AnyHashable: Any], Data), Error>) -> ()) {
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(Errors.couldNotSerialiseJson))
            return
        }
        
        var newHeaders = headers
        newHeaders["Content-Type"] = "application/json"
        
        postOrPutRaw(httpMethod: httpMethod, url: url, body: body, headers: newHeaders, token: token, timeoutInterval: timeoutInterval, completion: completion)
    }
    
    func postOrPutRaw(httpMethod: String, url: URL, body: Data, headers: [String: String], token: String?, timeoutInterval: TimeInterval? = nil, completion: @escaping (Result<([AnyHashable: Any], Data), Error>) -> ()) {
        var request = URLRequest.request(url: url, token: token, timeoutInterval: timeoutInterval)
        request.httpMethod = httpMethod
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpBody = body
        
        make(request: request, completion: completion)
    }
    
    /// Helper for making get/post requests to the backend.
    func make(request: URLRequest, completion: @escaping (Result<([AnyHashable: Any], Data), Error>) -> ()) {
        session.dataTask(with: request, completionHandler: { data, response, error in
            #if DEBUG
            if let s = data?.asString {
                print(s)
            }
            #endif
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(Errors.notHTTPURLResponse))
                return
            }
            guard 200 <= response.statusCode && response.statusCode < 300 else {
                let json = data?.asJson
                let code = json?["code"] as? String // eg "bad_request"
                let message = json?["message"] as? String // eg "Invalid bucketId: 967fa9f24082154465d30c12x"
                completion(.failure(Errors.not200(response.statusCode, code, message)))
                return
            }
            guard let data = data else {
                completion(.failure(Errors.missingResponseData))
                return
            }
            guard let json = data.asJson else {
                completion(.failure(Errors.couldNotParseJson))
                return
            }
            
            completion(.success((json, data)))
        }).resume()
    }
    
    // TODO use this everywhere instead of async, for ease of integration with 'throws' and no more complicated NSOperations.
    // TODO need to change the response queue from .main
    // Blocks the current thread.
    func makeSync(request: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)
        session.dataTask(with: request, completionHandler: { newData, newResponse, newError in
            data = newData
            response = newResponse
            error = newError
            semaphore.signal()
        }).resume()
        _ = semaphore.wait(timeout: .distantFuture)
        return (data, response, error)
    }
    
    // TODO rename this neatly?
    func makeSyncExtended(request: URLRequest) throws -> [AnyHashable: Any] {
        let (dataO, responseO, error) = makeSync(request: request)
        if let error = error {
            throw error
        }
        guard let response = responseO as? HTTPURLResponse else {
            throw Errors.notHTTPURLResponse
        }
        guard 200 <= response.statusCode && response.statusCode < 300 else {
            let json = dataO?.asJson
            let code = json?["code"] as? String // eg "bad_request"
            let message = json?["message"] as? String // eg "Invalid bucketId: 967fa9f24082154465d30c12x"
            throw Errors.not200(response.statusCode, code, message)
        }
        guard let data = dataO else {
            throw Errors.missingResponseData
        }
        guard let json = data.asJson else {
            throw Errors.couldNotParseJson
        }
        return json
    }
    
    enum Errors: Error {
        case badApiUrl
        case urlComponents
        case couldNotSerialiseJson
        case notHTTPURLResponse
        case unauthorized401
        case not200(Int, String?, String?) // HTTP code, code, message
        case missingResponseData
        case couldNotParseJson
        case notLoggedIn
        case invalidResponse
        case timedOut
    }
    
//    /// Helper that generates an endpoint url
//    static func endpoint(component: String, version: Int = 1) -> URL {
//        let path = "api/v\(version)/\(component)"
//        return ConfigManager.shared.config.api.appendingPathComponent(path)
//    }
    
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
