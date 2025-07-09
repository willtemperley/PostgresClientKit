//
//  SQLStatementTest.swift
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

import PostgresClientKit
import XCTest

/// Tests various DML statements.
class SQLStatementTest: PostgresClientKitTestCase {
    
    func testCRUD() {
        
        func time(_ name: String, operation: () throws -> Void) throws {
            let start = Date()
            try operation()
            let elapsed = Date().timeIntervalSince(start) * 1000
            Postgres.logger.info("\(name): elapsed time \(elapsed) ms")
        }
        
        do {
            try createWeatherTable()
            let connection = try Connection(configuration: terryConnectionConfiguration)

            // Create 1000 days of random weather records for San Jose.
            var weatherHistory = [[PostgresValueConvertible]]()
            
            for i in 0..<1000 {
                
                let tempLo = Int.random(in: 20...70)
                let tempHi = Int.random(in: tempLo...100)
                
                let prcp: Decimal? = {
                    let r = Double.random(in: 0..<1)
                    if r < 0.1 { return nil }
                    if r < 0.8 { return Decimal.zero }
                    return Decimal(Double(Int.random(in: 1...20)) / 10.0)
                }()
                
                let date: PostgresDate = {
                    let pgd = PostgresDate(year: 2000, month: 1, day: 1)!
                    var d = pgd.date(in: utcTimeZone)
                    d = enUsPosixUtcCalendar.date(byAdding: .day, value: i, to: d)!
                    return d.postgresDate(in: utcTimeZone)
                }()
                
                weatherHistory.append([ "San Jose", tempLo, tempHi, prcp, date ])
            }
            
            // INSERT the weather records.
            try time("INSERT \(weatherHistory.count) rows") {
                try connection.beginTransaction()
                
                let text = "INSERT INTO weather VALUES ($1, $2, $3, $4, $5)"
                let statement = try connection.prepareStatement(text: text)
                
                for weather in weatherHistory {
                    let cursor = try statement.execute(parameterValues: weather)
                    XCTAssertEqual(cursor.rowCount, 1)
                }
                
                try connection.commitTransaction()
            }
            
            // SELECT the weather records.
            var selectedWeatherHistory = [[PostgresValueConvertible]]()
                
            try time("SELECT \(weatherHistory.count) rows") {
                let text = "SELECT * FROM weather WHERE city = $1 ORDER BY date"
                let statement = try connection.prepareStatement(text: text)
                let cursor = try statement.execute(parameterValues: [ "San Jose" ])
                
                for row in cursor {
                    let columns = try row.get().columns
                    let city = try columns[0].string()
                    let tempLo = try columns[1].int()
                    let tempHi = try columns[2].int()
                    let prcp = try columns[3].optionalDecimal()
                    let date = try columns[4].date()
                    selectedWeatherHistory.append([ city, tempLo, tempHi, prcp, date ])
                }
                
                XCTAssertEqual(cursor.rowCount, selectedWeatherHistory.count)
            }
            
            // Check the SELECTed weather records.
            XCTAssertEqual(selectedWeatherHistory.count, weatherHistory.count)
            
            for (i, weather) in weatherHistory.enumerated() {
                let selectedWeather = selectedWeatherHistory[i]
                XCTAssertEqual(selectedWeather.count, weather.count)
                for j in 0..<weather.count {
                    XCTAssertEqual(selectedWeather[j].postgresValue, weather[j].postgresValue)
                }
            }
            
            // UPDATE the weather records (one by one).
            try time("UPDATE \(weatherHistory.count) rows") {
                try connection.beginTransaction()
                
                let text = """
                    UPDATE weather
                        SET temp_lo = temp_lo - 1, temp_hi = temp_hi + 1
                        WHERE city = $1 AND date = $2
                    """
                let statement = try connection.prepareStatement(text: text)
                
                for weather in weatherHistory {
                    let cursor = try statement.execute(parameterValues: [ weather[0], weather[4] ])
                    XCTAssertEqual(cursor.rowCount, 1)
                }
                
                try connection.commitTransaction()
            }
            
            // SELECT the updated weather records.
            selectedWeatherHistory = []
            
            try time("SELECT \(weatherHistory.count) rows") {
                let text = "SELECT * FROM weather WHERE city = $1 ORDER BY date"
                let statement = try connection.prepareStatement(text: text)
                let cursor = try statement.execute(parameterValues: [ "San Jose" ])
                
                for row in cursor {
                    let columns = try row.get().columns
                    let city = try columns[0].string()
                    let tempLo = try columns[1].int()
                    let tempHi = try columns[2].int()
                    let prcp = try columns[3].optionalDecimal()
                    let date = try columns[4].date()
                    selectedWeatherHistory.append([ city, tempLo, tempHi, prcp, date ])
                }
                
                XCTAssertEqual(cursor.rowCount, selectedWeatherHistory.count)
            }
            
            // Check the SELECTed updated weather records.
            XCTAssertEqual(selectedWeatherHistory.count, weatherHistory.count)
            
            for (i, weather) in weatherHistory.enumerated() {
                let selectedWeather = selectedWeatherHistory[i]
                XCTAssertEqual(selectedWeather.count, weather.count)
                XCTAssertEqual(selectedWeather[0].postgresValue, weather[0].postgresValue)
                XCTAssertEqual(selectedWeather[1] as! Int, weather[1] as! Int - 1)
                XCTAssertEqual(selectedWeather[2] as! Int, weather[2] as! Int + 1)
                XCTAssertEqual(selectedWeather[3].postgresValue, weather[3].postgresValue)
                XCTAssertEqual(selectedWeather[4].postgresValue, weather[4].postgresValue)
            }
            
            // DELETE the weather records (all at once).
            try time("DELETE \(weatherHistory.count) rows") {
                let text = "DELETE FROM weather WHERE city = $1"
                let statement = try connection.prepareStatement(text: text)
                let cursor = try statement.execute(parameterValues: [ "San Jose" ])
                XCTAssertEqual(cursor.rowCount, weatherHistory.count)
            }
            
            // SELECT COUNT(*) to confirm they were deleted.
            do {
                let text = "SELECT COUNT(*) FROM weather WHERE city = 'San Jose'"
                let statement = try connection.prepareStatement(text: text)
                let cursor = try statement.execute()
                let count = try cursor.next()!.get().columns[0].int()
                XCTAssertEqual(count, 0)
            }
            
            // Postgres allows an empty statement.
            do {
                let text = ""
                let statement = try connection.prepareStatement(text: text)
                let cursor = try statement.execute()
                XCTAssertNil(cursor.next())
            }
        } catch {
            XCTFail(String(describing: error))
        }
    }
    
