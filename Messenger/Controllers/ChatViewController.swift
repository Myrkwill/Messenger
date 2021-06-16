import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

final class ChatViewController: MessagesViewController {
    
    // DataFormatter
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()

    // Public
    public let otherUserEmail: String
    public var isNewConversation = false
    
    // Private
    private var senderPhotoURL: URL?
    private var otherUserPhotoURL: URL?
    private var conversationId: String?
    private var messages = [Message]()
    
    
    private var sender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "", senderId: safeEmail, displayName: "Me")
    }

    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red

        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, scrollToLastItem: true)
        }
    }

}

// MARK: Present Input Action Sheet
extension ChatViewController {
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }

    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(
            title: "Attach Media",
            message: "What would you like to attach?",
            preferredStyle: .actionSheet
        )
        
        let photoAlertAction = UIAlertAction(title: "Photo", style: .default) { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        }
        let videoAlertAction = UIAlertAction(title: "Video", style: .default) { [weak self]  _ in
            self?.presentVideoInputActionSheet()
        }
        let audioAlertAction = UIAlertAction(title: "Audio", style: .default) {  _ in }
        let locationAlertAction = UIAlertAction(title: "Location", style: .default) { [weak self]  _ in
            self?.presentLocationPicker()
        }
        
        actionSheet.addActions([photoAlertAction, videoAlertAction, audioAlertAction, locationAlertAction, .cancel])
        present(actionSheet, animated: true)
    }

    private func presentLocationPicker() {
        let viewController = LocationPickerViewController(coordinates: nil)
        viewController.title = "Pick Location"
        viewController.navigationItem.largeTitleDisplayMode = .never
        
        viewController.completion = { [weak self] selectedCoordinates in
            guard let self = self else { return }

            guard let messageId = self.createMessageId(),
                let conversationId = self.conversationId,
                let name = self.title,
                let sender = self.sender
            else {
                return
            }

            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude

            print("long=\(longitude) | lat= \(latitude)")

            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: .zero)
            let message = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .location(location))

            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: self.otherUserEmail, name: name, newMessage: message) { success in
                if success {
                    print("sent location message")
                } else {
                    print("failed to send location message")
                }
            }
        }
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(
            title: "Attach Photo",
            message: "Where would you like to attach a photo from",
            preferredStyle: .actionSheet
        )
        
        let cameraAlertAction = UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }
        
        let photoLibraryAlertAction = UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }
        
        actionSheet.addActions([cameraAlertAction, photoLibraryAlertAction, .cancel])
        present(actionSheet, animated: true)
    }

    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(
            title: "Attach Video",
            message: "Where would you like to attach a video from?",
            preferredStyle: .actionSheet
        )
        
        let cameraAlertAction = UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }
        
        let libraryAlertAction = UIAlertAction(title: "Library", style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            self?.present(picker, animated: true)
        }

        actionSheet.addActions([cameraAlertAction, libraryAlertAction, .cancel])
        present(actionSheet, animated: true)
    }

    private func listenForMessages(id: String, scrollToLastItem: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id) { [weak self] result in
            switch result {
            case .success(let messages):
                print("success in getting messages: \(messages)")
                guard !messages.isEmpty else {
                    print("messages are empty")
                    return
                }
                self?.messages = messages

                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()

                    if scrollToLastItem {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
            case .failure(let error):
                print("failed to get messages: \(error)")
            }
        }
    }

}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let messageId = createMessageId(),
            let conversationId = conversationId,
            let name = self.title,
            let sender = self.sender
        else {
            return
        }

        if let image = info[.editedImage] as? UIImage, let imageData =  image.pngData() {
            let fileName = StorageManager.fileName(forMessageId: messageId, fileExtension: .png)

            // Upload image

            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let urlString):
                    // Ready to send message
                    print("Uploaded Message Photo: \(urlString)")

                    guard let url = URL(string: urlString), let placeholder = UIImage(systemName: "plus") else {
                        return
                    }

                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .photo(media))

                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: self.otherUserEmail, name: name, newMessage: message) { success in

                        if success {
                            print("sent photo message")
                        } else {
                            print("failed to send photo message")
                        }

                    }

                case .failure(let error):
                    print("message photo upload error: \(error)")
                }
            }
            
        } else if let videoUrl = info[.mediaURL] as? URL {
            let fileName = StorageManager.fileName(forMessageId: messageId, fileExtension: .mov)

            // Upload Video

            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let urlString):
                    // Ready to send message
                    print("Uploaded Message Video: \(urlString)")

                    guard let url = URL(string: urlString), let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .video(media))

                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: self.otherUserEmail, name: name, newMessage: message) { success in

                        if success {
                            print("sent photo message")
                        } else {
                            print("failed to send photo message")
                        }

                    }

                case .failure(let error):
                    print("message photo upload error: \(error)")
                }
            }
        }
    }

}

