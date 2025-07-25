//
//  ConnectionConfiguration.swift
//  PostgresClientKit
//
//  Copyright 2019 David Pitfield and the PostgresClientKit contributors
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

/// The configuration for a `Connection` to the Postgres server.
public struct ConnectionConfiguration {
    
    /// Creates a `ConnectionConfiguration`.
    public init() { }
    
    /// The hostname or IP address of the Postgres server.  Defaults to `localhost`.
    public var host = "localhost"
    
    /// The port number of the Postgres server.  Defaults to `5432`.
    public var port = 5432
    
    /// The timeout for socket operations, in seconds, or 0 for no timeout.  Defaults to 0.
    public var socketTimeout = 0
    
    /// The name of the database on the Postgres server.  Defaults to `postgres`.
    public var database = "postgres"
    
    /// The Postgres username.  Defaults to an empty string.
    public var user = ""
    
    /// The credential to use to authenticate to the Postgres server.  Defaults to
    /// `Credential.trust`.
    public var credential = Credential.trust
    
    /// The Postgres `application_name` parameter.  Included in the `pg_stat_activity` view and
    /// displayed by pgAdmin.  Defaults to `PostgresClientKit`.
    public var applicationName = "PostgresClientKit"
    
    /// The channel binding policy
    public var channelBindingPolicy: ChannelBindingPolicy = .preferred
}

// EOF
