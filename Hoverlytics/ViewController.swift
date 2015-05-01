//
//  ViewController.swift
//  Hoverlytics for Mac
//
//  Created by Patrick Smith on 28/03/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

import Cocoa
import HoverlyticsModel


class ViewController: NSViewController
{
	var modelManager: HoverlyticsModel.ModelManager!
	
	var section: MainSection!
	
	var mainState: MainState! {
		didSet {
			startObservingModelManager()
			updateMainViewForState()
		}
	}
	
	typealias MainStateNotification = MainState.Notification
	
	var mainStateNotificationObservers = [MainStateNotification: AnyObject]()
	
	func startObservingModelManager() {
		let nc = NSNotificationCenter.defaultCenter()
		let mainQueue = NSOperationQueue.mainQueue()
		
		func addObserver(notificationIdentifier: MainState.Notification, block: (NSNotification!) -> Void) {
			let observer = nc.addObserverForName(notificationIdentifier.notificationName, object: mainState, queue: mainQueue, usingBlock: block)
			mainStateNotificationObservers[notificationIdentifier] = observer
		}
		
		addObserver(.ChosenSiteDidChange) { (notification) in
			self.updateMainViewForState()
		}
	}
	
	func stopObservingModelManager() {
		let nc = NSNotificationCenter.defaultCenter()
		
		for (notificationIdentifier, observer) in mainStateNotificationObservers {
			nc.removeObserver(observer)
		}
		mainStateNotificationObservers.removeAll(keepCapacity: false)
	}
	
	
	lazy var pageStoryboard: NSStoryboard = {
		NSStoryboard(name: "Page", bundle: nil)!
	}()
	var mainSplitViewController: NSSplitViewController!
	var pageViewController: PageViewController!
	var statsViewController: StatsViewController!
	
	var lastChosenSite: Site!
	
	func updateMainViewForState() {
		let site = mainState?.chosenSite
		
		//println("updateMainViewForState \(site?.name) before \(lastChosenSite?.name)")
		// Make sure page view controller is not loaded more than once for a site.
		/*if site?.identifier == lastChosenSite?.identifier {
			return
		}*/
		if site === lastChosenSite {
			return
		}
		lastChosenSite = site
		
		if let site = site {
			pageViewController.GoogleOAuth2TokenJSONString = site.GoogleAPIOAuth2TokenJSONString
			pageViewController.hoverlyticsPanelDidReceiveGoogleOAuth2TokenCallback = { [unowned self] tokenJSONString in
				self.modelManager.setGoogleOAuth2TokenJSONString(tokenJSONString, forSite: site)
			}
			pageViewController.loadURL(site.homePageURL)
			
			
			statsViewController.primaryURL = site.homePageURL
		}
		else {
			//pageViewController.loadURL(nil)
			statsViewController.primaryURL = nil
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		mainSplitViewController = NSSplitViewController()
		mainSplitViewController.splitView.vertical = false
		//mainSplitViewController.splitView.dividerStyle = .PaneSplitter
		mainSplitViewController.splitView.dividerStyle = .Thick
		fillWithChildViewController(mainSplitViewController)
		
		let storyboard = self.pageStoryboard
		
		// Create page view controller.
		let pageViewController = storyboard.instantiateControllerWithIdentifier("Page View Controller") as! PageViewController
		pageViewController.navigatedURLDidChangeCallback = { URL in
			if pageViewController.crawlWhileBrowsing {
				#if DEBUG
					println("navigatedURLDidChangeCallback \(URL)")
				#endif
				self.statsViewController.crawlNavigatedURL(URL)
			}
		}
		
		
		let statsViewController = storyboard.instantiateControllerWithIdentifier("Stats View Controller") as! StatsViewController
		statsViewController.didChooseURLCallback = { URL, pageInfo in
			if pageInfo.baseContentType == .LocalHTMLPage {
				self.pageViewController.loadURL(URL)
			}
		}
		
		
		mainSplitViewController.addSplitViewItem({
			let item = NSSplitViewItem(viewController: pageViewController)
			//item.canCollapse = true
			return item
			}())
		//mainSplitViewController.addChildViewController(pageViewController)
		self.pageViewController = pageViewController
		
		mainSplitViewController.addSplitViewItem({
			let item = NSSplitViewItem(viewController: statsViewController)
			//item.canCollapse = true
			return item
		}())
		//mainSplitViewController.addChildViewController(statsViewController)
		self.statsViewController = statsViewController
	}
	
	
	lazy var siteSettingsStoryboard = NSStoryboard(name: "SiteSettings", bundle: nil)!
	lazy var addSiteViewController: SiteSettingsViewController = {
		let vc = self.siteSettingsStoryboard.instantiateControllerWithIdentifier("Add Site View Controller") as! SiteSettingsViewController
		vc.modelManager = self.modelManager
		return vc
	}()
	lazy var siteSettingsViewController: SiteSettingsViewController = {
		let vc = self.siteSettingsStoryboard.instantiateControllerWithIdentifier("Site Settings View Controller") as! SiteSettingsViewController
		vc.modelManager = self.modelManager
		return vc
	}()
	
	
	@IBAction func showAddSite(button: NSButton) {
		if addSiteViewController.presentingViewController != nil {
			dismissViewController(addSiteViewController)
		}
		else {
			presentViewController(addSiteViewController, asPopoverRelativeToRect: button.bounds, ofView: button, preferredEdge: NSMaxYEdge, behavior: .Semitransient)
		}
	}
	
	
	@IBAction func showSiteSettings(button: NSButton) {
		if siteSettingsViewController.presentingViewController != nil {
			dismissViewController(siteSettingsViewController)
		}
		else {
			if let chosenSite = mainState?.chosenSite {
				siteSettingsViewController.updateUIWithSiteValues(chosenSite.values)
				
				let modelManager = self.modelManager
				siteSettingsViewController.willClose = { siteSettingsViewController in
					let (siteValues, error) = siteSettingsViewController.copySiteValuesFromUI()
					if let siteValues = siteValues {
						modelManager.updateSiteWithValues(chosenSite, siteValues: siteValues)
					}
				}
				
				presentViewController(siteSettingsViewController, asPopoverRelativeToRect: button.bounds, ofView: button, preferredEdge: NSMaxYEdge, behavior: .Semitransient)
			}
		}
	}
	
	
	override var representedObject: AnyObject? {
		didSet {
			
		}
	}
}
