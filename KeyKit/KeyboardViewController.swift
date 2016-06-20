//
//  KeyboardViewController.swift
//  KeyKit
//
//  Created by Dima Bart on 2016-01-27.
//  Copyright © 2016 Dima Bart. All rights reserved.
//

import UIKit

public protocol KeyboardDelegate: class {
    func keyboardViewController(controller: KeyboardViewController, didReceiveInputFrom key: Key)
    func keyboardViewController(controller: KeyboardViewController, didInputCharacter character: String)
    func keyboardViewController(controller: KeyboardViewController, didBackspaceLength length: Int)
    
    func keyboardViewControllerDidReturn(controller: KeyboardViewController)
    func keyboardViewControllerDidRequestNextKeyboard(controller: KeyboardViewController)
}

public class KeyboardViewController: UIViewController {
    
    public weak var delegate:      KeyboardDelegate?
    public weak var documentProxy: UITextDocumentProxy? {
        didSet {
            self.updateStateForCurrentInsertionPointIn(self.documentProxy)
        }
    }
    
    public var usePeriodShortcut = true
    public var allowCapsLock     = false
    
    private var keyboardView: KeyboardView!
    private var faces:        [String : Face] = [:]
    
    private var shiftKeys:         [KeyView] = []
    private var shiftEnabled:      Bool = false
    private var capsLockEnabled:   Bool = false
    private var lastInsertedSpace: Bool = false
    private var insertedShortcut:  Bool = false

    // ----------------------------------
    //  MARK: - Init -
    //
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    // ----------------------------------
    //  MARK: - View Loading -
    //
    public override func loadView() {
        super.loadView()
        
        self.keyboardView                  = KeyboardView(faceView: nil)
        self.keyboardView.frame            = self.view.bounds
        self.keyboardView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.keyboardView.backgroundColor  = UIColor.lightGrayColor()
        
        self.changeFaceTo(Identifier.Letters, inProxy: self.documentProxy)
        
        self.view.addSubview(self.keyboardView)
    }
    
    // ----------------------------------
    //  MARK: - Face Management -
    //
    private func faceFor(identifier: String) -> Face {
        if let face = self.faces[identifier] {
            return face
            
        } else {
            
            let face: Face
            switch identifier {
            case Identifier.Letters:
                face = Face.lettersFace()
            case Identifier.Numbers:
                face = Face.numbersFace()
            case Identifier.Characters:
                face = Face.charactersFace()
            default:
                fatalError("Unable to create face with identifier: \(identifier)")
            }
            
            self.faces[identifier] = face
            return face
        }
    }
    
    private func faceViewFor(face: Face) -> FaceView {
        return FaceView(face: face, targetable: self)
    }
    
    // ----------------------------------
    //  MARK: - Shift State -
    //
    private func referenceShiftKeys() {
        self.shiftKeys = self.keyboardView.keyViewsMatching { (key) -> Bool in
            if case .Action(.Shift) = key.value {
                return true
            }
            return false
        }
    }
    
    private func setShiftEnabled(enabled: Bool) {
        self.shiftEnabled = enabled
        for keyView in self.shiftKeys {
            keyView.setTrackingState(enabled ? .Selected : .Normal)
        }
    }
    
    // ----------------------------------
    //  MARK: - Updates -
    //
    private func updateStateForCurrentInsertionPointIn(proxy: UITextDocumentProxy?) {
        if let proxy = proxy {
            
            let content = proxy.documentContextBeforeInput ?? ""
            if content.characters.count < 1 {
                self.setShiftEnabled(true)
            }
        }
    }
    
    // ----------------------------------
    //  MARK: - Actions -
    //
    private func changeFaceTo(identifier: String, inProxy proxy: UITextDocumentProxy?) {
        let face = self.faceFor(identifier)
        self.keyboardView.setFaceView(self.faceViewFor(face))
        
        self.referenceShiftKeys()
        self.updateStateForCurrentInsertionPointIn(proxy)
    }
    
    private func processInsertion(character: String, withProxy proxy: UITextDocumentProxy?) {
        if let proxy = proxy {
            
            switch character {
            case " " where self.usePeriodShortcut:
                if !self.lastInsertedSpace {
                    self.lastInsertedSpace = true
                    
                } else if !self.insertedShortcut {
                    self.lastInsertedSpace = false
                    self.insertedShortcut  = true
                    
                    proxy.deleteBackward()
                    proxy.insertText(".")
                }
                proxy.insertText(character)
                
            default:
                var text = character
                if self.shiftEnabled {
                    text = character.capitalizedString
                }
                proxy.insertText(text)
                
                self.insertedShortcut  = false
                self.lastInsertedSpace = false
            }
        }
        
        /* ---------------------------------
         ** Disable shift key after each key
         ** press, unless we're in caps lock
         ** mode.
         */
        if self.shiftEnabled && !self.capsLockEnabled {
            self.setShiftEnabled(false)
        }
        
        print("\(character)", terminator: "")
    }
    
    private func processBackspaceIn(proxy: UITextDocumentProxy?) {
        proxy?.deleteBackward()
    }
}

// ----------------------------------
//  MARK: - KeyTargetable -
//
extension KeyboardViewController: KeyTargetable {
    
    public func keyReceivedAction(keyView: KeyView) {
        self.delegate?.keyboardViewController(self, didReceiveInputFrom: keyView.key)
        
        switch keyView.key.value {
        case .Action(let action):
            print("\nAction from: \(action)")
            
            switch action {
            case .Globe:
                self.delegate?.keyboardViewControllerDidRequestNextKeyboard(self)
                
            case .Backspace:
                self.processBackspaceIn(self.documentProxy)
                self.updateStateForCurrentInsertionPointIn(self.documentProxy)
                
                self.delegate?.keyboardViewController(self, didBackspaceLength: 1)
                
            case .ChangeFace(let identifier):
                self.changeFaceTo(identifier, inProxy: self.documentProxy)
                
            case .Shift:
                self.setShiftEnabled(!self.shiftEnabled)
                
            case .Return:
                self.processInsertion("\n", withProxy: self.documentProxy)
                self.updateStateForCurrentInsertionPointIn(self.documentProxy)
                
                self.delegate?.keyboardViewControllerDidReturn(self)
            }
            
        case .Char(let character):
            self.processInsertion(character, withProxy: self.documentProxy)
            self.updateStateForCurrentInsertionPointIn(self.documentProxy)
        }
    }
    
    public func key(keyView: KeyView, changeTrackingState tracking: Bool) {
        
    }
}
