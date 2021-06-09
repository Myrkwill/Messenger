import UIKit
import MessageKit

struct Message: MessageType {
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
}

struct Sender: SenderType {
    var photoURL: String
    var senderId: String
    var displayName: String
}

class ChatViewController: MessagesViewController {
    
    private var messages = [Message]()
    private var sender = Sender(photoURL: "", senderId: "1", displayName: "Mary Smith")

    override func viewDidLoad() {
        super.viewDidLoad()

        messages.append(Message(sender: sender, messageId: "1", sentDate: Date(), kind: .text("Hi! How are you?")))
        messages.append(Message(sender: sender, messageId: "1", sentDate: Date(), kind: .text("Hi! How are you? Hi! How are you? Hi! How are you? Hi! How are you? Hi! How are you? Hi! How are you? Hi! How are you? Hi! How are you? Hi! How are you?")))
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
    }

}

extension ChatViewController: MessagesLayoutDelegate, MessagesDisplayDelegate, MessagesDataSource {
    
    func currentSender() -> SenderType {
        sender
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        messages.count
    }
    
}
