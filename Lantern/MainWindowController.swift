//
//	MainWindowController.swift
//	Hoverlytics for Mac
//
//	Created by Patrick Smith on 29/03/2015.
//	Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

import Cocoa
import BurntFoundation
import BurntCocoaUI
import LanternModel
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
	switch (lhs, rhs) {
	case let (l?, r?):
		return l < r
	case (nil, _?):
		return true
	default:
		return false
	}
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
	switch (lhs, rhs) {
	case let (l?, r?):
		return l > r
	default:
		return rhs < lhs
	}
}



private let sectionUserDefaultKey = "mainSection"


class MainWindowController: NSWindowController {
	
	let mainState = MainState()
	
	let modelManager = LanternModel.ModelManager.sharedManager
	
	var mainViewController: ViewController! {
		return contentViewController as! ViewController
	}
	
	var toolbarAssistant: MainWindowToolbarAssistant!
	@IBOutlet var toolbar: NSToolbar! {
		didSet {
			toolbarAssistant = MainWindowToolbarAssistant(toolbar: toolbar, mainState: mainState, modelManager: modelManager)
			
			toolbarAssistant.prepareNewSiteButton = { button in
				button.target = nil
				button.action = #selector(MainWindowController.showAddSite(_:))
			}
			
			toolbarAssistant.prepareSiteSettingsButton = { [unowned self] button in
				button.target = self.mainViewController
				button.action = #selector(ViewController.showSiteSettings(_:))
			}
		}
	}
	
	var chosenSiteDidChangeObserver: AnyObject?

	override func windowDidLoad() {
		super.windowDidLoad()
		
		if let window = window {
			window.delegate = self
			
			// Prefer tabbing
			window.tabbingIdentifier = "main"
			window.tabbingMode = .preferred
			
			// Combine title and toolbar
			window.titleVisibility = .hidden
			
			//window.appearance = NSAppearance(named: NSAppearanceNameVibrantDark)
			//window.appearance = NSAppearance(named: NSAppearanceNameVibrantLight)
			
			window.title = "New"
		}
		
		mainViewController.modelManager = modelManager
		mainViewController.mainState = mainState
		
		let nc = NotificationCenter.default
		chosenSiteDidChangeObserver = nc.addObserver(forName: NSNotification.Name(rawValue: MainState.Notification.ChosenSiteDidChange.rawValue), object: mainState, queue: nil) { [unowned self] note in
			self.window?.title = self.windowTitle(forDocumentDisplayName: "New")
		}
	}
	
	deinit {
		let nc = NotificationCenter.default
		if let chosenSiteDidChangeObserver: AnyObject = chosenSiteDidChangeObserver {
			nc.removeObserver(chosenSiteDidChangeObserver)
		}
	}
	
	@IBAction func showAddSite(_ sender: AnyObject?) {
		mainViewController.showAddSiteRelativeToView(toolbarAssistant.addSiteButton)
	}
	
	@IBAction func focusOnSearchPagesField(_ sender: AnyObject?) {
		toolbarAssistant.focusOnSearchPagesField(sender)
	}
	
	override func windowTitle(forDocumentDisplayName displayName: String) -> String {
		return mainState.chosenSite?.name ?? displayName
	}
}

extension MainWindowController: NSWindowDelegate {
	
}


struct ToolbarItem<ControlClass: NSControl> {
	var control: ControlClass!
	
	typealias PrepareBlock = (_ control: ControlClass) -> Void
	var prepare: PrepareBlock!
}


class MainWindowToolbarAssistant: NSObject, NSToolbarDelegate {
	let toolbar: NSToolbar
	let mainState: MainState
	let mainStateObserver: NotificationObserver<MainState.Notification>
	let modelManager: LanternModel.ModelManager
	
	init(toolbar: NSToolbar, mainState: MainState, modelManager: LanternModel.ModelManager) {
		self.toolbar = toolbar
		self.mainState = mainState
		self.modelManager = modelManager
		
		mainStateObserver = NotificationObserver<MainState.Notification>(object: mainState)
		
		super.init()
		
		mainStateObserver.observe(.ChosenSiteDidChange) { [unowned self] _ in
			if let chosenSite = self.mainState.chosenSite {
				let choice = SiteMenuItem.choice(.savedSite(chosenSite))
				self.sitesPopUpButtonAssistant?.selectedUniqueIdentifier = choice.uniqueIdentifier
			}
		}
		
		toolbar.delegate = self
		
		startObservingModelManager()
	}
	
	deinit {
		stopObservingModelManager()
	}
	
	var modelManagerNotificationObservers = [ModelManagerNotification: AnyObject]()
	
	func startObservingModelManager() {
		let nc = NotificationCenter.default
		let mainQueue = OperationQueue.main
		
		func addObserver(_ notificationIdentifier: LanternModel.ModelManagerNotification, block: @escaping (Notification!) -> ()) {
			let observer = nc.addObserver(forName: Notification.Name(notificationIdentifier.notificationName), object: modelManager, queue: mainQueue, using: block)
			modelManagerNotificationObservers[notificationIdentifier] = observer
		}
		
		addObserver(.allSitesDidChange) { (notification) in
			self.updateUIForSites()
		}
	}
	
