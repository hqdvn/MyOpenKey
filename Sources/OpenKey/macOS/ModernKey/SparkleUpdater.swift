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
    
    @objc public func start() {
        // Đảm bảo singleton controller được khởi tạo sớm ngay khi app launch
        _ = controller
    }
    
    @objc public func checkForUpdates() {
        // Đưa việc hiển thị UI ra RunLoop default để menu bar đóng hoàn toàn
        RunLoop.main.perform(inModes: [.default]) { [weak self] in
            guard let self = self else { return }
            NSApp.activate(ignoringOtherApps: true)
            
            guard let controller = self.controller else { return }
            
            // Nếu updater đã sẵn sàng, gọi trực tiếp
            if controller.updater.canCheckForUpdates {
                controller.checkForUpdates(nil)
                return
            }
            
            // Nếu vừa khởi động và Sparkle chưa xong chu kỳ init runloop:
            // retry sau 0.3s thay vì bỏ qua khiến người dùng phải bấm lần 2
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.activate(ignoringOtherApps: true)
                controller.checkForUpdates(nil)
            }
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
