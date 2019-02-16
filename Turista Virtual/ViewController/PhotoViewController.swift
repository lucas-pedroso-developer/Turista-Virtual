//
//  PhotoViewController.swift
//  Turista Virtual
//
//  Created by Lucas Daniel on 30/01/19.
//  Copyright © 2019 Lucas Daniel. All rights reserved.
//

import UIKit
import Foundation
import MapKit
import CoreData

class PhotoCollectionCell: UICollectionViewCell {
    var imageUrl: String = ""
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
}

class PhotoViewController: UIViewController {
    var latitude: Double?
    var longitude: Double?
    var pinAnnotation: MKPointAnnotation? = nil
    var photoParser: PhotosParser?
    var dataController: DataController!
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    var pin: Pin?
    var totalPages: Int? = nil
    var selectedIndexes = [IndexPath]()
    var insertedIndexPaths: [IndexPath]!
    var deletedIndexPaths: [IndexPath]!
    var updatedIndexPaths: [IndexPath]!
    var presentingAlert: Bool = false
    
    private var tasks: [String: URLSessionDataTask] = [:]
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var photosCollectionView: UICollectionView!
    @IBOutlet weak var imageLabel: UILabel!
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupMapView()
        
        guard let pin = pin else {
            return
        }
        
        showOnTheMap(pin)
        setupFetchedResultControllerWith(pin)
        if let photos = pin.photos, photos.count == 0 {
            fetchPhotosFromAPI(pin)
        }
        
    }
    
    func setupMapView() {
        mapView.delegate = self
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)
        mapView.addAnnotation(annotation)
    }
    
    private func loadPhotos(using pin: Pin) -> [Photo]? {
        let predicate = NSPredicate(format: "pin == %@", argumentArray: [pin])
        var photos: [Photo]?
        do {
            try photos = dataController.fetchPhotos(predicate, entityName: Photo.name, sorting: nil)
            self.photosCollectionView.reloadData()
        } catch {
            showInfo(withTitle: "Error", withMessage: "Error while loading Photos from disk: \(error)")
        }
        return photos
    }
    
    private func showOnTheMap(_ pin: Pin) {
        
        let lat = Double(pin.latitude!)!
        let lon = Double(pin.longitude!)!
        let locCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = locCoord
        
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(annotation)
        mapView.setCenter(locCoord, animated: true)
    }
    
    private func setupFetchedResultControllerWith(_ pin: Pin) {
        
        let fr = NSFetchRequest<Photo>(entityName: Photo.name)
        fr.sortDescriptors = []
        fr.predicate = NSPredicate(format: "pin == %@", argumentArray: [pin])
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        var error: NSError?
        do {
            try fetchedResultsController.performFetch()
        } catch let error1 as NSError {
            error = error1
        }
        
        if let error = error {
            print("\(#function) Error performing initial fetch: \(error)")
        }
    }
    
    private func fetchPhotosFromAPI(_ pin: Pin) {
        
        let lat = Double(pin.latitude!)!
        let lon = Double(pin.longitude!)!
        
        activityIndicator.startAnimating()
        self.updateStatusLabel("Fetching photos ...")
        
        searchBy(latitude: lat, longitude: lon, totalPages: totalPages) { (photosParsed, error) in
            self.performUIUpdatesOnMain {
                self.activityIndicator.stopAnimating()
                self.statusLabel.text = ""
            }
            
            if let photosParsed = photosParsed {
                self.totalPages = photosParsed.photos.pages
                let totalPhotos = photosParsed.photos.photo.count
                print("\(#function) Downloading \(totalPhotos) photos.")
                self.storePhotos(photosParsed.photos.photo, forPin: pin)
                if totalPhotos == 0 {
                    self.updateStatusLabel("No photos found for this location 😢")
                    print("No photos found for this location 😢")
                }
            } else if let error = error {
                print("\(#function) error:\(error)")
                self.showInfo(withTitle: "Error", withMessage: error.localizedDescription)
                self.updateStatusLabel("Something went wrong, please try again 🧐")
            }
        }
    }
    
    private func storePhotos(_ photos: [PhotoParser], forPin: Pin) {
        func showErrorMessage(msg: String) {
            showInfo(withTitle: "Error", withMessage: msg)
        }
        
        for photo in photos {
            DispatchQueue.main.sync {
                if let url = photo.url {
                    _ = Photo(title: photo.title, url_m: url, forPin: forPin, context: dataController.viewContext)
                    do {
                        try dataController.viewContext.save()
                    } catch {
                        showInfo(withTitle: "Error", withMessage: "Error while store photos: \(error)")
                    }
                }
            }
        }
    }
    
    func searchBy(latitude: Double, longitude: Double, totalPages: Int?, completion: @escaping (_ result: PhotosParser?, _ error: Error?) -> Void) {
        
        var page: Int {
            if let totalPages = totalPages {
                let page = min(totalPages, 4000/Constants.FlickrParameterValues.PhotosPerPage)
                return Int(arc4random_uniform(UInt32(page)) + 1)
            }
            return 1
        }
        
        let bbox = bboxString()
        
        let methodParameters = [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.BoundingBox: bboxString(),
            Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
            Constants.FlickrParameterKeys.PhotosPerPage  : "\(Constants.FlickrParameterValues.PhotosPerPage)",
            Constants.FlickrParameterKeys.Page           : "\(page)"
        ]
        
        
        _ = Client.shared().taskForGETMethod(parameters: methodParameters) { (data, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let data = data else {
                let userInfo = [NSLocalizedDescriptionKey : "Could not retrieve data."]
                completion(nil, NSError(domain: "taskForGETMethod", code: 1, userInfo: userInfo))
                return
            }
            
            do {
                let photosParser = try JSONDecoder().decode(PhotosParser.self, from: data)
                completion(photosParser, nil)
            } catch {
                print("\(#function) error: \(error)")
                completion(nil, error)
            }
        }
    }

    private func bboxString() -> String {
        if let latitude = latitude, let longitude = longitude {
            let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
            let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
            let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
            let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
            return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
        } else {
            return "0,0,0,0"
        }
    }

}


