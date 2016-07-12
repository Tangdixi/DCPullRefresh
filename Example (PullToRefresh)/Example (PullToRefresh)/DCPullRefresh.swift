//
//  DCPullRefresh.swift
//  Example (PullToRefresh)
//
//  Created by tang dixi on 9/7/2016.
//  Copyright © 2016 Tangdixi. All rights reserved.
//

import UIKit

typealias DCRefreshControlHander = (()->Void)

enum DCRefreshControlState {
  
  case Idle
  case Ready
  case Charge
  case Refreshing
  case End
  
}

enum DCRefreshControlConstant {

  static let drawPathThreshold = CGFloat(64)
  static let onlyPathControlThreshold = CGFloat(120)
  static let color = UIColor(red: 140/255, green: 145/255, blue: 176/255, alpha: 1.0)
  
}

class DCRefreshControl: UIView {
  
  private weak var dcScrollView:UIScrollView!
  
  private var originContentInset:UIEdgeInsets!
  private var currentOffsetY = CGFloat(0)
  private var color:UIColor!
  
  var refreshControlState = DCRefreshControlState.Idle {
    didSet {
      if refreshControlState == oldValue {
        return
      }
    }
  }
  var refreshHandler:DCRefreshControlHander? = nil
  
  // MARK: - Initialization
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.opaque = false
    self.backgroundColor = UIColor.clearColor()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  convenience init(color:UIColor = DCRefreshControlConstant.color, refreshHandler: DCRefreshControlHander) {
    self.init(frame: CGRectZero)
    self.refreshHandler = refreshHandler
    self.color = color
  }
  
  override func willMoveToSuperview(newSuperview: UIView?) {
    
    super.willMoveToSuperview(newSuperview)
    
    // Make sure the superView is a scrollView
    //
    guard let newSuperview = newSuperview as? UIScrollView  else {
      
      removeObservers()
      return
      
    }
    
    dcScrollView = newSuperview
    dcScrollView.alwaysBounceVertical = true
    
    self.clipsToBounds = false
    self.frame = CGRect(origin: CGPointZero, size: CGSize(width: dcScrollView.frame.width, height: 0))
    
    configureObservers()
    
  }
  
  override func drawRect(rect: CGRect) {
    
    let path = UIBezierPath()
    path.moveToPoint(CGPointZero)
    
    switch refreshControlState {
    case .Idle:
      path.addLineToPoint(CGPoint(x: 0, y: self.frame.size.height))
      path.addLineToPoint(CGPoint(x: self.frame.size.width, y: self.frame.size.height))
    case .Ready:
      let controlPoint = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height)
      path.addLineToPoint(CGPoint(x: 0, y: abs(currentOffsetY)))
      path.addQuadCurveToPoint(CGPoint(x: self.frame.size.width, y: abs(currentOffsetY)), controlPoint: controlPoint)
    case .Charge:
      let controlPoint = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height)
      path.addLineToPoint(CGPoint(x: 0, y: DCRefreshControlConstant.onlyPathControlThreshold))
      path.addQuadCurveToPoint(CGPoint(x: self.frame.size.width, y: DCRefreshControlConstant.onlyPathControlThreshold), controlPoint: controlPoint)
    default:
      path.addLineToPoint(CGPoint(x: self.frame.size.width, y: self.frame.size.height))
    }
    
    path.addLineToPoint(CGPoint(x: self.frame.size.width, y: 0))
    path.closePath()
    
    let context = UIGraphicsGetCurrentContext()
    CGContextAddPath(context, path.CGPath)
    UIColor.redColor().set()
    CGContextFillPath(context)
    
  }
  
  // MARK: - KVO Stuff
  func configureObservers() {
    
    let options = NSKeyValueObservingOptions([.Old, .New])
    self.dcScrollView.addObserver(self, forKeyPath: "contentInset", options: options, context: nil)
    self.dcScrollView.addObserver(self, forKeyPath: "contentOffset", options: options, context: nil)
    
  }
  
  func removeObservers() {
    
    self.superview?.removeObserver(self, forKeyPath: "contentInset")
    self.superview?.removeObserver(self, forKeyPath: "contentOffset")
    
  }
  
  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    
    guard let keyPath = keyPath else { return }
    
    if keyPath == "contentInset" {

      guard let change = change else { return }
      guard let oldEdgeInset = change["old"]?.UIEdgeInsetsValue() else { return }
      guard let newEdgeInset = change["new"]?.UIEdgeInsetsValue() else { return }
      
      let condition = (originContentInset == nil) && (oldEdgeInset.top != newEdgeInset.top)
      
      if condition {
        originContentInset = change["new"]?.UIEdgeInsetsValue()
      }
      
    }

    if keyPath == "contentOffset" {
      
      guard let change = change else { return }
      scrollViewContentOffsetDidChanged(change)
    }
    
  }
  
  func scrollViewContentOffsetDidChanged(change:[String: AnyObject]) {
    
    guard let originContentInset = originContentInset else { return }
    
    // For example, a tableView will make a -64 offset in Y axis if there is a navigation bar
    //
    currentOffsetY = originContentInset.top + dcScrollView.contentOffset.y
    
    // When the tableView scroll to top, return immediately
    //
    guard currentOffsetY < 0 else { return }
    
    switch abs(currentOffsetY) {
    case let y where y > 0 && y < DCRefreshControlConstant.drawPathThreshold:
      refreshControlState = DCRefreshControlState.Idle
      
      self.frame = {
        let height = abs(currentOffsetY)
        let y = currentOffsetY
        return CGRectMake(0, y, dcScrollView.frame.width, height)
      }()
      
      self.setNeedsDisplay()
      
    case let y where y >= DCRefreshControlConstant.drawPathThreshold && y < DCRefreshControlConstant.onlyPathControlThreshold:
      refreshControlState = DCRefreshControlState.Ready
      
      print("offsetY:\(currentOffsetY)")
      
      self.frame = {
        let height = abs(currentOffsetY) + abs(currentOffsetY) - 64
        let y = currentOffsetY
        return CGRectMake(0, y, dcScrollView.frame.width, height)
      }()
      
      self.setNeedsDisplay()
      
    case let y where y >= DCRefreshControlConstant.onlyPathControlThreshold:
      refreshControlState = DCRefreshControlState.Charge
      
      let maxOffsetY = -(DCRefreshControlConstant.onlyPathControlThreshold + originContentInset.top)
      dcScrollView.setContentOffset(CGPoint(x: 0, y: maxOffsetY), animated: false)
      
      self.setNeedsDisplay()
      
    default:
      return
    }
    
  }
  
}

extension UIScrollView {
  
  private struct AssociatedKey {
    static var dcRefreshControlName = "dcRefreshControlName"
  }
  
  var dcRefreshControl:DCRefreshControl? {
    set {
      if let newValue = newValue {
        self.addSubview(newValue)
        objc_setAssociatedObject(self, AssociatedKey.dcRefreshControlName, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      }
    }
    get {
      guard let refreshControl = objc_getAssociatedObject(self, &AssociatedKey.dcRefreshControlName) as? DCRefreshControl else { return nil }
      return refreshControl
    }
  }
  
}
