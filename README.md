# PostgresClientKit

### This project has archived
It has been re-written with a fully asnchronous API:
https://github.com/willtemperley/swift-postgres-client

<p>

  <a href="https://codewinsdotcom.github.io/PostgresClientKit/Docs/API/index.html">
    <img src="https://img.shields.io/badge/api-docs-blue.svg">
  </a>
  
  <img src="https://img.shields.io/badge/swift-5-green.svg">
  <img src="https://img.shields.io/badge/os-macOS-green.svg">
  <img src="https://img.shields.io/badge/os-iOS-green.svg">  
  
  <img src="https://img.shields.io/github/release/codewinsdotcom/PostgresClientKit.svg">
  <img src="https://img.shields.io/github/license/codewinsdotcom/PostgresClientKit.svg">
  
</p>

PostgresClientKit provides a friendly Swift API for operating against a PostgreSQL database.

As of July 2025, the network backend uses Apple’s Network.framework, removing Kitura BlueSocket and BlueSSLService dependencies which are no longer supported. Channel binding support has been enabled, significantly improving security. Non-TLS connection support has been removed.

## Features

- **Doesn't require libpq.**  PostgresClientKit implements the Postgres network protocol in Swift, so it does not require `libpq`.

- **Developer-friendly API using modern Swift.**  For example, errors are represented by instances of `enum PostgresError: Error` and are raised by a `throw` or by returning a [`Result<Success, Error>`](https://github.com/apple/swift-evolution/blob/master/proposals/0235-add-result.md).

- **Safe conversion between Postgres and Swift types.** Type conversion is explicit and robust.  Conversion errors are signaled, not masked.  PostgresClientKit provides additional Swift types for dates and times to address the impedance mismatch between Postgres types and Foundation `Date`.

- **Memory efficient.** The rows in a result are exposed through an iterator, not an array.  Rows are lazily retrieved from the Postgres server.

- **SSL/TLS support.** Encrypts the connection between PostgresClientKit and the Postgres server.

- **Channel binding support.** This is essential security feature for SCRAM-SHA-256 authentication over TLS. It links the TLS session to the authentication exchange, protecting against man-in-the-middle (MitM) attacks.

- **Well-engineered**. Complete API documentation, an extensive test suite, actively supported.

Sounds good?  Let's look at an example.

## Example

This is a basic, but complete, example of how to connect to Postgres, perform a SQL `SELECT` command, and process the resulting rows.  It uses the `weather` table in the [Postgres tutorial](https://www.postgresql.org/docs/11/tutorial-table.html).

```swift
import PostgresClientKit

do {
    var configuration = PostgresClientKit.ConnectionConfiguration()
    configuration.host = "127.0.0.1"
    configuration.database = "example"
    configuration.user = "bob"
    configuration.credential = .scramSHA256(password: "welcome1")
    configuration.channelBindingPolicy = .required // Enforce channel binding. Defaults to preferred.

    let connection = try PostgresClientKit.Connection(configuration: configuration)
    defer { connection.close() }

    let text = "SELECT city, temp_lo, temp_hi, prcp, date FROM weather WHERE city = $1;"
    let statement = try connection.prepareStatement(text: text)
    defer { statement.close() }

    let cursor = try statement.execute(parameterValues: [ "San Francisco" ])
    defer { cursor.close() }

    for row in cursor {
        let columns = try row.get().columns
        let city = try columns[0].string()
        let tempLo = try columns[1].int()
        let tempHi = try columns[2].int()
        let prcp = try columns[3].optionalDouble()
        let date = try columns[4].date()
    
        print("""
            \(city) on \(date): low: \(tempLo), high: \(tempHi), \
            precipitation: \(String(describing: prcp))
            """)
    }
} catch {
    print(error) // better error handling goes here
}
```

Output:

```
San Francisco on 1994-11-27: low: 46, high: 50, precipitation: Optional(0.25)
San Francisco on 1994-11-29: low: 43, high: 57, precipitation: Optional(0.0)
```

## Channel binding

Channel binding is only relevant when using SCRAM-SHA-256 SASL authentication.

The channel binding policy can be configured as either:

* `preferred` - If the server supports SCRAM-SHA-256-PLUS, the client will use channel binding. Otherwise, a warning is logged and the connection falls back to plain SCRAM-SHA-256.
* `required` - If the server does not support SCRAM-SHA-256-PLUS, an error is thrown and the connection fails.
⚠️ When using `.preferred` mode, if the connection proceeds with plain SCRAM-SHA-256 (without -PLUS), it's important to verify that the server genuinely does not support SCRAM-SHA-256-PLUS. Otherwise, a protocol downgrade attack may be possible, where an attacker strips the -PLUS mechanism to force weaker authentication.

## Prerequisites

- **Swift 5 or later**  (PostgresClientKit uses Swift 5 language features)

This fork of PostgresClientKit is compatible with macOS and iOS.
It has only been tested on Postgres 17.

## Building

```
cd <path-to-clone>
swift package clean
swift build
```

## Testing

[Set up a Postgres database for testing](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/Docs/setting_up_a_postgres_database_for_testing.md).  This is a one-time process.

Then:

```
cd <path-to-clone>
swift package clean
swift build
swift test
```

## Using

### From an Xcode project (as a package dependency)

In Xcode:

- Select File > Add Packages...

- Enter the package URL: `https://github.com/codewinsdotcom/PostgresClientKit`

- Set the package version requirements (see [Decide on Package Requirements](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)).  For example, choose `Up To Next Major Version` and `1.0.0` to select the latest 1.x.x release of PostgresClientKit.

- Click Add Package.

Import to your source code file:

```swift
import PostgresClientKit
```

### From a standalone Swift package (`Package.swift`)

In your `Package.swift` file:

- Add PostgresClientKit to the `dependencies`.  For example:

```swift
dependencies: [
    .package(url: "https://github.com/codewinsdotcom/PostgresClientKit", from: "1.0.0"),
],
```

- Reference the `PostgresClientKit` product in the `targets`.  For example:

```swift
targets: [
    .target(
        name: "MyProject",
        dependencies: ["PostgresClientKit"]),
]
```

Import to your source code file:

```swift
import PostgresClientKit
```

### Using CocoaPods

Add `PostgresClientKit` to your `Podfile`.  For example:

```
target 'MyApp' do
  pod 'PostgresClientKit', '~> 1.0'
end
```

Then run `pod install`.

Import to your source code file:

```swift
import PostgresClientKit
```

## Documentation

- [API](https://codewinsdotcom.github.io/PostgresClientKit/Docs/API/index.html)
- [Troubleshooting](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/Docs/troubleshooting.md)
- [FAQ](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/Docs/faq.md)

## Additional examples

- [PostgresClientKit-CommandLine-Example](https://github.com/pitfield/PostgresClientKit-CommandLine-Example): an example command-line application

- [PostgresClientKit-iOS-Example](https://github.com/pitfield/PostgresClientKit-iOS-Example): an example iOS app

## Contributing

Thank you for your interest in contributing to PostgresClientKit.

This project has a code of conduct.  See [CODE_OF_CONDUCT.md](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/CODE_OF_CONDUCT.md) for details.

Please use [issues](https://github.com/codewinsdotcom/PostgresClientKit/issues) to:

- ask questions
- report problems (bugs)
- request enhancements

Pull requests against the `develop` branch are welcomed.  For a non-trivial contribution (for example, more than correcting spelling, typos, or whitespace) please first discuss the proposed change by opening an issue.
    
## License

PostgresClientKit is licensed under the Apache 2.0 license.  See [LICENSE](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/LICENSE) for details.

## Versioning

PostgresClientKit uses [Semantic Versioning 2.0.0](https://semver.org).  For the versions available, see the [tags on this repository](https://github.com/codewinsdotcom/PostgresClientKit/releases).

## Built with

- [Jazzy](https://github.com/realm/jazzy) - generation of API documentation pages

## Authors

- David Pitfield [(@pitfield)](https://github.com/pitfield)
