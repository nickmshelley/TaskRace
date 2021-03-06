//
//  UserDataController.swift
//  Todo
//
//  Created by Heather Shelley on 10/23/14.
//  Copyright (c) 2014 Mine. All rights reserved.
//

import Foundation
import YapDatabase

let ProfileChangedNotification = "ProfileChangedNotification"

struct UserDataController {
    private static var sharedInstance = UserDataController()
    let database: YapDatabase
    let connection: YapDatabaseConnection
    static var currentProfile: String {
        get {
            return NSUserDefaults.standardUserDefaults().stringForKey("current_profile") ?? "Default"
        }
        set {
            let currentProfile = NSUserDefaults.standardUserDefaults().stringForKey("current_profile") ?? ""
            if newValue != currentProfile {
                NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: "current_profile")
                sharedInstance = UserDataController()
                NSNotificationCenter.defaultCenter().postNotificationName(ProfileChangedNotification, object: nil)
            }
        }
    }
    
    static func sharedController() -> UserDataController {
        return UserDataController.sharedInstance
    }
    
    private init() {
        database = YapDatabase(path: UserDataController.databasePath())
        connection = database.newConnection()
    }
    
    private static func databasePath() -> String {
        let dbPath = databasePathForProfile(currentProfile)
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath((dbPath as NSString).stringByDeletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
        } catch _ {
        }
        return dbPath
    }
    
    private static func databasePathForProfile(profile: String) -> String {
        return (NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, NSSearchPathDomainMask.UserDomainMask, true).last! as NSString).stringByAppendingPathComponent(profile + "Data")
    }
    
    // MARK: - Profiles
    
    static func allProfiles() -> [String] {
        return NSUserDefaults.standardUserDefaults().arrayForKey("profiles") as? [String] ?? []
    }
    
    static func addProfile(profile: String) {
        var profiles = allProfiles()
        profiles.append(profile)
        NSUserDefaults.standardUserDefaults().setObject(profiles, forKey: "profiles")
    }
    
    static func renameProfile(currentName: String, toProfile newName: String) {
        var profiles = allProfiles()
        if let index = profiles.indexOf(currentName) {
            profiles[index] = newName
            let directory = (databasePathForProfile(currentName) as NSString).stringByDeletingLastPathComponent
            for filename in try! NSFileManager.defaultManager().contentsOfDirectoryAtPath(directory) {
                if filename.hasPrefix(currentName) {
                    do {
                        try NSFileManager.defaultManager().moveItemAtPath((directory as NSString).stringByAppendingPathComponent(filename), toPath: (directory as NSString).stringByAppendingPathComponent(filename.stringByReplacingOccurrencesOfString(currentName, withString: newName)))
                    }
                    catch let error {
                        print(error)
                    }
                }
            }
            NSUserDefaults.standardUserDefaults().setObject(profiles, forKey: "profiles")
            
            if currentName == currentProfile {
                currentProfile = newName
            }
        }
    }
    
    static func removeProfile(profile: String) {
        var profiles = allProfiles()
        if profiles.count > 0 {
            profiles.removeAtIndex(profiles.indexOf(profile)!)
            NSUserDefaults.standardUserDefaults().setObject(profiles, forKey: "profiles")
            if profile == currentProfile {
                currentProfile = profiles.count > 0 ? profiles[0] : "Default"
            }
        }
    }
    
    // MARK: - Settings
    
    func useGlobalOrdering() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("useGlobalOrdering")
    }
    
    func setUseGlobalOrdering(useGlobal: Bool) {
        NSUserDefaults.standardUserDefaults().setBool(useGlobal, forKey: "useGlobalOrdering")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    // MARK: - Templates
    
    func allTemplates() -> [Template] {
        var templates: [Template] = []
        connection.readWithBlock() { transaction in
            transaction.enumerateKeysAndObjectsInCollection("templates") { key, object, _ in
                if let template = object as? Template {
                    templates.append(template)
                }
            }
        }
        
        return templates.sort { $0.position < $1.position }
    }
    
    func regularTemplateLists() -> [List] {
        return allTemplates().flatMap { template in
            if !template.anytime {
                if let listID = template.listID {
                    return self.listWithID(listID)
                }
            }
            
            return nil
        }
    }
    
    func containsTemplate(template: Template) -> Bool {
        var hasTemplate = false
        connection.readWithBlock { transaction in
            if (transaction.objectForKey(template.id, inCollection: "templates") as? Template) != nil {
                hasTemplate = true
            }
        }
        
        return hasTemplate
    }
    
    func addOrUpdateTemplate(template: Template) -> Void {
        connection.readWriteWithBlock() { transaction in
            transaction.setObject(template, forKey: template.id, inCollection: "templates")
        }
    }
    
    func updateTemplates(templates: [Template]) -> Void {
        connection.readWriteWithBlock() { transaction in
            for template in templates {
                transaction.setObject(template, forKey: template.id, inCollection: "templates")
            }
        }
    }
    
    func removeTemplate(template: Template) -> Void {
        connection.readWriteWithBlock() { transaction in
            transaction.removeObjectForKey(template.id, inCollection: "templates")
        }
    }
    
    // MARK: - Days
    
    func dayForDate(date: Date) -> Day {
        var days: [Day] = []
        connection.readWithBlock() { transaction in
            transaction.enumerateKeysAndObjectsInCollection("days") { key, object, _ in
                if let day = object as? Day {
                    days.append(day)
                }
            }
        }
        
        let day: Day
        if let existingDay = days.filter({ $0.date == date }).first {
            day = existingDay
        } else {
            let list = List()
            addOrUpdateList(list)
            day = Day(date: date, listID: list.id)
            addOrUpdateDay(day)
        }
        
        return day
    }
    
    private func addOrUpdateDay(day: Day) -> Void {
        connection.readWriteWithBlock() { transaction in
            transaction.setObject(day, forKey: day.id, inCollection: "days")
        }
    }
    
    // MARK: - Lists
    
    func listWithID(id: String) -> List {
        var list: List? = nil
        connection.readWithBlock() { transaction in
            list = transaction.objectForKey(id, inCollection: "lists") as? List
        }
        if let list = list {
            return list
        } else {
            assert(false, "No list returned for id \(id)")
            return List()
        }
    }
    
    func emptyList() -> List {
        let list = List()
        addOrUpdateList(list)
        return list
    }
    
    func updateDayListFromTemplates(list list: List, forDate date: Date) -> List {
        let templates = allTemplates()
        for template in templates {
            if !template.anytime && template.templateDays.intersect(date.dayOfWeek) {
                if let listID = template.listID {
                    let templateList = listWithID(listID)
                    for templateItem in templateList.items {
                        if let index = list.items.indexOf(templateItem) {
                            let item = list.items[index]
                            item.updateFromItem(templateItem)
                        } else {
                            let newItem = templateItem.copy() as! TodoItem
                            list.items.append(newItem)
                        }
                    }
                }
            }
        }
        
        if useGlobalOrdering() {
            list.items.sortInPlace { $0.position <= $1.position }
        }
        
        addOrUpdateList(list)
        return list
    }
    
    func addOrUpdateList(list: List) -> Void {
        connection.readWriteWithBlock() { transaction in
            transaction.setObject(list, forKey: list.id, inCollection: "lists")
        }
    }
    
    func anytimeListsForDate(date: Date) -> [(name: String, list: List)] {
        return allTemplates().flatMap { template -> (String, List)? in
            if template.anytime && template.templateDays.intersect(date.dayOfWeek) {
                if let id = template.listID {
                    let list = self.listWithID(id)
                    list.items = list.items.filter() { item in
                        return !item.completed
                    }
                    return (template.name, list	)
                }
            }
            return nil
        }
    }
    
    func pastDueItems() -> [(item: TodoItem, listID: String)] {
        return allTemplates().flatMap { template -> [(item: TodoItem, listID: String)] in
            guard template.anytime, let id = template.listID else { return [] }
            let list = self.listWithID(id)
            let today = Date(date: NSDate())
            return list.items.filter {
                if let dueDate = $0.dueDate {
                    return !$0.completed && dueDate <= today
                }
                return false
                }.sort { $0.dueDate! > $1.dueDate! }.map { ($0, id) }
        }
    }
    
    // MARK: - Store
    
    func storePoints() -> Int {
        var points = 0
        connection.readWithBlock() { transaction in
            if let pts = transaction.objectForKey("points", inCollection: "store") as? NSNumber {
                points = pts.integerValue
            }
        }
        
        return points
    }
    
    func updateWithCompletedItem(item: AnyObject, numberComplete: Int) -> Void {
        let pointsToAdd: Int = {
            switch item {
            case let storeItem as StoreItem:
                return numberComplete * -storeItem.points
            case let todoItem as TodoItem:
                return numberComplete * todoItem.points
            default:
                return 0
            }
        }()
        
        if pointsToAdd != 0 {
            connection.readWriteWithBlock() { transaction in
                var currentPoints = 0
                if let storePoints = transaction.objectForKey("points", inCollection: "store") as? NSNumber {
                    currentPoints += storePoints.integerValue
                }
                transaction.setObject(NSNumber(integer: currentPoints + pointsToAdd), forKey: "points", inCollection: "store")
                
                let historyItem = HistoryItem(name: item.name, points: pointsToAdd, dateCompleted: NSDate(), numberCompleted: numberComplete)
                transaction.setObject(historyItem, forKey: historyItem.id, inCollection: "history")
            }
        }
    }
    
    func storeItems() -> [StoreItem] {
        var items: [StoreItem] = []
        connection.readWithBlock() { transaction in
            transaction.enumerateKeysAndObjectsInCollection("store") { key, object, _ in
                if let item = object as? StoreItem {
                    items.append(item)
                }
            }
        }
        
        return items.sort { $0.position < $1.position }
    }
    
    func addOrUpdateStoreItem(item: StoreItem) -> Void {
        connection.readWriteWithBlock() { transaction in
            transaction.setObject(item, forKey: item.id, inCollection: "store")
        }
    }
    
    func deleteStoreItem(item: StoreItem) -> Void {
        connection.readWriteWithBlock() { transaction in
            transaction.removeObjectForKey(item.id, inCollection: "store")
        }
    }
    
    func updateStoreItems(items: [StoreItem]) -> Void {
        connection.readWriteWithBlock() { transaction in
            for item in items {
                transaction.setObject(item, forKey: item.id, inCollection: "store")
            }
        }
    }
    
    // MARK: - History
    
    func historyItems() -> [HistoryItem] {
        var items: [HistoryItem] = []
        connection.readWithBlock() { transaction in
            transaction.enumerateKeysAndObjectsInCollection("history") { key, object, _ in
                if let item = object as? HistoryItem {
                    items.append(item)
                }
            }
        }
        
        return items.sort { $0.dateCompleted.timeIntervalSince1970 > $1.dateCompleted.timeIntervalSince1970 }
    }
}