    func testSQLCursor() {
        
        do {
            try createWeatherTable()
            let connection = try Connection(configuration: terryConnectionConfiguration)
            
            var text = "DECLARE wc CURSOR WITH HOLD FOR SELECT * FROM weather"
            var statement = try connection.prepareStatement(text: text)
            try statement.execute()
            
            text = "FETCH FORWARD 2 FROM wc"
            statement = try connection.prepareStatement(text: text)
            var rowCount = 0

            while true {
                let cursor = try statement.execute()
                var count = 0
                
                for row in cursor {
                    _ = try row.get()
                    count += 1
                }
                
                XCTAssertEqual(cursor.rowCount, count)
                
                if count == 0 {
                    break
                }
                
                rowCount += count
            }
            
            XCTAssertEqual(rowCount, 3)
        } catch {
            XCTFail(String(describing: error))
        }
    }

    func testResultMetadata() {
        
        do {
            try createWeatherTable()
            let connection = try Connection(configuration: terryConnectionConfiguration)
            
            func checkResultMetadata(columns: [ColumnMetadata]) {
                
                XCTAssertEqual(columns.count, 5)
                let expectedNames = [ "city", "temp_lo", "temp_hi", "prcp", "date" ]

                for (index, column) in columns.enumerated() {
                    XCTAssertEqual(column.name, expectedNames[index])
                    XCTAssertEqual(column.tableOID, columns[0].tableOID)
                    XCTAssertEqual(column.columnAttributeNumber, index + 1)
                    XCTAssertNotEqual(column.dataTypeOID, 0)
                    XCTAssertNotEqual(column.dataTypeSize, 0)
                    XCTAssertNotEqual(column.dataTypeModifier, 0)
                }
            }
            
            // No result metadata for statements that don't return results.
            do {
                let text = "UPDATE weather SET temp_hi = temp_hi + 1 WHERE city = 'Hayward'"
                let statement = try connection.prepareStatement(text: text)
                
                var cursor = try statement.execute()
                XCTAssertEqual(cursor.rowCount, 1)
                XCTAssertNil(cursor.columns) // retrieveColumnMetadata defaults to false
                
                cursor = try statement.execute(retrieveColumnMetadata: false)
                XCTAssertEqual(cursor.rowCount, 1)
                XCTAssertNil(cursor.columns) // retrieveColumnMetadata set to false
                
                cursor = try statement.execute(retrieveColumnMetadata: true)
                XCTAssertEqual(cursor.rowCount, 1)
                XCTAssertNil(cursor.columns) // UPDATE returns no results
            }
            
            // Result metadata for statements that do return results (but 0 rows).
            do {
                let text = "SELECT * FROM weather WHERE city = 'Seattle'"
                let statement = try connection.prepareStatement(text: text)
                
                var cursor = try statement.execute()
                XCTAssertEqual(cursor.rowCount, 0)
                XCTAssertNil(cursor.columns) // retrieveColumnMetadata defaults to false
                
                cursor = try statement.execute(retrieveColumnMetadata: false)
                XCTAssertEqual(cursor.rowCount, 0)
                XCTAssertNil(cursor.columns) // retrieveColumnMetadata set to false
                
                cursor = try statement.execute(retrieveColumnMetadata: true)
                XCTAssertEqual(cursor.rowCount, 0)
                XCTAssertNotNil(cursor.columns)
                checkResultMetadata(columns: cursor.columns!)
            }
                        
            // Result metadata available even before retrieving first row.
            do {
                let text = "SELECT city, temp_lo, temp_hi, prcp, date FROM weather WHERE city = 'San Francisco'"
                let statement = try connection.prepareStatement(text: text)
                
                let cursor = try statement.execute(retrieveColumnMetadata: true)
                XCTAssertNil(cursor.rowCount)
                XCTAssertNotNil(cursor.columns)
                checkResultMetadata(columns: cursor.columns!)
                
                for _ in cursor { } // drain cursor
                XCTAssertEqual(cursor.rowCount, 2)
                XCTAssertNotNil(cursor.columns) // result metadata still available
                checkResultMetadata(columns: cursor.columns!)
            }
        } catch {
            XCTFail(String(describing: error))
        }
    }
}

// EOF
