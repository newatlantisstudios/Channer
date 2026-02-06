import UIKit

class CatalystNavigationController: UINavigationController {

    #if targetEnvironment(macCatalyst)
    private var mouseMonitor: AnyObject?
    private var hasHandledSwipeBack = false
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        #if targetEnvironment(macCatalyst)
        setupMouseBackButton()
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func setupMouseBackButton() {
        guard let nsEventClass = NSClassFromString("NSEvent") else {
            print("DEBUG MOUSE: NSEvent class not found")
            return
        }
        print("DEBUG MOUSE: NSEvent class found")

        // NSEventMaskSwipe = 1 << 31
        let mask: UInt64 = 1 << 31

        let handler: @convention(block) (AnyObject) -> AnyObject? = { [weak self] event in
            let deltaX = event.value(forKey: "deltaX") as? CGFloat ?? 0
            let deltaY = event.value(forKey: "deltaY") as? CGFloat ?? 0
            print("DEBUG MOUSE SWIPE: deltaX=\(deltaX) deltaY=\(deltaY)")

            // Swipe right (deltaX > 0) = navigate back
            // Swipe left (deltaX < 0) = navigate forward
            // Use a flag to only handle once per gesture
            if deltaX != 0 {
                if deltaX > 0, self?.hasHandledSwipeBack == false {
                    self?.hasHandledSwipeBack = true
                    print("DEBUG MOUSE: Back swipe detected! Popping view controller.")
                    DispatchQueue.main.async {
                        if (self?.viewControllers.count ?? 0) > 1 {
                            self?.popViewController(animated: true)
                        }
                        // Reset flag after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.hasHandledSwipeBack = false
                        }
                    }
                    return nil
                }
            }
            return event
        }

        let sel = NSSelectorFromString("addLocalMonitorForEventsMatchingMask:handler:")
        guard let msgSendPtr = dlsym(dlopen(nil, RTLD_LAZY), "objc_msgSend") else {
            print("DEBUG MOUSE: Could not get objc_msgSend")
            return
        }

        typealias MsgSendType = @convention(c) (AnyObject, Selector, UInt64, Any) -> AnyObject?
        let msgSend = unsafeBitCast(msgSendPtr, to: MsgSendType.self)

        mouseMonitor = msgSend(nsEventClass, sel, mask, handler)
        print("DEBUG MOUSE: Swipe monitor installed, mouseMonitor=\(mouseMonitor != nil ? "set" : "nil")")
    }

    deinit {
        if let monitor = mouseMonitor {
            guard let nsEventClass = NSClassFromString("NSEvent") else { return }
            let sel = NSSelectorFromString("removeMonitor:")
            guard let msgSendPtr = dlsym(dlopen(nil, RTLD_LAZY), "objc_msgSend") else { return }

            typealias MsgSendType = @convention(c) (AnyObject, Selector, AnyObject) -> Void
            let msgSend = unsafeBitCast(msgSendPtr, to: MsgSendType.self)

            msgSend(nsEventClass, sel, monitor)
        }
    }
    #endif
}
