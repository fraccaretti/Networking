//
//  HttpClient.swift
//  Core
//
//  Created by Piotr Fraccaro on 19/04/2021.
//

import Foundation
import Combine

public struct EmptyResponse: Codable { }

public typealias NetworkingResultPublisher<U: Codable> = AnyPublisher<U, Error>
public typealias NetworkingEmptyResultPublisher = NetworkingResultPublisher<EmptyResponse>

public protocol HttpClientApi: AnyObject {
    
    func perform<T: Codable, U: Codable>(_ request: HttpRequest<T>) -> NetworkingResultPublisher<U>
}

public final class HttpClient: NSObject, HttpClientApi {
    
    private let session: URLSession
    
    public init(sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
                sessionDelegate: URLSessionDelegate) {
        self.session = URLSession(configuration: sessionConfiguration,
                                  delegate: sessionDelegate,
                                  delegateQueue: OperationQueue())
        super.init()
    }
    
    public func perform<T: Codable, U: Codable>(_ request: HttpRequest<T>) -> NetworkingResultPublisher<U> {
        NSLog("[🌐] [↑] \(request.string)")
        
        guard var components = URLComponents(url: request.url, resolvingAgainstBaseURL: true) else {
            return Fail(error: NetworkingError.invalidURL).eraseToAnyPublisher()
        }
        
        if request.method == .get {
            components.queryItems = components.queryItems != nil ? components.queryItems : [URLQueryItem]()
            components.queryItems?.append(contentsOf: request.parameters.asQueryItems())
        }
        
        guard let url = components.url else {
            return Fail(error: NetworkingError.invalidURLParameters).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.headers
        
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        if request.body != nil {
            guard
                let data = try? JSONEncoder().encode(request.body)
            else {
                return Fail(error: NetworkingError.invalidJSONParameters).eraseToAnyPublisher()
            }
            urlRequest.httpBody = data
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .networkingResultPublisher(for: request)
    }
}

private extension URLSession.DataTaskPublisher {
    
    func networkingResultPublisher<T: Codable, U: Codable>(for request: HttpRequest<T>) -> NetworkingResultPublisher<U> {
        tryMap { data, response -> Data in
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkingError.notHttpResponse
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                throw NetworkingError.apiError(code: httpResponse.statusCode, data: data)
            }

            NSLog("""
                [🌐] [↑] [🟢] Request: \(request.string)
                Response: \(String(data: data, encoding: .utf8) ?? "")
                """)
            
            return data
        }
        .compactMap { data -> U? in
            if U.self == EmptyResponse.self,
               let empty = EmptyResponse() as? U {
                return empty
            }
            
            let decoder = JSONDecoder()
            let decoded = try? decoder.decode(U.self, from: data)
            return decoded
        }
        .mapError { error -> Error in
            NSLog(
                """
                [🌐] [↓] [🔴] Request: \(request.string)
                Error: \(error.localizedDescription)
                """)
            return error
        }
        .eraseToAnyPublisher()
    }
}
