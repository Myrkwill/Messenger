import UIKit

extension UIAlertController {
    
    func addActions(_ actions: [UIAlertAction]) {
        for action in actions {
            self.addAction(action)
        }
    }
    
}
