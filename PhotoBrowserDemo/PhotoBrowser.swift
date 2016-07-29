//
//  PhotoBrowserViewController.swift
//  Nodality
//
//  Created by Simon Gladman on Feb 8, 2015
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to http://www.shinobicontrols.com/blog/posts/2014/08/22/ios8-day-by-day-day-20-photos-framework


import UIKit
import Photos

class PhotoBrowser: UIViewController
{
    let manager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()

    var touchedCell: (cell: UICollectionViewCell, indexPath: IndexPath)?
    var collectionViewWidget: UICollectionView!
    var segmentedControl: UISegmentedControl!
    let blurOverlay = UIVisualEffectView(effect: UIBlurEffect())
    let background = UIView(frame: CGRect.zero)
    let activityIndicator = ActivityIndicator()
    
    var photoBrowserSelectedSegmentIndex = 0

    var assetCollections: PHFetchResult<PHAssetCollection>!
    var segmentedControlItems = [String]()
    var contentOffsets = [CGPoint]()
    
    var selectedAsset: PHAsset?
    var uiCreated = false
    
    var returnImageSize = CGSize(width: 100, height: 100)
    
    weak var delegate: PhotoBrowserDelegate?
    
    required init(returnImageSize: CGSize)
    {
        super.init(nibName: nil, bundle: nil)
        
        self.returnImageSize = returnImageSize
        
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.highQualityFormat
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.exact
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.progressHandler = {
            (value: Double, _: NSError?, _ : UnsafeMutablePointer<ObjCBool>, _ : [NSObject : AnyObject]?) in
            self.activityIndicator.updateProgress(value)
        }
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    func launch()
    {
        if let viewController = UIApplication.shared().keyWindow!.rootViewController
        {
            modalPresentationStyle = UIModalPresentationStyle.overFullScreen
            modalTransitionStyle = UIModalTransitionStyle.crossDissolve
            
            viewController.present(self, animated: true, completion: nil)
            
            activityIndicator.stopAnimating()
        }
    }
    
    var assetsByDate = [String : [PHAsset]]()
    func updateAssetsByDate()
    {
        let formatter:DateFormatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if assets.count > 0
        {
            assetsByDate = [String : [PHAsset]]()
            var assetsByDateUnsorted = [String : [PHAsset]]()
            for i in 0..<assets.count
            {
                let asset = assets[i]
                if let date = asset.creationDate
                {
                    let dateString = formatter.string(from: date) // DateFormatter.localizedString(from: date, dateStyle: DateFormatter.Style.medium, timeStyle: DateFormatter.Style.none)
                    if assetsByDateUnsorted[dateString] == nil
                    {
                        assetsByDateUnsorted[dateString] = [PHAsset]()
                        
                    }
                    assetsByDateUnsorted[dateString]!.append(asset)
                }
            }
            for element in (assetsByDateUnsorted.sorted { $0.value.first?.creationDate < $1.value.first?.creationDate })
            {
                print(element.value.first?.creationDate)
                assetsByDate[element.key] = element.value
            }
        }
    }
    
    var assets: PHFetchResult<PHAsset>!
    {
        didSet
        {
            guard let oldValue = oldValue else
            {
                return
            }
            
            if oldValue.count - assets.count == 1
            {
                updateAssetsByDate()
                
                collectionViewWidget.deleteItems(at: [touchedCell!.indexPath])
                
                collectionViewWidget.reloadData()
            }
            else if oldValue.count != assets.count
            {
                updateAssetsByDate()
                
                UIView.animate(withDuration: PhotoBrowserConstants.animationDuration,
                    animations:
                    {
                        self.collectionViewWidget.alpha = 0
                    },
                    completion:
                    {
                        (value: Bool) in
                        self.collectionViewWidget.reloadData()
                        self.collectionViewWidget.contentOffset = self.contentOffsets[self.segmentedControl.selectedSegmentIndex]
                        UIView.animate(withDuration: PhotoBrowserConstants.animationDuration, animations: { self.collectionViewWidget.alpha = 1.0 })
                    })
            }
            else
            {
                collectionViewWidget.reloadData()
            }
        }
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        PHPhotoLibrary.shared().register(self)
        
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized
        {
            createUserInterface()
        }
        else
        {
            PHPhotoLibrary.requestAuthorization(requestAuthorizationHandler)
        }
    }
    
    func requestAuthorizationHandler(_ status: PHAuthorizationStatus)
    {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized
        {
            PhotoBrowser.executeInMainQueue({ self.createUserInterface() })
        }
        else
        {
            PhotoBrowser.executeInMainQueue({ self.dismiss(animated: true, completion: nil) })
        }
    }
    
    func createUserInterface()
    {
        assetCollections = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.albumRegular, options: nil)
        
        segmentedControlItems = [String]()
        
        for i in 0  ..< assetCollections.count 
        {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = Predicate(format: "mediaType = %i", PHAssetMediaType.image.rawValue)
            
            let assetsInCollection  = PHAsset.fetchAssets(in: assetCollections[i], options: fetchOptions)
            
            if assetsInCollection.count > 0 || assetCollections[i].localizedTitle == "Favorites"
            {
                if let localizedTitle = assetCollections[i].localizedTitle
                {
                    segmentedControlItems.append(localizedTitle)
                    
                    contentOffsets.append(CGPoint(x: 0, y: 0))
                }
            }
        }
        
        segmentedControlItems = segmentedControlItems.sorted { $0 < $1 }
        
        segmentedControl = UISegmentedControl(items: segmentedControlItems)
        segmentedControl.selectedSegmentIndex = photoBrowserSelectedSegmentIndex
        segmentedControl.addTarget(self, action: #selector(PhotoBrowser.segmentedControlChangeHandler), for: UIControlEvents.valueChanged)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = PhotoBrowserConstants.thumbnailSize
        layout.minimumLineSpacing = 30
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        collectionViewWidget = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        
        collectionViewWidget.backgroundColor = UIColor.clear()
        
        collectionViewWidget.delegate = self
        collectionViewWidget.dataSource = self
        collectionViewWidget.register(ImageItemRenderer.self, forCellWithReuseIdentifier: "Cell")
        collectionViewWidget.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
   
    if UIApplication.shared().keyWindow?.traitCollection.forceTouchCapability == UIForceTouchCapability.available
    {
        registerForPreviewing(with: self, sourceView: view)
    }
    else
    {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(PhotoBrowser.longPressHandler(_:)))
        collectionViewWidget.addGestureRecognizer(longPress)
    }
            
        background.layer.borderColor = UIColor.darkGray().cgColor
        background.layer.borderWidth = 1
        background.layer.cornerRadius = 5
        background.layer.masksToBounds = true
        
        view.addSubview(background)
        
        background.addSubview(blurOverlay)
        background.addSubview(collectionViewWidget)
        background.addSubview(segmentedControl)
        
        view.backgroundColor = UIColor(white: 0.15, alpha: 0.85)
        
        activityIndicator.frame = CGRect(origin: CGPoint.zero, size: view.frame.size)
        view.addSubview(activityIndicator)
        
        segmentedControlChangeHandler()
        
        uiCreated = true
    }
    
