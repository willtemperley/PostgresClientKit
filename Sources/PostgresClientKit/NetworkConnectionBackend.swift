// NetworkConnectionBackend.swift
// PostgresClientKit
//
//  Copyright 2025 Will Temperley and the PostgresClientKit contributors
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Network
import Foundation
import CryptoKit

typealias ChannelBindingDataProvider = (Data) -> Void

final class NetworkConnectionBackend {
    private let connection: NWConnection
    private var remoteClosed = false
    private let remoteClosedLock = DispatchQueue(label: "remoteClosedLock")
    
    private var isReady = false
    
    private var onReadyCallbacks: [() -> Void] = []
    private var onCancelCallbacks: [() -> Void] = []
    
    private var cancelling = false

    private var channelBindingDataProvider: ChannelBindingDataProvider?
    
    init(host: String, port: UInt16, channelBindingProvider: ChannelBindingDataProvider? = nil) {
        
        let tlsOptions = NWProtocolTLS.Options()
        
        let secProtocolOptions = tlsOptions.securityProtocolOptions
        
        // This is required else Postgres will close the connection and log the error:
        // "received direct SSL connection request without ALPN protocol negotiation extension"
        "postgresql".withCString { cString in
            sec_protocol_options_add_tls_application_protocol(secProtocolOptions, cString)
        }
        
        func hashSHA256(certificate: SecCertificate) -> Data? {
            let certData = SecCertificateCopyData(certificate) as Data
            let digest = SHA256.hash(data: certData)
            return Data(digest)
        }

        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { metadata, trustRef, verifyComplete in
            let trust = sec_trust_copy_ref(trustRef).takeRetainedValue()

            if host == "localhost" || host == "127.0.0.1" || host == "::1" {
                // Still accept self-signed for localhost
                if let cert = SecTrustGetCertificateAtIndex(trust, 0) {
                    let certificateHash = hashSHA256(certificate: cert)
                    if let channelBindingProvider, let certificateHash {
                        channelBindingProvider(certificateHash)
                    }
                }
                verifyComplete(true)
            } else {
                SecTrustEvaluateAsyncWithError(trust, DispatchQueue.global()) { _, result, _ in
                    if result {
                        if let cert = SecTrustGetCertificateAtIndex(trust, 0) {
                            let channelBindingData = hashSHA256(certificate: cert)
                            if let channelBindingProvider, let channelBindingData {
                                channelBindingProvider(channelBindingData)
                            }
                            print(channelBindingData?.hexEncodedString() ?? "No channel binding data")
                        }
                    }
                    verifyComplete(result)
                }
            }
        }, DispatchQueue.global())
        
        let parameters = NWParameters(tls: tlsOptions)
        self.connection = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: parameters)
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            
            switch state {
            case .ready:
                cancelling = false
                self.isReady = true
                let callbacks = self.onReadyCallbacks
                self.onReadyCallbacks = [] // Clear queue
                for callback in callbacks {
                    callback()
                }
            case .cancelled:
                let callbacks = self.onCancelCallbacks
                self.onCancelCallbacks = [] // Clear queue
                for callback in callbacks {
                    callback()
                }

            default:
                self.isReady = false
            }
        }
        print("init complete")
    }
    
    var remoteConnectionClosed: Bool {
        remoteClosedLock.sync { remoteClosed }
    }
    
    func start(callback: @escaping () -> Void) {
        onReadyCallbacks.append(callback)
        connection.start(queue: .global())
    }
    
    func cancel(force: Bool = false, callback: (() -> Void)? = nil) {
        cancelling = true
        if let callback {
            onCancelCallbacks.append(callback)
        }
        if force {
            connection.forceCancel()
        } else {
            connection.cancel()
        }
    }

    func read(into buffer: inout Data) throws -> Int {
        var receivedData: Data?
        var receiveError: NWError?
        let semaphore = DispatchSemaphore(value: 0)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, isComplete, error in
            if let data = data {
                receivedData = data
            }
            if isComplete {
                self.remoteClosedLock.sync {
                    self.remoteClosed = true
                }
            }
            if let error = error {
                receiveError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = receiveError {
            throw error
        }
        
        if let data = receivedData {
            buffer.append(data)
            return data.count
        } else {
            return 0
        }
    }
    
    func write(from data: Data) throws {
        
        if connection.state == .cancelled {
            throw PostgresError.connectionClosed
        }
        
        var sendError: NWError?
        let semaphore = DispatchSemaphore(value: 0)
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                sendError = error
            }
            semaphore.signal()
        })
        
        semaphore.wait()
        
        if let error = sendError {
            throw error
        }
    }
    
    var isConnected: Bool {
        if cancelling {
            return false
        }
        switch connection.state {
        case .ready:
            return true
        case .cancelled, .failed(_):
            return false
        default:
            return false
        }
    }
    
}
