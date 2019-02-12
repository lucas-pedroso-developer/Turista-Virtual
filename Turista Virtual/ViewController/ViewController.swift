//
//  ViewController.swift
//  Turista Virtual
//
//  Created by Lucas Daniel on 27/01/19.
//  Copyright © 2019 Lucas Daniel. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class ViewController: UIViewController, MKMapViewDelegate {

    var latitude: Double?
    var longitude: Double?
    var pinAnnotation: MKPointAnnotation? = nil
    var dataController: DataController!
    var fetchedResultsController:NSFetchedResultsController<Pin>!
    var pin: Pin?
    var editando: Bool = false
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet var LongPressGesture: UILongPressGestureRecognizer!
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var deletePinButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        if let pins = loadAllPins() {
            showPins(pins)
        }
    }
    
    func showPins(_ pins: [Pin]) {
        for pin in pins where pin.latitude != nil && pin.longitude != nil {
            let annotation = MKPointAnnotation()
            let lat = Double(pin.latitude!)!
            let lon = Double(pin.longitude!)!
            annotation.coordinate = CLLocationCoordinate2DMake(lat, lon)
            mapView.addAnnotation(annotation)
        }
        mapView.showAnnotations(mapView.annotations, animated: true)
    }

    @IBAction func edit(_ sender: UIBarButtonItem) {
        editando = !editando
        if editando {
            editButton.title = "Concluir"
            deletePinButton.isHidden = false
        } else {
            editButton.title = "Editar"
            deletePinButton.isHidden = true
        }
    }
    
    private func loadAllPins() -> [Pin]? {
        var pins: [Pin]?
        do {
            try pins = dataController.fetchAllPins(entityName: Pin.name)
        } catch {
            print("\(#function) error:\(error)")
            showInfo(withTitle: "Error", withMessage: "Error while fetching Pin locations: \(error)")
        }
        return pins
    }
    
    private func loadPin(latitude: String, longitude: String) -> Pin? {
        let predicate = NSPredicate(format: "latitude == %@ AND longitude == %@", latitude, longitude)
        var pin: Pin?
        do {
            try pin = dataController.fetchPin(predicate, entityName: Pin.name)
        } catch {
            print("\(#function) error:\(error)")
            showInfo(withTitle: "Error", withMessage: "Error while fetching location: \(error)")
        }
        return pin
    }
    
    @IBAction func adedPinGesture(_ sender: UILongPressGestureRecognizer) {
        let location = sender.location(in: mapView)
        let locCoord = mapView.convert(location, toCoordinateFrom: mapView)
        
        if sender.state == .began {
            pinAnnotation = MKPointAnnotation()
            pinAnnotation!.coordinate = locCoord
            print("\(#function) Coordinate: \(locCoord.latitude),\(locCoord.longitude)")
            mapView.addAnnotation(pinAnnotation!)
            let pin = Pin(context: dataController.viewContext)
            pin.latitude = String(locCoord.latitude)
            pin.longitude = String(locCoord.longitude)
        } else if sender.state == .changed {
            pinAnnotation!.coordinate = locCoord
        } else if sender.state == .ended {
            _ = Pin(
                latitude: String(pinAnnotation!.coordinate.latitude),
                longitude: String(pinAnnotation!.coordinate.longitude),
                context: DataController.shared().viewContext
            )
            save()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destinationVC = segue.destination as! PhotoViewController
        destinationVC.latitude = latitude!
        destinationVC.longitude = longitude!
        destinationVC.pin = pin
        destinationVC.dataController = self.dataController
    }
}

extension ViewController {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = .red
            pinView!.animatesDrop = true
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == view.rightCalloutAccessoryView {
            self.showInfo(withMessage: "No link defined.")
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
         guard let annotation = view.annotation else {
            return
        }
        
        mapView.deselectAnnotation(annotation, animated: true)
        print("\(#function) lat \(annotation.coordinate.latitude) lon \(annotation.coordinate.longitude)")
        let lat = String(annotation.coordinate.latitude)
        let lon = String(annotation.coordinate.longitude)
        self.latitude = annotation.coordinate.latitude
        self.longitude = annotation.coordinate.longitude
        
        if let pin = loadPin(latitude: lat, longitude: lon) {
            self.pin = pin            
            if editando {
                mapView.removeAnnotation(annotation)
                dataController.viewContext.delete(pin)
                save()
                return
            }
        }
        
        let methodParameters = [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
        ]
        performSegue(withIdentifier: "showPhotos", sender: nil)
    }
}