extension ChatViewController: InputBarAccessoryViewDelegate {

    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let sender = self.sender,
              let messageId = createMessageId()
        else {
                return
        }

        print("Sending: \(text)")

        let message = Message(sender: sender, messageId: messageId, sentDate: Date(), kind: .text(text))

        // Send Message
        if isNewConversation {
            // create convo in database
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: message) { [weak self] success in
                if success {
                    print("message sent")
                    self?.isNewConversation = false
                    let newConversationId = "conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, scrollToLastItem: true)
                    self?.messageInputBar.inputTextView.text = nil
                }
                else {
                    print("failed to send")
                }
            }
            
        } else {
            guard let conversationId = conversationId, let name = self.title else { return }

            // append to existing conversation data
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message) { [weak self] success in
                if success {
                    self?.messageInputBar.inputTextView.text = nil
                    print("message sent")
                }
                else {
                    print("failed to send")
                }
            }
        }
    }

    private func createMessageId() -> String? {
        // date, otherUserEmail, senderEmail, randomInt
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }

        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)

        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"

        print("created message id: \(newIdentifier)")

        return newIdentifier
    }

}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    
    func currentSender() -> SenderType {
        guard let sender = sender else {
            fatalError("Self Sender is nil, email should be cached")
        }
        return sender
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }

    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }

    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }

        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }

    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        if message.sender.senderId == sender?.senderId {
            // our message that we've sent
            return .link
        }

        return .secondarySystemBackground
    }

    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {

        if message.sender.senderId == sender?.senderId {
            // show our image
            if let currentUserImageURL = self.senderPhotoURL {
                avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
            } else {
                // images/safeemail_profile_picture.png

                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }

                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = StorageManager.pathProfilePicture(by: safeEmail)

                // fetch url
                StorageManager.shared.downloadURL(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                }
            }
            
        } else {
            // other user image
            if let otherUsrePHotoURL = self.otherUserPhotoURL {
                avatarView.sd_setImage(with: otherUsrePHotoURL, completed: nil)
            } else {
                // fetch url
                let email = self.otherUserEmail

                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = StorageManager.pathProfilePicture(by: safeEmail)

                // fetch url
                StorageManager.shared.downloadURL(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                }
            }
        }
    }
    
}

extension ChatViewController: MessageCellDelegate {
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        let message = messages[indexPath.section]

        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let viewController = LocationPickerViewController(coordinates: coordinates)
            viewController.title = "Location"
            navigationController?.pushViewController(viewController, animated: true)
        default:
            break
        }
    }

    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }

        let message = messages[indexPath.section]

        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else { return }
            
            let viewController = PhotoViewerViewController(with: imageUrl)
            navigationController?.pushViewController(viewController, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else { return }

            let viewController = AVPlayerViewController()
            viewController.player = AVPlayer(url: videoUrl)
            present(viewController, animated: true)
        default:
            break
        }
    }
    
}
