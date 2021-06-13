import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage

final class ProfileViewController: UIViewController {

    @IBOutlet var tableView: UITableView!

    var data = [ProfileViewModel]()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ProfileCell.self, forCellReuseIdentifier: ProfileCell.identifier)
        
        let name = ProfileViewModel(
            viewModelType: .info,
            title: "Name: \(UserDefaults.standard.value(forKey:"name") as? String ?? "No Name")",
            handler: nil
        )
        
        let email = ProfileViewModel(
            viewModelType: .info,
            title: "Email: \(UserDefaults.standard.value(forKey:"email") as? String ?? "No Email")",
            handler: nil
        )
        
        let logout = ProfileViewModel(viewModelType: .logout, title: "Log Out") { [weak self] in
            guard let self = self else { return }

            let actionSheet = UIAlertController(title: "", message: "", preferredStyle: .actionSheet)
            let logoutAlertAction = UIAlertAction(title: "Log Out", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                
                UserDefaults.standard.setValue(nil, forKey: "email")
                UserDefaults.standard.setValue(nil, forKey: "name")
                
                // Log Out facebook
                FBSDKLoginKit.LoginManager().logOut()
                
                // Google Log out
                GIDSignIn.sharedInstance()?.signOut()
                
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    
                    let viewController = LoginViewController()
                    let nav = UINavigationController(rootViewController: viewController)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                } catch {
                    print("Failed to log out")
                }
            }
            
            actionSheet.addActions([logoutAlertAction, .cancel])
            self.present(actionSheet, animated: true)
        }
        
        data += [name, email, logout]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableViewHeader()
    }
    
    func createTableViewHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let path = StorageManager.pathProfilePicture(by: safeEmail)
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.width, height: 300))
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(frame: CGRect(x: (headerView.width - 150) / 2, y: 75, width: 150, height: 150))
        imageView.backgroundColor = .white
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadURL(for: path) { result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("Failed to get download url: \(error)")
            }
        }
        
        return headerView
    }

}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileCell.identifier, for: indexPath) as! ProfileCell
        
        let viewModel = data[indexPath.row]
        cell.setUp(with: viewModel)
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }
    
}
