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
        resetState()
    }
}

// MARK: - Reset

extension SAKeyboardManager {
    
    private func resetState() {
        activeField = nil
        allFields.removeAll()
    }
}

// MARK: - Detect Active Field

extension SAKeyboardManager {
    
    @objc private func editingDidBegin(_ notification: Notification) {
        guard let view = notification.object as? UIView else { return }
        
        activeField = view
        
        attachToolbar(view) // 🔥 ALWAYS attach fresh toolbar
        collectFields(in: view.window)
        
        adjustScroll()
    }
}

// MARK: - Collect Fields

extension SAKeyboardManager {
    
    private func collectFields(in root: UIView?) {
        guard let root = root else { return }
        
        allFields = findAllTextInputs(in: root) // 🔥 always refresh
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

// MARK: - ScrollView Finder

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
        
        resetState() // 🔥 VERY IMPORTANT
    }
}

// MARK: - Scroll Logic (FIXED)

extension SAKeyboardManager {
    
    private func adjustScroll() {
        
        guard let field = activeField,
              let scrollView = findScrollView(from: field) else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            
            let frame = field.convert(field.bounds, to: scrollView)
            
            let visibleTop = scrollView.contentOffset.y
            let visibleBottom = visibleTop + scrollView.frame.height - scrollView.contentInset.bottom
            
            let fieldTop = frame.minY
            let fieldBottom = frame.maxY
            
            var offsetY = scrollView.contentOffset.y
            
            let padding: CGFloat = 20
            
            if fieldBottom > visibleBottom {
                offsetY = fieldBottom - scrollView.frame.height + scrollView.contentInset.bottom + padding
            } else if fieldTop < visibleTop {
                offsetY = fieldTop - padding
            }
            
            scrollView.setContentOffset(
                CGPoint(x: 0, y: max(offsetY, -scrollView.contentInset.top)),
                animated: true
            )
        }
    }
}

// MARK: - Toolbar (FIXED)

extension SAKeyboardManager {
    
    private func attachToolbar(_ view: UIView) {
        
        let toolbar = createToolbar(for: view)
        
        if let tf = view as? UITextField {
            tf.inputAccessoryView = toolbar
        } else if let tv = view as? UITextView {
            tv.inputAccessoryView = toolbar
        }
    }
    
    private func createToolbar(for view: UIView) -> UIToolbar {
        
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
        
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        
        if let tf = view as? UITextField {
            label.text = tf.placeholder ?? ""
        } else if let tv = view as? UITextView {
            label.text = tv.text.isEmpty ? "Input" : ""
        }
        
        label.sizeToFit()
        
        let titleItem = UIBarButtonItem(customView: label)
        
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
}

// MARK: - Navigation (FIXED)

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
        
        guard let current = activeField else { return }
        
        // 🔥 Recollect every time (fix stale issue)
        collectFields(in: current.window)
        
        guard let index = allFields.firstIndex(where: { $0 === current }) else { return }
        
        let newIndex = index + offset
        
        guard newIndex >= 0, newIndex < allFields.count else { return }
        
        let nextField = allFields[newIndex]
        
        attachToolbar(nextField) // 🔥 important
        nextField.becomeFirstResponder()
        
        activeField = nextField
        adjustScroll()
    }
}