    // MARK: User interaction handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        super.touchesBegan(touches, with: event)
        
        if let locationInView = touches.first?.location(in: view) where
            !background.frame.contains(locationInView)
        {
            dismiss(animated: true, completion: nil)
        }
    }
    
    func segmentedControlChangeHandler()
    {
        contentOffsets[photoBrowserSelectedSegmentIndex] = collectionViewWidget.contentOffset
        
        photoBrowserSelectedSegmentIndex = segmentedControl.selectedSegmentIndex
        
        let options = PHFetchOptions()
        options.sortDescriptors = [ SortDescriptor(key: "creationDate", ascending: false) ]
        options.predicate =  Predicate(format: "mediaType = %i", PHAssetMediaType.image.rawValue)
        
        for i in 0 ..< assetCollections.count
        {
            if segmentedControlItems[photoBrowserSelectedSegmentIndex] == assetCollections[i].localizedTitle
            {
                assets = PHAsset.fetchAssets(in: assetCollections[i], options: options)
                updateAssetsByDate()
                return
            }
        }
        
        selectedAsset = nil
    }
    
    func longPressHandler(_ recognizer: UILongPressGestureRecognizer)
    {
        guard let touchedCell = touchedCell,
            asset = assets[(touchedCell.indexPath as NSIndexPath).row] as? PHAsset where
            recognizer.state == UIGestureRecognizerState.began else
        {
            return
        }
        
        let contextMenuController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        let toggleFavouriteAction = UIAlertAction(title: asset.isFavorite ? "Remove Favourite" : "Make Favourite", style: UIAlertActionStyle.default, handler: toggleFavourite)
        
        contextMenuController.addAction(toggleFavouriteAction)
        
        if let popoverPresentationController = contextMenuController.popoverPresentationController
        {
            popoverPresentationController.sourceRect = collectionViewWidget.convert(touchedCell.cell.frame, to: self.view)
            
            popoverPresentationController.sourceView = view
        }
        
        present(contextMenuController, animated: true, completion: nil)
    }
    
    func toggleFavourite(_: UIAlertAction!) -> Void
    {
        if let touchedCell = touchedCell, targetEntity = assets[(touchedCell.indexPath as NSIndexPath).row] as? PHAsset
        {
            PHPhotoLibrary.shared().performChanges(
                {
                    let changeRequest = PHAssetChangeRequest(for: targetEntity)
                    changeRequest.isFavorite = !targetEntity.isFavorite
                },
                completionHandler: nil)
        }
    }
    
    // MARK: Image management
    
    func requestImageForAsset(_ asset: PHAsset)
    {
        activityIndicator.startAnimating()
        
        selectedAsset = asset
        
        manager.requestImage(for: asset,
            targetSize: returnImageSize,
            contentMode: PHImageContentMode.aspectFill,
            options: requestOptions,
            resultHandler: imageRequestResultHandler)
    }
    
    func imageRequestResultHandler(_ image: UIImage?, properties: [NSObject: AnyObject]?)
    {
        if let delegate = delegate, image = image, selectedAssetLocalIdentifier = selectedAsset?.localIdentifier
        {
            PhotoBrowser.executeInMainQueue
            {
                delegate.photoBrowserDidSelectImage(image, localIdentifier: selectedAssetLocalIdentifier)
            }
        }
        // TODO : Handle no image case (asset is broken in iOS)
        
        activityIndicator.stopAnimating()
        selectedAsset = nil
        dismiss(animated: true, completion: nil)
    }

    // MARK: System Layout
    
    override func viewDidLayoutSubviews()
    {
        if uiCreated
        {
            background.frame = view.frame.insetBy(dx: 50, dy: 50)
            activityIndicator.frame = view.frame.insetBy(dx: 50, dy: 50)
            blurOverlay.frame = CGRect(x: 0, y: 0, width: background.frame.width, height: background.frame.height)
            
            segmentedControl.frame = CGRect(x: 0, y: 0, width: background.frame.width, height: 40).insetBy(dx: 5, dy: 5)
            collectionViewWidget.frame = CGRect(x: 0, y: 40, width: background.frame.width, height: background.frame.height - 40)
        }
    }
    
    deinit
    {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    static func executeInMainQueue(_ function: () -> Void)
    {
        DispatchQueue.main.async(execute: function)
    }
}

