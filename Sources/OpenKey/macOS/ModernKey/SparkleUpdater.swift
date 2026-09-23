//
//  SparkleUpdater.swift
//  MyOpenKey
//
//  Integrated Sparkle 2 Auto-Update Controller
//

import Foundation
import AppKit
import Sparkle

@objc public class SparkleUpdater: NSObject {
    @objc public static let shared = SparkleUpdater()
    
    private var controller: SPUStandardUpdaterController?
    private var internalDelegate: SparkleInternalDelegate?
    
    public override init() {
        super.init()
        let delegate = SparkleInternalDelegate()
        self.internalDelegate = delegate
        // Initialize Sparkle standard controller
        self.controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: delegate, userDriverDelegate: delegate)
    }
    
    @objc public func checkForUpdates() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.controller?.checkForUpdates(nil)
        }
    }
    
    @objc public var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }
}

private class SparkleInternalDelegate: NSObject, SPUStandardUserDriverDelegate, SPUUpdaterDelegate {
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}
