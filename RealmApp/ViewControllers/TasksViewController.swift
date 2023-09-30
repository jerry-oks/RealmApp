//
//  TasksViewController.swift
//  RealmApp
//
//  Created by Alexey Efimov on 02.07.2018.
//  Copyright © 2018 Alexey Efimov. All rights reserved.
//

import UIKit
import RealmSwift

final class TasksViewController: UITableViewController {
    
    var taskList: TaskList!
    
    private var currentTasks: Results<Task>!
    private var completedTasks: Results<Task>!
    private let storageManager = StorageManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = taskList.title
        
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonPressed)
        )
        navigationItem.rightBarButtonItems = [addButton, editButtonItem]
        
        currentTasks = taskList.tasks.filter("isComplete = false")
        completedTasks = taskList.tasks.filter("isComplete = true")
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? currentTasks.count : completedTasks.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "CURRENT TASKS" : "COMPLETED TASKS"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TasksCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        let task = indexPath.section == 0 ? currentTasks[indexPath.row] : completedTasks[indexPath.row]
        content.text = task.title
        content.secondaryText = task.note
        cell.contentConfiguration = content
        return cell
    }
    
    @objc private func addButtonPressed() {
        showAlert()
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let task = indexPath.section == 0
        ? currentTasks[indexPath.row]
        : completedTasks [indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "") { [unowned self] _, _, _ in
            storageManager.delete(task)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        
        let editAction = UIContextualAction(style: .normal, title: "") { [unowned self] _, _, isDone in
            showAlert(with: task) {
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
        let task = indexPath.section == 0
        ? currentTasks[indexPath.row]
        : completedTasks [indexPath.row]
        
        let doneAction = UIContextualAction(style: .normal, title: "") { [unowned self] _, _, isDone in
            storageManager.doneToggle(task) { [unowned self] editedTask in
                let rowIndex = indexPath.section == 0
                ? self.completedTasks.index(of: editedTask) ?? 0
                : self.currentTasks.index(of: editedTask) ?? 0
                let sectionIndex = indexPath.section == 0 ? 1 : 0
                let toIndexPath = IndexPath(row: rowIndex, section: sectionIndex)
                
                tableView.moveRow(at: indexPath, to: toIndexPath)
            }
            isDone(true)
        }
        
        doneAction.backgroundColor = task.isComplete ? #colorLiteral(red: 1, green: 0.6235294118, blue: 0.03921568627, alpha: 1) : #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        doneAction.image = task.isComplete
        ? UIImage(systemName: "arrow.uturn.backward")
        : UIImage(systemName: "checkmark")

        return UISwipeActionsConfiguration(actions: [doneAction])
    }
    
}

extension TasksViewController {
    private func showAlert(with task: Task? = nil, completion: (() -> Void)? = nil) {
        let alertCB = AlertControllerBuilder(
            title: task != nil ? "Edit Task" : "New Task",
            message: "What do you want to do?"
        )
        let alert = alertCB
            .setTextField(withPlaceholder: "Task Title", andText: task?.title)
            .setTextField(withPlaceholder: "Note Title", andText: task?.note)
            .addAction(
                title: task != nil ? "Update Task" : "Save Task",
                style: .default
            ) { [unowned self] taskTitle, taskNote in
                if let task, let completion {
                    self.storageManager.edit(task, newTitle: taskTitle, newNote: taskNote)
                    completion()
                    return
                }
                self.save(task: taskTitle, withNote: taskNote)
            }
            .addAction(title: "Cancel", style: .destructive)
            .build()
        
        present(alert, animated: true)
    }
    
    private func save(task: String, withNote note: String) {
        storageManager.save(task, withNote: note, to: taskList) { task in
            let indexPath = IndexPath(row: currentTasks.index(of: task) ?? 0, section: 0)
            tableView.insertRows(at: [indexPath], with: .automatic)
        }
    }
}
