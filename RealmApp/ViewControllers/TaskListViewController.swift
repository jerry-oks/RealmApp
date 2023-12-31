//
//  TaskListsViewController.swift
//  RealmApp
//
//  Created by Alexey Efimov on 02.07.2018.
//  Copyright © 2018 Alexey Efimov. All rights reserved.
//

import UIKit
import RealmSwift

final class TaskListViewController: UITableViewController {
    
    @IBOutlet private var segmentedControl: UISegmentedControl!
    
    private var taskLists: Results<TaskList>!
    private let storageManager = StorageManager.shared
    private let dataManager = DataManager.shared
    private let userDefaults = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonPressed)
        )
        
        navigationItem.rightBarButtonItem = addButton
        navigationItem.leftBarButtonItem = editButtonItem
        
        createTempData()
        taskLists = storageManager.fetchData(TaskList.self)
        segmentedControl.selectedSegmentIndex = userDefaults.integer(forKey: "sorting")
        sort(by: userDefaults.integer(forKey: "sorting"))
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        taskLists.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskListCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        let taskList = taskLists[indexPath.row]
        content.text = taskList.title
        
        let taskListIsNotEmpty = !taskList.tasks.isEmpty
        let activeTaskListIsEmpty = taskList.tasks.filter { !$0.isComplete } .isEmpty
        let activeTasksCount = taskList.tasks.filter { !$0.isComplete } .count.formatted()
        content.secondaryText = taskListIsNotEmpty && activeTaskListIsEmpty
        ? "✓"
        : activeTasksCount
        content.secondaryTextProperties.color = taskListIsNotEmpty && activeTaskListIsEmpty
        ? #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        : #colorLiteral(red: 0.6642268896, green: 0.6642268896, blue: 0.6642268896, alpha: 1)
        
        cell.contentConfiguration = content
        return cell
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let taskList = taskLists[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "") { [unowned self] _, _, _ in
            storageManager.delete(taskList)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        
        let editAction = UIContextualAction(style: .normal, title: "") { [unowned self] _, _, isDone in
            showAlert(with: taskList) {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
            isDone(true)
        }
        
        deleteAction.image = UIImage(systemName: "trash")
        editAction.image = UIImage(systemName: "text.cursor")
        editAction.backgroundColor = #colorLiteral(red: 1, green: 0.6235294118, blue: 0.03921568627, alpha: 1)
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let taskList = taskLists[indexPath.row]

        let doneAction = UIContextualAction(style: .normal, title: "") { [unowned self] _, _, isDone in
            storageManager.done(taskList)
            tableView.reconfigureRows(at: [indexPath])
            isDone(true)
        }
        
        doneAction.image = UIImage(systemName: "checkmark")
        doneAction.backgroundColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        
        return UISwipeActionsConfiguration(actions: [doneAction])
    }
        
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let indexPath = tableView.indexPathForSelectedRow else { return }
        guard let tasksVC = segue.destination as? TasksViewController else { return }
        let taskList = taskLists[indexPath.row]
        tasksVC.taskList = taskList
    }
    
    @IBAction func sortList(_ sender: UISegmentedControl) {
        sort(by: sender.selectedSegmentIndex)
        userDefaults.set(sender.selectedSegmentIndex, forKey: "sorting")
        UIView.transition(
            with: tableView,
            duration: 0.15,
            options: [.transitionCrossDissolve, .curveEaseInOut]
        ) { [unowned self] in
            tableView.reloadData()
        }
    }
    
    @objc private func addButtonPressed() {
        showAlert()
    }
    
    private func createTempData() {
        if !UserDefaults.standard.bool(forKey: "done") {
            dataManager.createTempData { [unowned self] in
                UserDefaults.standard.setValue(true, forKey: "done")
                tableView.reloadData()
            }
        }
    }
    
    private func sort(by key: Int) {
        taskLists = taskLists.sorted(
            byKeyPath: key == 1 ? "title" : "date",
            ascending: key == 1 ? true : false
        )
    }
}

// MARK: - AlertController
extension TaskListViewController {
    private func showAlert(with taskList: TaskList? = nil, completion: (() -> Void)? = nil) {
        let alertBuilder = AlertControllerBuilder(
            title: taskList != nil ? "Edit List" : "New List",
            message: "Please set title for new task list"
        )
        
        alertBuilder
            .setTextField(withPlaceholder: "List Title", andText: taskList?.title)
            .addAction(title: taskList != nil ? "Update List" : "Save List", style: .default) { [weak self] newValue, _ in
                if let taskList, let completion {
                    self?.storageManager.edit(taskList, newValue: newValue)
                    completion()
                    return
                }
                
                self?.save(taskList: newValue)
            }
            .addAction(title: "Cancel", style: .destructive)
        
        let alertController = alertBuilder.build()
        present(alertController, animated: true)
    }
    
    private func save(taskList: String) {
        storageManager.save(taskList) { taskList in
            let rowIndex = IndexPath(row: taskLists.index(of: taskList) ?? 0, section: 0)
            tableView.insertRows(at: [rowIndex], with: .automatic)
        }
    }
}
