import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn

class LoginViewController: UIViewController {
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .continue
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.lightGray.cgColor
        textField.placeholder = "Email address..."
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        textField.leftViewMode = .always
        textField.backgroundColor = .white
        return textField
    }()
    
    private let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.lightGray.cgColor
        textField.placeholder = "Password..."
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        textField.leftViewMode = .always
        textField.backgroundColor = .white
        textField.isSecureTextEntry = true
        return textField
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let facebookLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["public_profile", "email"]
        return button
    }()
    
    private let googleLoginButton: GIDSignInButton = {
        let button = GIDSignInButton()
        return button
    }()
    
    private var loginObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
        GIDSignIn.sharedInstance().presentingViewController = self
        
        title = "Log In"
        view.backgroundColor = .white
        
        let registerBarButtonItem = UIBarButtonItem(
            title: "Register",
            style: .done,
            target: self,
            action: #selector(registerButtonAction)
        )
        navigationItem.rightBarButtonItem = registerBarButtonItem
        
        loginButton.addTarget(self, action: #selector(loginButtonAction), for: .touchUpInside)
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
        facebookLoginButton.delegate = self
        
        // add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailTextField)
        scrollView.addSubview(passwordTextField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(facebookLoginButton)
        scrollView.addSubview(googleLoginButton)
    }
    
    deinit {
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width / 3
        
        imageView.frame = CGRect(x: (scrollView.width - size) / 2, y: 20, width: size, height: size)
        emailTextField.frame = CGRect(x: 30, y: imageView.bottom + 10, width: scrollView.width - 60, height: 52)
        passwordTextField.frame = CGRect(x: 30, y: emailTextField.bottom + 10, width: scrollView.width - 60, height: 52)
        loginButton.frame = CGRect(x: 30, y: passwordTextField.bottom + 10, width: scrollView.width - 60, height: 52)
        facebookLoginButton.frame = CGRect(x: 30, y: loginButton.bottom + 10, width: scrollView.width - 60, height: 52)
        googleLoginButton.frame = CGRect(x: 30, y: facebookLoginButton.bottom + 10, width: scrollView.width - 60, height: 52)
    }
    
    @objc private func loginButtonAction() {
        emailTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, password.count >= 6
        else {
            alertUserLoginError()
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            guard let result = authResult, error == nil else {
                print("Failed to log in user with email: \(email)")
                return
            }
            
            let user = result.user
            print("Logged in User: \(user)")
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
    }
    
    func alertUserLoginError() {
        let alert = UIAlertController(
            title: "Woops",
            message: "Please enter all information to log in.",
            preferredStyle: .alert
        )
        
        let dismissAlertAction = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
        alert.addAction(dismissAlertAction)
        
        present(alert, animated: true)
    }
    
    @objc private func registerButtonAction() {
        let viewController = RegisterViewController()
        viewController.title = "Create Account"
        navigationController?.pushViewController(viewController, animated: true)
    }

}

extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            loginButtonAction()
        }
        
        return true
    }
    
}

extension LoginViewController: LoginButtonDelegate {
    
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        // no operation
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else {
            print("User failed to log in with facebook")
            return
        }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(
            graphPath: "me",
            parameters: ["fields": "email, name"],
            tokenString: token,
            version: nil,
            httpMethod: .get
        )
        
        facebookRequest.start {[weak self]  _, result, error in
            guard let self = self else { return }
            guard let result = result as? [String: Any] else {
                print("Failed to make facebook graph request")
                return
            }
            
            guard let userName = result["name"] as? String,
                  let email = result["email"] as? String
            else {
                print("Failed to get email and name from facebook result")
                return
            }
            
            let nameComponents = userName.components(separatedBy: " ")
            guard nameComponents.count == 2 else {
                print("Failed to get email and name from facebook result")
                return
            }
            
            let firstName = nameComponents[0]
            let lastName = nameComponents[1]
            
            DatabaseManager.shared.userExists(with: email) { exist in
                if !exist {
                    let chatAppUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                    DatabaseManager.shared.insertUser(with: chatAppUser)
                }
            }
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            Auth.auth().signIn(with: credential) { authResult, error in
                guard authResult != nil, error == nil else {
                    print("Facebook credential login failed, MFA may be needed")
                    return
                }
                
                print("Successfully logged user in")
                self.navigationController?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
}
