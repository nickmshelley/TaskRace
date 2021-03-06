//
//  TemplatesViewController.swift
//  Todo
//
//  Created by Heather Shelley on 11/6/14.
//  Copyright (c) 2014 Mine. All rights reserved.
//

import UIKit

class TemplatesViewController: UITableViewController {
    
    var orderItemsButton: UIBarButtonItem!
    var sections: [(title: String, templates: [Template])] = []
    
    override func viewDidLoad() {
        navigationItem.leftBarButtonItem = editButtonItem()
        orderItemsButton = UIBarButtonItem(title: "Order Items", style: .Plain, target: self, action: "orderItems")
        tableView.allowsSelectionDuringEditing = true
    }
    
    override func viewWillAppear(animated: Bool) {
        updateData()
        tableView.reloadData()
    }
    
    private func updateData() {
        let templates = UserDataController.sharedController().allTemplates()
        sections = [("Regular", templates.filter { !$0.anytime }), ("Anytime", templates.filter { $0.anytime })]
    }
    
    @IBAction func addPressed(sender: UIBarButtonItem) -> Void {
        let templates = sections[0].templates
        let position = templates.count
        let template = Template(name: "New Template", position: position)
        UserDataController.sharedController().addOrUpdateTemplate(template)
        updateData()
        let indexPath = NSIndexPath(forRow: position, inSection: 0)
        self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    // MARK: - Table View
    
    override func setEditing(editing: Bool, animated: Bool) {
        if editing {
            navigationItem.rightBarButtonItems?.append(orderItemsButton)
        } else if let index = navigationItem.rightBarButtonItems?.indexOf(orderItemsButton) {
            navigationItem.rightBarButtonItems?.removeAtIndex(index)
        }
        super.setEditing(editing, animated: animated)
    }
    
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath {
        return sourceIndexPath.section == proposedDestinationIndexPath.section ? proposedDestinationIndexPath : sourceIndexPath
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        let movedTemplate = sections[sourceIndexPath.section].templates.removeAtIndex(sourceIndexPath.row)
        sections[destinationIndexPath.section].templates.insert(movedTemplate, atIndex: destinationIndexPath.row)
        for section in sections {
            for (i, t) in section.templates.enumerate() {
                t.position = i
            }
            
            UserDataController.sharedController().updateTemplates(section.templates)
        }
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].templates.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].templates.count > 0 ? sections[section].title : nil
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) 
        let templates = sections[indexPath.section].templates
        cell.textLabel?.text = templates[indexPath.row].name
        cell.detailTextLabel?.text = daysStringFromTemplateDays(templates[indexPath.row].templateDays)
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let template = sections[indexPath.section].templates[indexPath.row]
        if editing {
            let alertController = UIAlertController(title: "Edit Title", message: nil, preferredStyle: .Alert)
            alertController.addTextFieldWithConfigurationHandler() { textField in
                textField.text = template.name
                textField.autocapitalizationType = .Words
                textField.clearButtonMode = UITextFieldViewMode.WhileEditing
            }
            alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            alertController.addAction(UIAlertAction(title: "Save", style: .Default, handler: { (_) -> Void in
                let textField = alertController.textFields!.first!
                template.name = textField.text!
                UserDataController.sharedController().addOrUpdateTemplate(template)
                self.updateData()
                self.tableView.reloadData()
            }))
            self .presentViewController(alertController, animated: true, completion: nil)
        } else {
            performSegueWithIdentifier("TemplateDetailSegue", sender: template)
        }
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            var templates = sections[indexPath.section].templates
            UserDataController.sharedController().removeTemplate(templates[indexPath.row])
            updateData()
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let destination = segue.destinationViewController as? TemplateViewController {
            destination.template = sender as! Template
        }
    }
    
    // MARK: - Private Functions
    
    func orderItems() {
        performSegueWithIdentifier("OrderItems", sender: nil)
    }
    
}