extension PhotoViewController: MKMapViewDelegate {
    
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
    
}

extension PhotoViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: Screen.screenWidth*35/100, height: Screen.screenWidth*35/100)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let sectionInfo = self.fetchedResultsController.sections?[section] {
            print(sectionInfo.numberOfObjects)
            return sectionInfo.numberOfObjects
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! PhotoCollectionCell
        cell.photoImageView.image = nil
        cell.activityIndicator.startAnimating()
        
        return cell
    }
    
     func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let photo = fetchedResultsController.object(at: indexPath)
        let photoViewCell = cell as! PhotoCollectionCell
        photoViewCell.imageUrl = photo.url_m!
        configImage(using: photoViewCell, photo: photo, collectionView: collectionView, index: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showAlert(indexPath: indexPath)
    }
    
    func showAlert(indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Deletar", message: "Deseja realmente deletar essa foto?", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) {
            UIAlertAction in
            self.deletePhoto(indexPath: indexPath)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) {
            UIAlertAction in
            NSLog("Cancel Pressed")
        }
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func deletePhoto(indexPath: IndexPath) {
        let photoToDelete = self.fetchedResultsController.object(at: indexPath)
        self.dataController.viewContext.delete(photoToDelete)
        do {
            try dataController.viewContext.save()
        } catch {
            showInfo(withTitle: "Error", withMessage: "Error while save context: \(error)")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying: UICollectionViewCell, forItemAt: IndexPath) {
        
        if collectionView.cellForItem(at: forItemAt) == nil {
            return
        }
        
        let photo = fetchedResultsController.object(at: forItemAt)
        if let imageUrl = photo.url_m {
            cancelDownload(imageUrl)
        }
        
        newCollectionButton.isEnabled = true
        newCollectionButton.isHidden = false
    }
    
    private func configImage(using cell: PhotoCollectionCell, photo: Photo, collectionView: UICollectionView, index: IndexPath) {
        if let imageData = photo.image {
            cell.activityIndicator.stopAnimating()
            cell.photoImageView.image = UIImage(data: Data(referencing: imageData))
        } else {
            if let imageUrl = photo.url_m {
                cell.activityIndicator.startAnimating()
                downloadImage(imageUrl: imageUrl) { (data, error) in
                    if let _ = error {
                        print("Error")
                        DispatchQueue.main.async {
                            cell.activityIndicator.stopAnimating()
                        }
                        self.performUIUpdatesOnMain {
                            cell.activityIndicator.stopAnimating()
                            self.errorForImageUrl(imageUrl)
                        }
                        return
                    } else if let data = data {
                        self.performUIUpdatesOnMain {
                            if let currentCell = collectionView.cellForItem(at: index) as? PhotoCollectionCell {
                                if currentCell.imageUrl == imageUrl {
                                    currentCell.photoImageView.image = UIImage(data: data)
                                    cell.activityIndicator.stopAnimating()
                                }
                            }
                            photo.image = NSData(data: data)
                            DispatchQueue.global(qos: .background).async {
                                DispatchQueue.main.sync {
                                    do {
                                        try self.dataController.viewContext.save()
                                    } catch {
                                        self.showInfo(withTitle: "Error", withMessage: "Error while save context: \(error)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func downloadImage(imageUrl: String, result: @escaping (_ result: Data?, _ error: NSError?) -> Void) {
        guard let url = URL(string: imageUrl) else {
            return
        }
        
        let task = Client.shared().taskForGETMethod(nil, url, parameters: [:]) { (data, error) in
            result(data, error)
            self.tasks.removeValue(forKey: imageUrl)
        }
        
        if tasks[imageUrl] == nil {
            tasks[imageUrl] = task
        }
    }
    
    private func errorForImageUrl(_ imageUrl: String) {
        if !self.presentingAlert {
            self.showInfo(withTitle: "Error", withMessage: "Error while fetching image for URL: \(imageUrl)", action: {
                self.presentingAlert = false
            })
        }
        self.presentingAlert = true
    }
    
    func cancelDownload(_ imageUrl: String) {
        tasks[imageUrl]?.cancel()
        if tasks.removeValue(forKey: imageUrl) != nil {
            print("\(#function) task canceled: \(imageUrl)")
        }
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        newCollectionButton.isEnabled = false
        newCollectionButton.isHidden = true
        for photos in fetchedResultsController.fetchedObjects! {
            dataController.viewContext.delete(photos)
        }
        
        do {
            try dataController.viewContext.save()
        } catch {
            showInfo(withTitle: "Error", withMessage: "Error while save context: \(error)")
        }
        fetchPhotosFromAPI(pin!)
    }
    
    private func updateStatusLabel(_ text: String) {
        self.performUIUpdatesOnMain {
            self.statusLabel.text = text
        }
    }
}

extension PhotoViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        insertedIndexPaths = [IndexPath]()
        deletedIndexPaths = [IndexPath]()
        updatedIndexPaths = [IndexPath]()
    }
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?) {
        
        switch (type) {
        case .insert:
            insertedIndexPaths.append(newIndexPath!)
            break
        case .delete:
            deletedIndexPaths.append(indexPath!)
            break
        case .update:
            updatedIndexPaths.append(indexPath!)
            break
        case .move:
            print("Move an item. We don't expect to see this in this app.")
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        photosCollectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.photosCollectionView.insertItems(at: [indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.photosCollectionView.deleteItems(at: [indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.photosCollectionView.reloadItems(at: [indexPath])
            }
            
        }, completion: nil)
    }
    
}