// MARK: PHPhotoLibraryChangeObserver

extension PhotoBrowser: PHPhotoLibraryChangeObserver
{
    func photoLibraryDidChange(_ changeInstance: PHChange)
    {
        guard let assets = assets else
        {
            return
        }
        
        if let assetsAO = assets as? PHFetchResult<AnyObject>
        {
            if let changeDetails = changeInstance.changeDetails(for: assetsAO ) where uiCreated
            {
                PhotoBrowser.executeInMainQueue
                {
                    if let assetsAPH = changeDetails.fetchResultAfterChanges as? PHFetchResult<PHAsset>
                    {
                        self.assets = assetsAPH
                    }
                }
            }
        }
    }
}

// MARK: UICollectionViewDataSource

extension PhotoBrowser: UICollectionViewDataSource
{
    func numberOfSections(in collectionView: UICollectionView) -> Int
    {
        return assetsByDate.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return  assetsByDate[Array(assetsByDate.keys)[section]]!.count
    }
}

// MARK: UICollectionViewDelegate

extension PhotoBrowser: UICollectionViewDelegate
{
    @objc(collectionView:cellForItemAtIndexPath:) func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! ImageItemRenderer
        
//        let currentIndexPath = indexPath as NSIndexPath
        cell.asset = assetsByDate[Array(assetsByDate.keys)[indexPath.section]]?[indexPath.row] // assets[currentIndexPath.row]
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath)
    {
        touchedCell = (cell: self.collectionView(collectionViewWidget, cellForItemAt: indexPath), indexPath: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        requestImageForAsset(assets[(indexPath as NSIndexPath).row])
    }
    
    
    
//    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
//        if let previousItem = context.previouslyFocusedView as? ImageItemRenderer {
//            UIView.animate(withDuration: 0.2, animations: { () -> Void in
//                previousItem.frame.size = PhotoBrowserConstants.thumbnailSize
//                previousItem.imageView.clipsToBounds = true
//            })
//        }
//        if let nextItem = context.nextFocusedView as? ImageItemRenderer {
//            UIView.animate(withDuration: 0.2, animations: { () -> Void in
//                nextItem.frame.size = PhotoBrowserConstants.thumbnailHighlightSize
//                nextItem.imageView.clipsToBounds = false
//            })
//        }
//    }
}

