import UIKit
import FirebaseAuth
import JGProgressHUD

/// Controller that shows list of conversations
final class ConversationsViewController: UIViewController {
    
    private var loginObserver: NSObjectProtocol?
    private var conversations = [Conversation]()
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.identifier)
        return table
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No conversations!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(composeButtonAction))
        
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setupTableView()
        startListeningForConversations()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else {
                return
            }

            self.startListeningForConversations()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = view.bounds
        noConversationsLabel.frame = CGRect(
            x: 10,
            y: (view.height - 100) / 2,
            width: view.width - 20,
            height: 100
        )
    }
    
    private func startListeningForConversations() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }

        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        print("starting conversation fetch...")

        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case let .success(conversations):
                print("successfully got conversation models")
                guard !conversations.isEmpty else {
                    self.tableView.isHidden = true
                    self.noConversationsLabel.isHidden = false
                    return
                }
                
                self.noConversationsLabel.isHidden = true
                self.tableView.isHidden = false
                self.conversations = conversations

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            case let .failure(error):
                print("failure got conversation models")
                self.tableView.isHidden = true
                self.noConversationsLabel.isHidden = false
                print("failed to get convos: \(error)")
            }
        }
    }
    
    @objc private func composeButtonAction() {
        let viewController = NewConversationViewController()
        viewController.completion = { [weak self] user in
            guard let self = self else { return }

            let currentConversations = self.conversations
            
            let safeEmail = DatabaseManager.safeEmail(emailAddress: user.email)

            if let targetConversation = currentConversations.first(where: { $0.otherUserEmail == safeEmail }) {
                let viewController = ChatViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
                viewController.isNewConversation = false
                viewController.title = targetConversation.name
                viewController.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(viewController, animated: true)
            }
            else {
                self.createNewConversation(with: user)
            }
        }
        let navigationController = UINavigationController(rootViewController: viewController)
        present(navigationController, animated: true)
    }
    
    private func createNewConversation(with user: SearchResult) {
        let name = user.name
        let email = DatabaseManager.safeEmail(emailAddress: user.email)

        // check in database if conversation with these two users exists
        // if it does, reuse conversation id
        // otherwise use existing code

        DatabaseManager.shared.conversationExists(with: email) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let conversationId):
                let viewController = ChatViewController(with: email, id: conversationId)
                viewController.isNewConversation = false
                viewController.title = name
                viewController.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(viewController, animated: true)
            case .failure(_):
                let viewController = ChatViewController(with: email, id: nil)
                viewController.isNewConversation = true
                viewController.title = name
                viewController.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
    
    private func validateAuth() {
        if Auth.auth().currentUser == nil {
            let viewController = LoginViewController()
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.modalPresentationStyle = .fullScreen
            present(navigationController, animated: false)
        }
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationCell.identifier, for: indexPath) as! ConversationCell
        let model = conversations[indexPath.row]
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let model = conversations[indexPath.row]
        let viewController = ChatViewController(with: model.otherUserEmail, id: model.id)
        viewController.title = model.name
        viewController.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // begin delete
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            self.conversations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)

            DatabaseManager.shared.deleteConversation(conversationId: conversationId) { success in
                if !success {
                    // add model and row back and show error alert
                }
            }

            tableView.endUpdates()
        }
    }
    
}
