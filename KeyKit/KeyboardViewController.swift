//
//  KeyboardViewController.swift
//  KeyKit
//
//  Created by Dima Bart on 2016-01-27.
//  Copyright © 2016 Dima Bart. All rights reserved.
//

import UIKit

public protocol KeyboardDelegate: class {
    func keyboardViewControllerDidRequestNextKeyboard(controller: KeyboardViewController)
    
    func keyboardViewController(controller: KeyboardViewController, didReceiveInputFrom key: Key)
    func keyboardViewController(controller: KeyboardViewController, didInputCharacter character: String)
    func keyboardViewController(controller: KeyboardViewController, didBackspaceLength length: Int)
    
    func keyboardViewControllerDidReturn(controller: KeyboardViewController)
}

public class KeyboardViewController: UIViewController {
    
    public weak var delegate:      KeyboardDelegate?
    public weak var documentProxy: UITextDocumentProxy? {
        didSet {
            self.updateShiftStateIn(self.documentProxy)
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
    //  MARK: - Text Actions -
    //
    public func textWillChange(input: UITextInput?) {
        
    }
    
    public func textDidChange(input: UITextInput?) {
        
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
    private func updateShiftStateIn(proxy: UITextDocumentProxy?) {
        if let proxy = proxy {
            
            /* ---------------------------------
             ** Check the shift state and enable
             ** all the keys in case the faces
             ** have changed, etc.
             */
            if self.shiftEnabled {
                self.setShiftEnabled(true)
                
            } else {
                let content = proxy.documentContextBeforeInput ?? ""
                var enable  = false
                
                if content == "" {
                    enable = true
                } else {
                    enable = content.suffix(2) == ". "
                }
                
                self.setShiftEnabled(enable)
            }
        }
    }
    
    // ----------------------------------
    //  MARK: - Actions -
    //
    public func simulate(action: Key.Action) {
        self.handle(.Action(action), forKey: nil)
    }
    
    private func handle(value: Key.Value, forKey key: Key?) {
        if let key = key {
            self.delegate?.keyboardViewController(self, didReceiveInputFrom: key)
        }
        
        switch value {
        case .Action(let action):
            print("\nAction from: \(action)")
            
            switch action {
            case .Globe:
                self.delegate?.keyboardViewControllerDidRequestNextKeyboard(self)
                
            case .Backspace:
                self.processBackspaceIn(self.documentProxy)
                
                self.delegate?.keyboardViewController(self, didBackspaceLength: 1)
                
            case .ChangeFace(let identifier):
                self.changeFaceTo(identifier, inProxy: self.documentProxy)
                
            case .Shift:
                self.setShiftEnabled(!self.shiftEnabled)
                
            case .Return:
                self.handle(.Char("\n"), forKey: nil)
                self.delegate?.keyboardViewControllerDidReturn(self)
            }
            
        case .Char(let character):
            self.processInsertion(character, withProxy: self.documentProxy)
        }
    }
    
    private func changeFaceTo(identifier: String, inProxy proxy: UITextDocumentProxy?) {
        let face = self.faceFor(identifier)
        self.keyboardView.setFaceView(self.faceViewFor(face))
        
        self.referenceShiftKeys()
        self.updateShiftStateIn(proxy)
    }
    
    private func processInsertion(character: String, withProxy proxy: UITextDocumentProxy?) {
        
        /* ---------------------------------
         ** If a proxy is provided, we need
         ** to handle the entered key events
         ** appropriately.
         */
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
                
                /* ---------------------------------
                 ** Disable shift key after each key
                 ** press, unless we're in caps lock
                 ** mode.
                 */
                if self.shiftEnabled && !self.capsLockEnabled {
                    self.handle(.Action(.Shift), forKey: nil)
                }
                
                /* -----------------------------------
                 ** Return to keyboard if the inserted
                 ** char is an apostrophe.
                 */
                if text == "'" {
                    self.handle(.Action(.ChangeFace(Identifier.Letters)), forKey: nil)
                }
            }
        }
        
        self.updateShiftStateIn(proxy)
        print("\(character)", terminator: "")
    }
    
    private func processBackspaceIn(proxy: UITextDocumentProxy?) {
        proxy?.deleteBackward()
        
        self.insertedShortcut  = false
        self.lastInsertedSpace = false
        
        self.updateShiftStateIn(proxy)
    }
}

// ----------------------------------
//  MARK: - KeyTargetable -
//
extension KeyboardViewController: KeyTargetable {
    
    public func keyReceivedAction(keyView: KeyView) {
        self.handle(keyView.key.value, forKey: keyView.key)
    }
    
    public func key(keyView: KeyView, didChangeTrackingState tracking: Bool) {
        if tracking {
            Click.play()
        }
    }
}

// ----------------------------------
//  MARK: - String -
//
private extension String {
    func suffix(length: Int) -> String {
        return String(self.characters.suffix(length))
    }
}