// MARK:

extension PhotoBrowser: UIViewControllerPreviewingDelegate
{
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard let touchedCell = touchedCell else
        {
            return nil
        }
        
        let previewSize = min(view.frame.width, view.frame.height) * 0.8
        
        let peekController = PeekViewController(frame: CGRect(x: 0, y: 0,
            width: previewSize,
            height: previewSize))

        peekController.asset = assets[(touchedCell.indexPath as NSIndexPath).row]
        
        return peekController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        guard let touchedCell = touchedCell else
        {
            dismiss(animated: true, completion: nil)
            
            return
        }
        
        requestImageForAsset(assets[(touchedCell.indexPath as NSIndexPath).row])
    }
}

// MARK: PeekViewController

class PeekViewController: UIViewController
{
    let itemRenderer: ImageItemRenderer
    
    required init(frame: CGRect)
    {
        itemRenderer = ImageItemRenderer(frame: frame)
        
        super.init(nibName: nil, bundle: nil)
        
        preferredContentSize = frame.size
        
        view.addSubview(itemRenderer)
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
 
    func toggleFavourite()
    {
        if let targetEntity = asset
        {
            PHPhotoLibrary.shared().performChanges(
                {
                    let changeRequest = PHAssetChangeRequest(for: targetEntity)
                    changeRequest.isFavorite = !targetEntity.isFavorite
                },
                completionHandler: nil)
        }
    }
    
    var previewActions: [UIPreviewActionItem]
    {
        return [UIPreviewAction(title: asset!.isFavorite ? "Remove Favourite" : "Make Favourite",
            style: UIPreviewActionStyle.default,
            handler:
            {
                (previewAction, viewController) in (viewController as? PeekViewController)?.toggleFavourite()
            })]
    }
    
    var asset: PHAsset?
    {
        didSet
        {
            itemRenderer.asset = asset
        }
    }
}

// MARK: ActivityIndicator overlay

class ActivityIndicator: UIView
{
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
    let label = UILabel()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        addSubview(activityIndicator)
        addSubview(label)
        
        backgroundColor = UIColor(white: 0.15, alpha: 0.85)
        label.textColor = UIColor.white()
        label.textAlignment = NSTextAlignment.center
        
        label.text = "Loading..."
        
        stopAnimating()
    }

    override func layoutSubviews()
    {
        activityIndicator.frame = CGRect(origin: CGPoint.zero, size: frame.size)
        
        label.frame = CGRect(x: 0,
            y: label.intrinsicContentSize().height,
            width: frame.width,
            height: label.intrinsicContentSize().height)
    }
    
    func updateProgress(_ value: Double)
    {
        PhotoBrowser.executeInMainQueue
        {
            self.label.text = "Loading \(Int(value * 100))%"
        }
    }
    
    func startAnimating()
    {
        activityIndicator.startAnimating()
        
        Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(ActivityIndicator.show), userInfo: nil, repeats: false)
    }
    
    func show()
    {
        PhotoBrowser.executeInMainQueue
        {
            self.label.text = "Loading..."
            self.isHidden = false
        }
    }
    
    func stopAnimating()
    {
        isHidden = true
        activityIndicator.stopAnimating()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PhotoBrowserConstants
{
    static let thumbnailSize = CGSize(width: 256, height: 256)
    static let thumbnailHighlightSize = CGSize(width: 384, height: 384)
    static let animationDuration = 0.175
}
