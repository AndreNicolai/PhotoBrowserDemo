//
//  ViewController.swift
//  PhotoKitExperiments
//
//  Created by MaxShining on 28/07/16.
//  Copyright © 2016 André Nicolai. All rights reserved.
//

import UIKit

class ViewController: UIViewController , PhotoBrowserDelegate
{
    let photoBrowser = PhotoBrowser(returnImageSize: CGSize(width: 640, height: 640))
    let launchBrowserButton = UIButton(type: UIButtonType.system)
    let imageView: UIImageView = UIImageView(frame: CGRect.zero)
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black()
        
        launchBrowserButton.setTitle("Launch Photo Browser", for: UIControlState())
        launchBrowserButton.addTarget(self, action: #selector(ViewController.launchPhotoBrowser), for: UIControlEvents.primaryActionTriggered)
        
        imageView.layer.borderColor = UIColor.white().cgColor
        imageView.layer.borderWidth = 2
        
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        
        view.addSubview(imageView)
        view.addSubview(launchBrowserButton)
    }
    
    func launchPhotoBrowser()
    {
        photoBrowser.delegate = self
        
        photoBrowser.launch()
    }
    
    func photoBrowserDidSelectImage(_ image: UIImage, localIdentifier: String)
    {
        imageView.image = image
    }
    
    override func viewDidLayoutSubviews()
    {
        let topMargin = topLayoutGuide.length
        let imageViewSide = min(view.frame.width, view.frame.height - topMargin) - 75
        
        imageView.frame = CGRect(x: view.frame.width / 2 - imageViewSide / 2,
                                 y: view.frame.height / 2 - imageViewSide / 2,
                                 width: imageViewSide,
                                 height: imageViewSide)
        
        launchBrowserButton.frame = CGRect(x: 0, y: view.frame.height - 40, width: view.frame.width, height: 40)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

