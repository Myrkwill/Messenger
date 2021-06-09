import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn

class ProfileViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    let data = ["Log Out"]

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
    }

}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = data[indexPath.row]
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.textColor = .red
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let actionSheet = UIAlertController(title: "", message: "", preferredStyle: .actionSheet)
        let logoutAlertAction = UIAlertAction(
            title: "Log Out",
            style: .destructive,
            handler: { [weak self] _ in
                guard let self = self else { return }
                
                // Log Out Facebook
                LoginManager().logOut()
                
                // Log Out Google
                GIDSignIn.sharedInstance().signOut()
                
                do {
                    try Auth.auth().signOut()
                    
                    let viewController = LoginViewController()
                    let navigationController = UINavigationController(rootViewController: viewController)
                    navigationController.modalPresentationStyle = .fullScreen
                    self.present(navigationController, animated: false)
                } catch {
                    print(error)
                }
            }
        )
        let cancelAlertAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheet.addAction(logoutAlertAction)
        actionSheet.addAction(cancelAlertAction)
        present(actionSheet, animated: true)
    }
    
}
