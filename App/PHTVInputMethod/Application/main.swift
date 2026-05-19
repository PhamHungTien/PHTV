import Cocoa

let application = NSApplication.shared
let delegate = PHTVInputMethodApplicationDelegate()
application.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
