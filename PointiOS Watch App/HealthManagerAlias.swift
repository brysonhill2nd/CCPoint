//
//  HealthManagerAlias.swift
//  ClaudePoint Watch App
//
//  Type alias for health manager compatibility
//

import Foundation

// Type alias to use existing WatchHealthKitManager as HealthManager
// This allows the rest of the code to reference HealthManager.shared
typealias HealthManager = WatchHealthKitManager
