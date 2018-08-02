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

enum Result<T> {
    case success(T)
    case error(String)
}

struct Activity: Codable {
    let type: String
    let body: String
    let displayName: String
    let email: String
    let uid: String
}

// We'll need a completion block that returns an error if we run into any problems
func submitActivity(activity: Activity, location: CLLocation, placemark: CLPlacemark, completion: ((Result<String>) -> Void)?) {
    
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
                "name": placemark.name!,
                "thoroughfare": placemark.thoroughfare!,
                "subThoroughfare": placemark.subThoroughfare!,
                "country": placemark.country!,
                "locality": placemark.locality!,
                "subLocality": placemark.subLocality!,
            ]
        
           db.collection("activity").addDocument(data: [
                "type": activity.type,
                "body": activity.body,
                "displayName": activity.displayName,
                "email": activity.email,
                "uid": activity.uid,
                "createdAt": FieldValue.serverTimestamp(),
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

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UNUserNotificationCenterDelegate,  CLLocationManagerDelegate, GIDSignInUIDelegate {

    var locationManager: CLLocationManager!
    var userLocation: CLLocation!
    var placemark: CLPlacemark!
    
    let pickerData: [(String, String)]  = [
        ("Word", "Daddy" ),
        ("Weight", "12.5"),
        ("Height", "75"),
        ("Action", "Jumped")
    ]
    
    private let activityLabel:UILabel = {
        var label = UILabel()
        label.textAlignment = NSTextAlignment.center
        label.text = "Add another Activity"
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
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
        btn.addTarget(self, action: #selector(postActivity(_:)), for: .touchUpInside)

        return btn
    }()
    
    private let activityType:UITextField = {
        let txtField = UITextField()
        txtField.borderStyle = .roundedRect
        txtField.placeholder = "Activity Type"
        txtField.translatesAutoresizingMaskIntoConstraints = false
        //        txtField.sizeToFit()
        
        return txtField
    }()
    
    private let activityBody:UITextField = {
        let txtField = UITextField()
        txtField.borderStyle = .roundedRect
        txtField.placeholder = "Activity Body"
        //        txtField.sizeToFit()
        
        txtField.translatesAutoresizingMaskIntoConstraints = false
        
        return txtField
    }()
    
    @objc private func googleSignIn(_ sender: UIButton?) {
        GIDSignIn.sharedInstance().signIn()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        loginContentView.addSubview(btnLogin)
        view.addSubview(loginContentView)
        
        signedInContentView.addSubview(activityLabel)
        signedInContentView.addSubview(activityType)
        signedInContentView.addSubview(activityBody)
        signedInContentView.addSubview(btnSubmit)
        view.addSubview(signedInContentView)
        signedInContentView.isHidden = true
        
        activityType.inputView = activityPicker
        
        setUpAutoLayout()
        
        GIDSignIn.sharedInstance().uiDelegate = self
        activityPicker.delegate = self
        activityPicker.dataSource = self
        
        if GIDSignIn.sharedInstance().hasAuthInKeychain() {
            GIDSignIn.sharedInstance().signInSilently()
        }

        determineMyCurrentLocation()
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

    @objc private func postActivity(_ sender: UIButton?) {
        guard let user = Auth.auth().currentUser else { fatalError("Could not get authed user") }
        
        let myActivity = Activity(
            type: activityType.text!,
            body: activityBody.text!,
            displayName: user.displayName!,
            email: user.email!,
            uid: user.uid
        )
        
        submitActivity(activity: myActivity, location: userLocation, placemark: placemark) {
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

        activityType.topAnchor.constraint(equalTo:activityLabel.bottomAnchor, constant:20).isActive = true
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
    
    func numberOfComponents(in _: UIPickerView) -> Int {
        return 1
    }
    
    func numberOfComponentsInPickerView(pickerView _: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        return pickerData.count
    }
    
    func pickerView(_: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
        activityType.text = pickerData[row].0
        activityBody.text = pickerData[row].1
    }
    
    func pickerView(_: UIPickerView, titleForRow row: Int, forComponent _: Int) -> String? {
        return pickerData[row].0
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}

