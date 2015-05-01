//
//  AppDelegate.swift
//  Hoverlytics for Mac
//
//  Created by Patrick Smith on 28/03/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

import Cocoa
import HoverlyticsModel


let NSApp = NSApplication.sharedApplication()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	deinit {
		let nc = NSNotificationCenter.defaultCenter()
		for observer in windowWillCloseObservers {
			nc.removeObserver(observer)
		}
		windowWillCloseObservers.removeAll()
	}

	func applicationDidFinishLaunching(aNotification: NSNotification) {
		// Create shared manager to ensure quickest start up time.
		let modelManager = HoverlyticsModel.ModelManager.sharedManager
		
	}

	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}
	
	lazy var mainStoryboard: NSStoryboard = {
		return NSStoryboard(name: "Main", bundle: nil)!
	}()
	
	var mainWindowControllers = [MainWindowController]()
	var windowWillCloseObservers = [AnyObject]()

	func applicationOpenUntitledFile(sender: NSApplication) -> Bool {
		let windowController = mainStoryboard.instantiateInitialController() as! MainWindowController
		windowController.showWindow(nil)
		
		mainWindowControllers.append(windowController)
		
		let nc = NSNotificationCenter.defaultCenter()
		windowWillCloseObservers.append(nc.addObserverForName(NSWindowWillCloseNotification, object: windowController.window!, queue: nil, usingBlock: { [unowned self] note in
			if let index = find(self.mainWindowControllers, windowController) {
				self.mainWindowControllers.removeAtIndex(index)
			}
		}))
		
		return true
	}
	
	@IBAction func newDocument(sender: AnyObject?) {
		self.applicationOpenUntitledFile(NSApp)
	}
}