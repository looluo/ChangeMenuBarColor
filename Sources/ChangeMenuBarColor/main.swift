import Foundation

if AppMode.isGUI {
    MainActor.assumeIsolated {
        MenuBarApp.run()
    }
} else {
    ChangeMenuBarColor.main()
}
