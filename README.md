# SAKeyboardManager
Lightweight, zero-configuration keyboard manager for iOS. Automatically handles keyboard avoidance, scrolling, and input navigation without requiring manual setup.

No need to:

Pass UIScrollView
Manage UITextField arrays
Write keyboard handling code per screen

✨ Features
✅ Automatic keyboard handling
✅ Detects UITextField & UITextView automatically
✅ Works with UIScrollView, UITableView, UICollectionView
✅ Built-in toolbar (Previous / Next / Done)
✅ Smooth scrolling (forward + backward navigation)
✅ Fixes common IQKeyboardManager issues
✅ Zero per-screen setup
✅ Lightweight & easy to integrate


📱 Demo Behavior
Tap any input → auto scroll
Tap Next → moves forward
Tap Previous → moves backward (correctly!)
Keyboard hides → layout resets

📦 Installation (Swift Package Manager)
🔹 Add via Xcode
Go to File → Add Packages
Enter repository URL:
https://github.com/your-username/MiniKeyboardManager.git

🔹 Or add in Package.swift
dependencies: [
    .package(url: "", from: "1.0.0")
]

🛠 Usage
1. Import
import SAKeyboardManager


2. Enable (Only once)
SAKeyboardManager.shared.enable = true

👉 That’s it. No additional setup required.

⚙️ Requirements
iOS 13+
Swift 5.9+

