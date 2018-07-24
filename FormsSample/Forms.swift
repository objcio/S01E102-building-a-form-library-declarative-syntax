//
//  Forms.swift
//  FormsSample
//
//  Created by Chris Eidhof on 26.03.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

class Section {
    let cells: [FormCell]
    var footerTitle: String?
    init(cells: [FormCell], footerTitle: String?) {
        self.cells = cells
        self.footerTitle = footerTitle
    }
}

class FormCell: UITableViewCell {
    var shouldHighlight = false
    var didSelect: (() -> ())?
}

class FormViewController: UITableViewController {
    var sections: [Section] = []
    var firstResponder: UIResponder?
    
    func reloadSectionFooters() {
        UIView.setAnimationsEnabled(false)
        tableView.beginUpdates()
        for index in sections.indices {
            let footer = tableView.footerView(forSection: index)
            footer?.textLabel?.text = tableView(tableView, titleForFooterInSection: index)
            footer?.setNeedsLayout()
            
        }
        tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }
    
    
    init(sections: [Section], title: String, firstResponder: UIResponder? = nil) {
        self.firstResponder = firstResponder
        self.sections = sections
        super.init(style: .grouped)
        navigationItem.title = title
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        firstResponder?.becomeFirstResponder()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }
    
    
    
    func cell(for indexPath: IndexPath) -> FormCell {
        return sections[indexPath.section].cells[indexPath.row]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cell(for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return cell(for: indexPath).shouldHighlight
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        cell(for: indexPath).didSelect?()
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}

class KeyboardLikeViewController: UIViewController {
    var contentView: UIView = UIView()
    
    init(view: UIView) {
        super.init(nibName: nil, bundle: nil)
        self.contentView = view
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        let toolbar = UIToolbar()
        toolbar.items = [UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done(_:)))]
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView(arrangedSubviews: [
            toolbar,
            contentView
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        view.addSubview(stack)
        contentView.backgroundColor = .white
        view.addConstraints([
            view.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
            view.leftAnchor.constraint(equalTo: stack.leftAnchor),
            view.rightAnchor.constraint(equalTo: stack.rightAnchor)
        ])
    }
    
    @objc func done(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

class FormDriver<State> {
    var formViewController: FormViewController!
    var rendered: RenderedElement<[Section], State>!
    
    var state: State {
        didSet {
            rendered.update(state)
            formViewController.reloadSectionFooters()
        }
    }
    
    init(initial state: State, build: (RenderingContext<State>) -> RenderedElement<[Section], State>) {
        self.state = state
        let context = RenderingContext(state: state, change: { [unowned self] f in
            f(&self.state)
        }, pushViewController: { [unowned self] vc in
            if vc.modalPresentationStyle == .none {
                self.formViewController.navigationController?.pushViewController(vc, animated: true)
            } else {
                self.formViewController.navigationController?.present(vc, animated: true)
            }
        }, popViewController: {
                self.formViewController.navigationController?.popViewController(animated: true)
        })
        self.rendered = build(context)
        rendered.update(state)
        formViewController = FormViewController(sections: rendered.element, title: "Personal Hotspot Settings")
    }
}

final class TargetAction {
    let execute: () -> ()
    init(_ execute: @escaping () -> ()) {
        self.execute = execute
    }
    @objc func action(_ sender: Any) {
        execute()
    }
}

struct RenderedElement<Element, State> {
    var element: Element
    var strongReferences: [Any]
    var update: (State) -> ()
}

struct RenderingContext<State> {
    let state: State
    let change: ((inout State) -> ()) -> ()
    let pushViewController: (UIViewController) -> ()
    let popViewController: () -> ()
}

func uiSwitch<State>(keyPath: WritableKeyPath<State, Bool>) -> Rendered<State, UIView> {
    return { context in
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        let toggleTarget = TargetAction {
            context.change { $0[keyPath: keyPath] = toggle.isOn }
        }
        toggle.addTarget(toggleTarget, action: #selector(TargetAction.action(_:)), for: .valueChanged)
        return RenderedElement(element: toggle, strongReferences: [toggleTarget], update: { state in
            toggle.isOn = state[keyPath: keyPath]
        })
    }
}

func textField<State>(keyPath: WritableKeyPath<State, String>) -> Rendered<State, UIView> {
    return { context in
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        let didEnd = TargetAction {
            context.change { $0[keyPath: keyPath] = textField.text ?? "" }
        }
        let didExit = TargetAction {
            context.change { $0[keyPath: keyPath] = textField.text ?? "" }
            context.popViewController()
        }
        
        textField.addTarget(didEnd, action: #selector(TargetAction.action(_:)), for: .editingDidEnd)
        textField.addTarget(didExit, action: #selector(TargetAction.action(_:)), for: .editingDidEndOnExit)
        return RenderedElement(element: textField, strongReferences: [didEnd, didExit], update: { state in
            textField.text = state[keyPath: keyPath]
        })
    }
}

func datePicker<State>(keyPath: WritableKeyPath<State, Date>) -> Rendered<State, UIView> {
    return { context in
        let picker = UIDatePicker()
        picker.translatesAutoresizingMaskIntoConstraints = false
        let valueChanged = TargetAction {
            context.change { $0[keyPath: keyPath] = picker.date }
        }
        picker.addTarget(valueChanged, action: #selector(TargetAction.action(_:)), for: .valueChanged)
        return RenderedElement(element: picker, strongReferences: [valueChanged], update: { state in
            picker.date = state[keyPath: keyPath]
        })
    }
}

func controlCell<State>(title: String, control: @escaping Rendered<State, UIView>, leftAligned: Bool = false) -> Rendered<State, FormCell> {
    return { context in
        let cell = FormCell(style: .value1, reuseIdentifier: nil)
        let renderedControl = control(context)
        cell.textLabel?.text = title
        cell.contentView.addSubview(renderedControl.element)
        cell.contentView.addConstraints([
            renderedControl.element.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            renderedControl.element.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor)
            ])
        if leftAligned {
            cell.contentView.addConstraint(
                renderedControl.element.leadingAnchor.constraint(equalTo: cell.textLabel!.trailingAnchor, constant: 20))
        }
        return RenderedElement(element: cell, strongReferences: renderedControl.strongReferences, update: renderedControl.update)
    }
}

func detailTextCell<State>(title: String, keyPath: KeyPath<State, String>, form: @escaping Form<State>) -> Rendered<State, FormCell> {
    return { context in
        let cell = FormCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = title
        cell.accessoryType = .disclosureIndicator
        cell.shouldHighlight = true
        let rendered = form(context)
        let nested = FormViewController(sections: rendered.element, title: title)
        cell.didSelect = {
            context.pushViewController(nested)
        }
        return RenderedElement(element: cell, strongReferences: rendered.strongReferences, update: { state in
            cell.detailTextLabel?.text = state[keyPath: keyPath]
            rendered.update(state)
        })
    }
}

func modalDetailCell<State>(title: String, keyPath: KeyPath<State, String>, element: @escaping Rendered<State, UIView>) -> Rendered<State, FormCell> {
    return { context in
        let cell = FormCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = title
        cell.accessoryType = .disclosureIndicator
        cell.shouldHighlight = true
        let rendered = element(context)
        let nested = KeyboardLikeViewController(view: rendered.element)
        nested.modalPresentationStyle = .overFullScreen
        cell.didSelect = {
            context.pushViewController(nested)
        }
        return RenderedElement(element: cell, strongReferences: rendered.strongReferences, update: { state in
            cell.detailTextLabel?.text = state[keyPath: keyPath]
            rendered.update(state)
        })
    }
}


func section<State>(_ cells: [Rendered<State, FormCell>], footer keyPath: KeyPath<State, String?>? = nil) -> RenderedSection<State> {
    return { context in
        let renderedCells = cells.map { $0(context) }
        let strongReferences = renderedCells.flatMap { $0.strongReferences }
        let section = Section(cells: renderedCells.map { $0.element }, footerTitle: nil)
        let update: (State) -> () = { state in
            for c in renderedCells {
                c.update(state)
            }
            if let kp = keyPath {
                section.footerTitle = state[keyPath: kp]
            }
        }
        return RenderedElement(element: section, strongReferences: strongReferences, update: update)
    }
}

// todo DRY
func sections<State>(_ sections: [RenderedSection<State>]) -> Form<State> {
    return { context in
        let renderedSections = sections.map { $0(context) }
        let strongReferences = renderedSections.flatMap { $0.strongReferences }
        let update: (State) -> () = { state in
            for c in renderedSections {
                c.update(state)
            }
        }
        return RenderedElement(element: renderedSections.map { $0.element }, strongReferences: strongReferences, update: update)
    }
}

// todo think of name
typealias Rendered<A, Element> = (RenderingContext<A>) -> RenderedElement<Element, A>
typealias Form<A> = Rendered<A, [Section]>
typealias RenderedSection<A> = Rendered<A, Section>
