//
//  TimeLog2Tests.swift
//  TimeLog2Tests
//
//  Created by Alberto Barrago on 10/05/2026.
//

import Testing
import TimelogCore

struct TimeLog2Tests {

    @Test func appTestTargetCanImportSharedCore() {
        let client = Client(name: "Test Client")
        #expect(client.name == "Test Client")
    }

}
