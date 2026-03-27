import UIKit
@MainActor
public final class SAKeyboardManager: NSObject {
    
    public static let shared = SAKeyboardManager()
    
    public var enable: Bool = false {
        didSet {
            enable ? start() : stop()
        }
    }
    
    private override init() {}
    
    private weak var activeField: UIView?
    private var allFields: [UIView] = []
}

// MARK: - Start / Stop

extension SAKeyboardManager {
    
    private func start() {
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editingDidBegin),
            name: UITextField.textDidBeginEditingNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editingDidBegin),
            name: UITextView.textDidBeginEditingNotification,
            object: nil
        )
        
        registerKeyboardNotifications()
    }
    
    private func stop() {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Detect Active Field

extension SAKeyboardManager {
    
    @objc private func editingDidBegin(_ notification: Notification) {
        guard let view = notification.object as? UIView else { return }
        
        activeField = view
        attachToolbarIfNeeded(view)
        collectFields(in: view.window)
        
        updateToolbarTitle()
        adjustScroll()
    }
}

// MARK: - Collect Fields Automatically

extension SAKeyboardManager {
    
    private func collectFields(in root: UIView?) {
        guard let root = root else { return }
        
        let newFields = findAllTextInputs(in: root)
        
        if newFields.count != allFields.count {
            allFields = newFields
        }
    }
    
    private func findAllTextInputs(in view: UIView) -> [UIView] {
        var result: [UIView] = []
        
        if view is UITextField || view is UITextView {
            result.append(view)
        }
        
        for subview in view.subviews {
            result.append(contentsOf: findAllTextInputs(in: subview))
        }
        
        return result.sorted {
            let f1 = $0.convert($0.bounds, to: nil)
            let f2 = $1.convert($1.bounds, to: nil)
            return f1.minY < f2.minY
        }
    }
}

// MARK: - Find ScrollView Automatically

extension SAKeyboardManager {
    
    private func findScrollView(from view: UIView?) -> UIScrollView? {
        var current = view
        
        while current != nil {
            if let scroll = current as? UIScrollView {
                return scroll
            }
            current = current?.superview
        }
        
        return nil
    }
}

// MARK: - Keyboard Handling

extension SAKeyboardManager {
    
    private func registerKeyboardNotifications() {
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        
        guard let field = activeField,
              let scrollView = findScrollView(from: field),
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        scrollView.contentInset.bottom = frame.height
        scrollView.verticalScrollIndicatorInsets.bottom = frame.height
        
        adjustScroll()
    }
    
    @objc private func keyboardWillHide() {
        
        guard let field = activeField,
              let scrollView = findScrollView(from: field) else { return }
        
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}

// MARK: - 🔥 Scroll Fix (Forward + Backward)

extension SAKeyboardManager {
    
    private func adjustScroll() {
        
        guard let field = activeField,
              let scrollView = findScrollView(from: field) else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            
            let frame = field.convert(field.bounds, to: scrollView)
            
            let visibleHeight = scrollView.frame.height - scrollView.contentInset.bottom
            
            let padding: CGFloat = 20

            let targetY = max(
                frame.origin.y - padding,
                -scrollView.contentInset.top
            )
            
            scrollView.setContentOffset(
                CGPoint(x: 0, y: targetY),
                animated: true
            )
        }
    }
}

// MARK: - Toolbar (Auto Attach)

extension SAKeyboardManager {
    
    private func attachToolbarIfNeeded(_ view: UIView) {
        
        if let tf = view as? UITextField, tf.inputAccessoryView == nil {
            tf.inputAccessoryView = createToolbar()
        }
        
        if let tv = view as? UITextView, tv.inputAccessoryView == nil {
            tv.inputAccessoryView = createToolbar()
        }
    }
    
    private func createToolbar() -> UIToolbar {
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let prev = UIBarButtonItem(
            image: UIImage(systemName: "chevron.up"),
            style: .plain,
            target: self,
            action: #selector(previousTapped)
        )
        
        let next = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down"),
            style: .plain,
            target: self,
            action: #selector(nextTapped)
        )
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        
        let titleItem = UIBarButtonItem(customView: titleLabel)
        
        let flexible = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )
        
        let done = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        toolbar.items = [prev, next, flexible, titleItem, flexible, done]
        
        return toolbar
    }
    
    private func updateToolbarTitle() {
        
        guard let field = activeField,
              let toolbar = (field as? UITextField)?.inputAccessoryView as? UIToolbar
                ?? (field as? UITextView)?.inputAccessoryView as? UIToolbar
        else { return }
        
        let placeholder: String?
        
        if let tf = field as? UITextField {
            placeholder = tf.placeholder
        } else if let tv = field as? UITextView {
            placeholder = tv.text.isEmpty ? "Input" : nil
        } else {
            placeholder = nil
        }
        
        if let labelItem = toolbar.items?.compactMap({ $0.customView as? UILabel }).first {
            labelItem.text = placeholder ?? ""
            labelItem.sizeToFit()
        }
    }
}

// MARK: - Navigation (Prev / Next Fix)

extension SAKeyboardManager {
    
    @objc private func previousTapped() {
        move(offset: -1)
    }
    
    @objc private func nextTapped() {
        move(offset: 1)
    }
    
    @objc private func doneTapped() {
        activeField?.resignFirstResponder()
    }
    
    private func move(offset: Int) {
        
        guard let current = activeField,
              let index = allFields.firstIndex(where: { $0 === current }) else { return }
        
        let newIndex = index + offset
        
        guard newIndex >= 0, newIndex < allFields.count else { return }
        
        let nextField = allFields[newIndex]
        nextField.becomeFirstResponder()
        
        activeField = nextField
        updateToolbarTitle()
        adjustScroll() // 🔥 fixes reverse scroll
    }
}