	func stopObservingModelManager() {
		let nc = NotificationCenter.default
		
		for (_, observer) in modelManagerNotificationObservers {
			nc.removeObserver(observer)
		}
		modelManagerNotificationObservers.removeAll()
	}
	
	
	var sitesPopUpButton: NSPopUpButton!
	var chosenSiteChoice: SiteMenuItem = .loadingSavedSites
	var sitesPopUpButtonAssistant: PopUpButtonAssistant<SiteMenuItem>?
	let siteTag: Int = 1
	
	var siteChoices: [SiteMenuItem?] {
		var result: [SiteMenuItem?] = [
			SiteMenuItem.choice(.custom),
			nil
		]
		
		if let allSites = modelManager.allSites {
			let allSites = allSites.sorted(by: { $0.name < $1.name })
			
			if allSites.count == 0 {
				result.append(
					SiteMenuItem.noSavedSitesYet
				)
			}
			else {
				for site in allSites {
					result.append(
						SiteMenuItem.choice(.savedSite(site))
					)
				}
			}
		}
		else {
			result.append(
				SiteMenuItem.loadingSavedSites
			)
		}
		
		return result
	}
	
	func updateSitesPopUpButton() {
		#if DEBUG
			//println("updateSitesPopUpButton")
		#endif
		
		guard let popUpButton = sitesPopUpButton
			else { return }
		
		popUpButton.target = self
		popUpButton.action = #selector(MainWindowToolbarAssistant.chosenSiteDidChange(_:))
		
		
		let popUpButtonAssistant = sitesPopUpButtonAssistant ?? {
			let popUpButtonAssistant = PopUpButtonAssistant<SiteMenuItem>(popUpButton: popUpButton)
			
			let menuAssistant = popUpButtonAssistant.menuAssistant
			menuAssistant.customization.enabled = { siteChoice in
				switch siteChoice {
				case .loadingSavedSites, .noSavedSitesYet:
					return false
				default:
					return true
				}
			}
			
			self.sitesPopUpButtonAssistant = popUpButtonAssistant
			
			return popUpButtonAssistant
		}()
		
		popUpButtonAssistant.menuItemRepresentatives = siteChoices
		popUpButtonAssistant.update()
	}
	
	func updateUIForSites() {
		let hasSites = modelManager.allSites?.count > 0
		
		//sitesPopUpButton?.enabled = hasSites
		siteSettingsButton?.isEnabled = hasSites
		siteSettingsButton?.isHidden = !hasSites
		
		updateSitesPopUpButton()
	}
	
	@objc @IBAction func chosenSiteDidChange(_ sender: NSPopUpButton) {
		updateChosenSiteState()
	}

	func updateChosenSiteState() {
		if let siteMenuItem = sitesPopUpButtonAssistant?.selectedItemRepresentative {
			//mainState.chosenSite = site
			switch siteMenuItem {
			case .choice(let siteChoice):
				mainState.siteChoice = siteChoice
			default:
				mainState.siteChoice = .custom
			}
		}
		else {
			mainState.siteChoice = .custom
		}
		
		/*if let selectedItem = sitesPopUpButton.selectedItem {
			if let site = selectedItem.representedObject as? Site {
				println("chosenSite TO \(site.name)")
				mainState.chosenSite = site
			}
			else {
				println("chosenSite TO nil")
				mainState.chosenSite = nil
			}
		}*/
	}
	
	typealias PrepareButtonCallback = (NSButton) -> Void
	
	var addSiteButton: NSButton!
	var prepareNewSiteButton: PrepareButtonCallback?
	
	var siteSettingsButton: NSButton!
	var prepareSiteSettingsButton: PrepareButtonCallback?
	
	
	var searchPagesField: NSSearchField!
	@IBAction func focusOnSearchPagesField(_ sender: AnyObject?) {
		if let searchPagesField = searchPagesField {
			searchPagesField.window!.makeFirstResponder(searchPagesField)
		}
	}
	
	
	//var sectionItem = ToolbarItem<NSSegmentedControl>()
	
	
	func toolbarWillAddItem(_ notification: Notification) {
		let userInfo = (notification as NSNotification).userInfo!
		let toolbarItem = userInfo["item"] as! NSToolbarItem
		let itemIdentifier = toolbarItem.itemIdentifier
		var sizeToFit = false
		
		if itemIdentifier == "newSiteButton" {
			addSiteButton = toolbarItem.view as! NSButton
			prepareNewSiteButton?(addSiteButton)
		}
		else if itemIdentifier == "chosenSite" {
			sitesPopUpButton = toolbarItem.view as! NSPopUpButton
			updateUIForSites()
		}
		else if itemIdentifier == "siteSettingsButton" {
			siteSettingsButton = toolbarItem.view as! NSButton
			sizeToFit = true
			prepareSiteSettingsButton?(siteSettingsButton)
			updateUIForSites()
		}
		else if itemIdentifier == "searchPages" {
			searchPagesField = toolbarItem.view as! NSSearchField
		}
		
		if sizeToFit {
			let fittingSize = toolbarItem.view!.fittingSize
			toolbarItem.minSize = fittingSize
			toolbarItem.maxSize = fittingSize
		}
	}
}
