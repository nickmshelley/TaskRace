//
//  UserDataController.swift
//  Todo
//
//  Created by Heather Shelley on 10/23/14.
//  Copyright (c) 2014 Mine. All rights reserved.
//

import Foundation

struct UserDataController {
    private static let sharedInstance = UserDataController()
    let database: YapDatabase
    let connection: YapDatabaseConnection
    
    static func sharedController() -> UserDataController {
        return UserDataController.sharedInstance
    }
    
    private init() {
        let dbPath = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, NSSearchPathDomainMask.UserDomainMask, true).last!.stringByAppendingPathComponent("data")
        NSFileManager.defaultManager().createDirectoryAtPath(dbPath, withIntermediateDirectories: true, attributes: nil, error: nil)
        database = YapDatabase(path: dbPath)
        connection = database.newConnection()
    }
    
    // MARK: - Templates
    
    func allTemplates() -> [Template] {
        var templates: [Template] = []
        self.connection.readWithBlock() { transaction in
            transaction.enumerateKeysAndObjectsInCollection("templates") { key, object, _ in
                if let template = object as? Template {
                    templates.append(template)
                }
            }
        }
        
        return sorted(templates) { $0.position < $1.position }
    }
    
    func addOrUpdateTemplate(template: Template) -> Void {
        self.connection.readWriteWithBlock() { transaction in
            transaction.setObject(template, forKey: template.id, inCollection: "templates")
        }
    }
    
    func updateTemplates(templates: [Template]) -> Void {
        self.connection.readWriteWithBlock() { transaction in
            for template in templates {
                transaction.setObject(template, forKey: template.id, inCollection: "templates")
            }
        }
    }
    
    func removeTemplate(template: Template) -> Void {
        self.connection.readWriteWithBlock() { transaction in
            transaction.removeObjectForKey(template.id, inCollection: "templates")
        }
    }
    
    // MARK: - Days
    
    func allDays() -> [Day] {
        var days: [Day] = []
        self.connection.readWithBlock() { transaction in
            transaction.enumerateKeysAndObjectsInCollection("days") { key, object, _ in
                if let day = object as? Day {
                    days.append(day)
                }
            }
        }
        
        return sorted(days) { $0.date < $1.date }
    }
    
    func addOrUpdateDay(day: Day) -> Void {
        self.connection.readWriteWithBlock() { transaction in
            transaction.setObject(day, forKey: day.id, inCollection: "days")
        }
    }
    
    func createDayForToday() -> Day {
        let day = Day(date: Date(date: NSDate()))
        
        self.connection.readWriteWithBlock() { transaction in
            transaction.setObject(day, forKey: day.id, inCollection: "days")
        }
        
        return day
    }
    
    // MARK: - Lists
    
    func listWithID(id: String) -> List {
        var list: List? = nil
        self.connection.readWithBlock() { transaction in
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
    
    func listForDate(date: Date) -> List {
        let list = List()
        let templates = allTemplates()
        for template in templates {
            if !template.anytime && template.templateDays & date.dayOfWeek {
                if let listID = template.listID {
                    let templateList = listWithID(listID)
                    list.items += templateList.items.map { $0.copy() as TodoItem }
                }
            }
        }
        
        addOrUpdateList(list)
        return list
    }
    
    func addOrUpdateList(list: List) -> Void {
        self.connection.readWriteWithBlock() { transaction in
            transaction.setObject(list, forKey: list.id, inCollection: "lists")
        }
    }
}
