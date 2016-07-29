//
//  ImageItemRenderer.swift
//  PHImageManagerTwitterDemo
//
//  Created by Simon Gladman on 31/12/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//

import UIKit
import Photos

class ImageItemRenderer: UICollectionViewCell, PHPhotoLibraryChangeObserver
{
    let label = UILabel(frame: CGRect.zero)
    let imageView = UIImageView(frame: CGRect.zero)
    let blurOverlay = UIVisualEffectView(effect: UIBlurEffect())
    
    let manager = PHImageManager.default()
    let deliveryOptions = PHImageRequestOptionsDeliveryMode.opportunistic
    let requestOptions = PHImageRequestOptions()
    
    let priority = DispatchQueue.GlobalAttributes.qosDefault
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        requestOptions.deliveryMode = deliveryOptions
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.exact
        
        contentView.layer.cornerRadius = 5
        contentView.layer.masksToBounds = true
        
        label.numberOfLines = 0
  
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = NSTextAlignment.center
        
        contentView.addSubview(imageView)
        contentView.addSubview(blurOverlay)
        contentView.addSubview(label)
        
        layer.borderColor = UIColor.darkGray().cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 5
        
        PHPhotoLibrary.shared().register(self)
    }
    
    override func layoutSubviews()
    {
        imageView.frame = bounds
        
        let labelFrame = CGRect(x: 0, y: frame.height - 20, width: frame.width, height: 20)
        
        blurOverlay.frame = labelFrame
        label.frame = labelFrame
    }
    
    deinit
    {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    var asset: PHAsset?
    {
        didSet
        {
            if let asset = asset
            {
                DispatchQueue.global(attributes: priority).async
                {
                    self.setLabel()
                    self.manager.requestImage(for: asset,
                        targetSize: self.frame.size,
                        contentMode: PHImageContentMode.aspectFill,
                        options: self.requestOptions,
                        resultHandler: self.requestResultHandler)
                }
            }
        }
    }
    
    func setLabel()
    {
        if let asset = asset, creationDate = asset.creationDate
        {
            let text = (asset.isFavorite ? "★ " : "") + DateFormatter.localizedString(from: creationDate, dateStyle: DateFormatter.Style.medium, timeStyle: DateFormatter.Style.none)
            
            PhotoBrowser.executeInMainQueue({self.label.text = text})
        }
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange)
    {
        DispatchQueue.main.async(execute: { self.setLabel() })
    }

    func requestResultHandler (_ image: UIImage?, properties: [NSObject: AnyObject]?) -> Void
    {
        PhotoBrowser.executeInMainQueue({self.imageView.image = image})
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
}

