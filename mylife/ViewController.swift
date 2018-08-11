//
//  ViewController.swift
//  mylife
//
//  Created by Johan Stenehall on 2018-08-01.
//  Copyright © 2018 Johan Stenehall. All rights reserved.
//

import UIKit
import UserNotifications
import CoreLocation

import Firebase
import GoogleSignIn
//import FirebaseFirestore

//import Firebase/Storage

enum Result<T> {
    case success(T)
    case error(String)
}

struct Activity: Codable {
    let child: String
    let type: String
    let prettyType: String
    let body: String
    let photoURL: String
}

// We'll need a completion block that returns an error if we run into any problems
func submitActivity(activity: Activity, user: User,  location: CLLocation, placemark: CLPlacemark, completion: ((Result<String>) -> Void)?) {
    
    // Firestore was complaining about having to these lines
    let db = Firestore.firestore()
    let settings = db.settings
    settings.areTimestampsInSnapshotsEnabled = true
    db.settings = settings
    
    let healthKitInterface = HealthKitInterface()
    healthKitInterface.getTodaysSteps(completion: {
        (stepCount) in
        
            let dbLocation = [
                "latitude": String(location.coordinate.latitude),
                "longitude": String(location.coordinate.longitude),
                "name": placemark.name ?? "",
                "thoroughfare": placemark.thoroughfare ?? "",
                "subThoroughfare": placemark.subThoroughfare ?? "",
                "country": placemark.country ?? "",
                "locality": placemark.locality ?? "",
                "subLocality": placemark.subLocality ?? "",
            ]
        
//        print(ServerValue.timestamp())
//        let t = ServerValue.timestamp()
//        let t1 = NSDate().timeIntervalSince1970
//        let t2 = Firestore.database.ServerValue.TIMESTAMP
        
        db.collection("users").document(user.uid).collection("activities").addDocument(data: [
                "type": activity.type,
                "prettyType": activity.prettyType,
                "child": activity.child,
                "body": activity.body,
                "photoURL": activity.photoURL,
                "displayName": user.displayName!,
                "email": user.email!,
                "uid": user.uid,
                "createdAt": Firebase.FieldValue.serverTimestamp(),
                "healthKit": [
                    "stepCount": stepCount
                ],
                "location": dbLocation
            ]) { err in
                if err != nil {
                    // This is rather nice.
                    // If we have a completion lets run it
                    completion?(.error("Oh noooo"))
                } else {
                    completion?(.success("hurray"))
                }
            }
    })
}

