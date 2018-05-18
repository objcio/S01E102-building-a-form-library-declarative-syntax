//
//  ViewController.swift
//  FormsSample
//
//  Created by Chris Eidhof on 22.03.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

struct Hotspot {
    var isEnabled: Bool = true
    var password: String = "hello"
}

extension Hotspot {
    var enabledSectionTitle: String? {
        return isEnabled ? "Personal Hotspot Enabled" : nil
    }
}

let hotspotForm: Form<Hotspot> =
    sections([
        section([
            controlCell(title: "Personal Hotspot", control: uiSwitch(keyPath: \.isEnabled))
        ], footer: \.enabledSectionTitle),
        section([
            detailTextCell(title: "Password", keyPath: \.password, form: buildPasswordForm)
        ])
    ])

let buildPasswordForm: Form<Hotspot> =
    sections([section([controlCell(title: "Password", control: textField(keyPath: \.password), leftAligned: true)])])
