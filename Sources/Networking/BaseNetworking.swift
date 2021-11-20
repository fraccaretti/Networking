//
//  BaseNetworking.swift
//  Core
//
//  Created by Piotr Fraccaro on 19/04/2021.
//
import Foundation

open class BaseNetworking {

    private let client: HttpClientAPI
    
    public init(client: HttpClientAPI) {
        self.client = client
    }
    
    public func perform<T: Codable, U: Codable>(_ request: HttpRequest<T>) -> NetworkingResultPublisher<U> {
        return client.perform(request)
    }
}