class ViewController:
    UIViewController,
    UIPickerViewDataSource,
    UIImagePickerControllerDelegate,
    UIPickerViewDelegate,
    UNUserNotificationCenterDelegate,
    UINavigationControllerDelegate,
    CLLocationManagerDelegate,
    GIDSignInUIDelegate  {

    var locationManager: CLLocationManager!
    var userLocation: CLLocation!
    var placemark: CLPlacemark!
    var activityTypeKey: String!
    
    let imagePicker = UIImagePickerController()
    
    let childPickerData: [String]  = [
        "Aron",
        "Mini"
    ]
    
    let pickerData: [(String, String, String)]  = [
        ("New Word", "newword", "Daddy"),
        ("Weight (kg)", "weight", "12.5"),
        ("Height (cm)", "height", "75"),
        ("Action", "action","Jumped for the first time"),
        ("Travel", "travel","At the summer house"),
        ("Sick", "sick","Having a high fever")
    ]
    
    private let activityLabel:UILabel = {
        var label = UILabel()
        label.textAlignment = NSTextAlignment.center
        label.text = "Add another Activity"
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()
    
    private let childPicker:UIPickerView = {
        let picker = UIPickerView()

        return picker
    }()
    
    private let activityPicker:UIPickerView = {
        let picker = UIPickerView()
        
        return picker
    }()
    
    private let loginContentView:UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    private let signedInContentView:UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    private let btnLogin:GIDSignInButton = {
        let btn = GIDSignInButton()
        btn.addTarget(self, action: #selector(googleSignIn(_:)), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false

        return btn
    }()
    
    private let btnSubmit:UIButton = {
        let btn = UIButton(type:.system)
        btn.backgroundColor = .blue
        btn.setTitle("Submit", for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = 5
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(ViewController.postActivity), for: .touchUpInside)

        return btn
    }()
    
    private let imageView:UIImageView = {
        let imageV = UIImageView(frame: CGRect.zero)
        imageV.backgroundColor = .gray
        imageV.contentMode = UIViewContentMode.scaleAspectFit
        imageV.frame.size.height = 100
        imageV.translatesAutoresizingMaskIntoConstraints = false
        //imageV.isHidden = true
        
        return imageV
    }()
    
    private let activityImage:UIButton = {
        let btn = UIButton(type:.system)
        btn.backgroundColor = .blue
        btn.setTitle("+", for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = 5
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(showImageUploader(_:)), for: .touchUpInside)
        
        return btn
    }()
    
    private let activityChild:UITextField = {
        let txtField = UITextField()
        txtField.borderStyle = .roundedRect
        txtField.placeholder = "Child"
        txtField.translatesAutoresizingMaskIntoConstraints = false
        
        return txtField
    }()
    
    private let activityType:UITextField = {
        let txtField = UITextField()
        txtField.borderStyle = .roundedRect
        txtField.placeholder = "Activity Type"
        txtField.translatesAutoresizingMaskIntoConstraints = false
        
        return txtField
    }()
    
    private let activityBody:UITextField = {
        let txtField = UITextField()
        txtField.borderStyle = .roundedRect
        txtField.placeholder = "Activity Body"
        txtField.clearButtonMode = .whileEditing

        txtField.translatesAutoresizingMaskIntoConstraints = false
        
        return txtField
    }()
    
    @objc private func googleSignIn(_ sender: UIButton?) {
        GIDSignIn.sharedInstance().signIn()
    }
    
    @objc private func showImageUploader(_ sender: UIButton?) {
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
        present(imagePicker, animated: true, completion: nil)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.showImageUploader))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGestureRecognizer)

        
        loginContentView.addSubview(btnLogin)
        view.addSubview(loginContentView)
 
        signedInContentView.addSubview(activityLabel)
        signedInContentView.addSubview(activityImage)
        signedInContentView.addSubview(imageView)

        signedInContentView.addSubview(activityChild)
        signedInContentView.addSubview(activityType)
        signedInContentView.addSubview(activityBody)
        signedInContentView.addSubview(btnSubmit)

        view.addSubview(signedInContentView)
        signedInContentView.isHidden = true
        
        setUpAutoLayout()
        
        activityPicker.delegate = self
        activityPicker.dataSource = self
        
        childPicker.delegate = self
        childPicker.dataSource = self

        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary

        activityChild.inputView = childPicker
        activityType.inputView = activityPicker
        
        // Setting default values for inputs
        activityChild.text = childPickerData[0]
        activityType.text = pickerData[0].0
        activityTypeKey = pickerData[0].1
        activityBody.text = pickerData[0].2
        
        GIDSignIn.sharedInstance().uiDelegate = self
        
        if GIDSignIn.sharedInstance().hasAuthInKeychain() {
            GIDSignIn.sharedInstance().signInSilently()
        }

        //requesting for authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: {didAllow, error in
            
        })
        repeatNotification()

        determineMyCurrentLocation()
    }

    func fileUpload(completion: @escaping (String) -> Void) {
        if((imageView.image != nil) && imageView.image?.size.width != 0) {
            let storage = Storage.storage()
            let storageRef = storage.reference()
            var data = Data()
            data = UIImageJPEGRepresentation(imageView.image!, 0.8)!
            
            let riversRef = storageRef.child("images/" + NSUUID().uuidString + ".jpg")

            let uploadTask = riversRef.putData(data, metadata: nil) { (metadata, error) in
                guard let metadata = metadata else {
                    return
                }

                let size = metadata.size
                let downloadURL = riversRef.downloadURL { (url, error) in
                    guard let downloadURL = url else {
                        return
                    }
                    print(downloadURL)
                    completion(downloadURL.absoluteString)
                }
                print(downloadURL)
            }
            print(uploadTask)
        } else {
            completion("")
        }
    }

    
    func determineMyCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
            //locationManager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations[0] as CLLocation
        
        CLGeocoder().reverseGeocodeLocation(userLocation, completionHandler: {(placemarks, error) -> Void in
            if (error != nil) {
                print("Reverse geocoder failed with error" + (error?.localizedDescription)!)
                return
            }
            
            if (placemarks?.count)! > 0 {
                self.placemark = placemarks![0] as CLPlacemark
            } else {
                print("Problem with the data received from geocoder")
            }
        })
    }
    
    func repeatNotification() {
        let content = UNMutableNotificationContent()
        content.title = "It's Time!"
        //content.subtitle = "Save a new activity"
        content.body = "Save a memory of what's been happening over the last few hours"
        content.categoryIdentifier = "mylife.reminder"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 21600.0, repeats: true)
        
        let request = UNNotificationRequest(identifier: "mylife.reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("error in allowing notifications: \(error.localizedDescription)")
            }
        }
        
        print("added notification:\(request.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error \(error)")
    }
    
    func showSuccess() {
        let alert = UIAlertController(title: "Notice", message: "Success we've submitted the data", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Ok!", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func showFailure(reason: String) {
        let alert = UIAlertController(title: "Notice", message: reason, preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func signedIn() {
        loginContentView.isHidden = true
        signedInContentView.isHidden = false
    }

    @objc private func postActivity() {
        fileUpload() {
            photoURL in
                print(photoURL)
            
                guard let user = Auth.auth().currentUser else { fatalError("Could not get authed user") }
            
                let myActivity = Activity(
                    child: self.activityChild.text!,
                    type: self.activityTypeKey ?? "",
                    prettyType: self.activityType.text!,
                    body: self.activityBody.text!,
                    photoURL: photoURL
                )
            
            submitActivity(activity: myActivity, user: user, location: self.userLocation, placemark: self.placemark) {
                        (result) in
                        switch result {
                            case let .success(value):
                                print("Result of division is \(value)")
                                self.showSuccess()
                            case let .error(error):
                                print("error: \(error)")
                                self.showFailure(reason: error)
                            }
                    }

        }
    }
    
    func setUpAutoLayout() {
        loginContentView.leftAnchor.constraint(equalTo:view.leftAnchor).isActive = true
        loginContentView.rightAnchor.constraint(equalTo:view.rightAnchor).isActive = true
        loginContentView.heightAnchor.constraint(equalToConstant: view.frame.height/3).isActive = true
        loginContentView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        btnLogin.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        btnLogin.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        signedInContentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        signedInContentView.leftAnchor.constraint(equalTo:view.leftAnchor).isActive = true
        signedInContentView.rightAnchor.constraint(equalTo:view.rightAnchor).isActive = true
        signedInContentView.heightAnchor.constraint(equalToConstant: view.frame.height).isActive = true

        activityLabel.topAnchor.constraint(equalTo:signedInContentView.topAnchor, constant:40).isActive = true
        activityLabel.leftAnchor.constraint(equalTo:signedInContentView.leftAnchor, constant:20).isActive = true
        activityLabel.rightAnchor.constraint(equalTo:signedInContentView.rightAnchor, constant:-20).isActive = true

        activityImage.topAnchor.constraint(equalTo:activityLabel.bottomAnchor, constant:40).isActive = true
        activityImage.leftAnchor.constraint(equalTo:signedInContentView.leftAnchor, constant:20).isActive = true
        activityImage.heightAnchor.constraint(equalToConstant:30).isActive = true
        
        imageView.topAnchor.constraint(equalTo:activityLabel.bottomAnchor, constant:20).isActive = true
        imageView.leftAnchor.constraint(equalTo:activityImage.rightAnchor, constant:20).isActive = true
        imageView.rightAnchor.constraint(equalTo:signedInContentView.rightAnchor, constant:-20).isActive = true
        imageView.heightAnchor.constraint(equalToConstant:100).isActive = true
        
        activityChild.topAnchor.constraint(equalTo:imageView.bottomAnchor, constant:40).isActive = true
        activityChild.leftAnchor.constraint(equalTo:signedInContentView.leftAnchor, constant:20).isActive = true
        activityChild.rightAnchor.constraint(equalTo:signedInContentView.rightAnchor, constant:-20).isActive = true
        activityChild.heightAnchor.constraint(equalToConstant:30).isActive = true
        
        activityType.topAnchor.constraint(equalTo:activityChild.bottomAnchor, constant:20).isActive = true
        activityType.leftAnchor.constraint(equalTo:signedInContentView.leftAnchor, constant:20).isActive = true
        activityType.rightAnchor.constraint(equalTo:signedInContentView.rightAnchor, constant:-20).isActive = true
        activityType.heightAnchor.constraint(equalToConstant:30).isActive = true
        
        activityBody.topAnchor.constraint(equalTo:activityType.bottomAnchor, constant:20).isActive = true
        activityBody.leftAnchor.constraint(equalTo:signedInContentView.leftAnchor, constant:20).isActive = true
        activityBody.rightAnchor.constraint(equalTo:signedInContentView.rightAnchor, constant:-20).isActive = true
        activityBody.heightAnchor.constraint(equalToConstant:30).isActive = true

        btnSubmit.topAnchor.constraint(equalTo:activityBody.bottomAnchor, constant:20).isActive = true
        btnSubmit.leftAnchor.constraint(equalTo:signedInContentView.leftAnchor, constant:20).isActive = true
        btnSubmit.rightAnchor.constraint(equalTo:signedInContentView.rightAnchor, constant:-20).isActive = true
        btnSubmit.heightAnchor.constraint(equalToConstant:30).isActive = true
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func numberOfComponentsInPickerView(pickerView _: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        if (pickerView == activityPicker) {
            return pickerData.count
        } else {
            return childPickerData.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
        if (pickerView == activityPicker) {
            let (type, key, body) = pickerData[row] // Decompose / deconstruct
            
            activityType.text = type
            activityTypeKey = key
            activityBody.text = body
        } else {
            activityChild.text = childPickerData[row]
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent _: Int) -> String? {
        if (pickerView == activityPicker) {
            return pickerData[row].0
        } else {
            return childPickerData[row]

        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            // imageViewPic.contentMode = .scaleToFill
            imageView.image = pickedImage
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}

