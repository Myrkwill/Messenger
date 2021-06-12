import Foundation
import FirebaseDatabase

/// Manager object to read and write data to real time firebase database
final class DatabaseManager {
    
    /// Shared instance of class
    public static let shared = DatabaseManager()
    
    private let conversationManager = DatabaseConversationManager.shared
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

// MARK: - Account Menagment
extension DatabaseManager {
    
    public func userExists(with email: String, completion: @escaping (Bool) -> Void) {
        DatabaseUserManager.shared.userExists(with: email, completion: completion)
    }
    
    /// Insert new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        DatabaseUserManager.shared.insertUser(with: user, completion: completion)
    }
    
    /// Gets all users from database
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        DatabaseUserManager.shared.getAllUsers(completion: completion)
    }
}

// MARK: - Sending messages / conversation
extension DatabaseManager {
    
    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        conversationManager.createNewConversation(with: otherUserEmail, name: name, firstMessage: firstMessage, completion: completion)
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        conversationManager.getAllConversation(for: email, completion: completion)
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        conversationManager.getAllMessagesForConversation(with: id, completion: completion)
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        conversationManager.sendMessage(to: conversation, otherUserEmail: otherUserEmail, name: name, newMessage: newMessage, completion: completion)
    }

    public func deleteConversation(conversationId id: String, completion: @escaping (Bool) -> Void) {
        conversationManager.deleteConversation(conversationId: id, completion: completion)
    }

    public func conversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        conversationManager.conversationExists(with: targetRecipientEmail, completion: completion)
    }
    
}



