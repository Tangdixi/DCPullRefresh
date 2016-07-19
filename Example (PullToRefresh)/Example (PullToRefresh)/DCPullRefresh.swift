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
  case Charging
  case Refreshing
  case End
  
}

// MARK: - Constants
enum DCRefreshControlConstant {

  static let drawPathThreshold = CGFloat(64)
  static let beginRefreshingThreshold = CGFloat(116)
  static let color = UIColor(red: 140/255, green: 145/255, blue: 176/255, alpha: 1.0)
  
  static let ballLayerTransformKeyFrame = (11, 16)
  static let ballLayerTransformLastKeyFrame = 17
  static let circlePathLayerTransformKeyFrame = (17, 60)
  
}

class DCRefreshControl: UIView {
  
  // Reference to self.superView, keep it with a weak attribute for avoiding memory leak
  //
  private weak var mirrorSuperView:UIScrollView!
  
  private var displayLink:CADisplayLink!
  private var originContentInset:UIEdgeInsets!
  private var currentOffsetY = CGFloat(0)
  private var color:UIColor!
  private var panGestureRecognizer:UIPanGestureRecognizer!
  
  private var isAnimating = false
  private var ballLayer:CAShapeLayer!
  private var controlPointAssociateView:UIView!
  private var controlPoint:CGPoint!
  private var frameCount:Int = 0
  private var transformPathAssociatePoint:CGPoint!
  private var circlePathLayer:CAShapeLayer!
  
  private var queue:NSOperationQueue!
  
  var refreshControlState = DCRefreshControlState.Idle
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
      
      /* The view will be destroied, cancel all executing operation */
      guard let queue = queue else { return }
      queue.cancelAllOperations()
      
      return
      
    }
    
    mirrorSuperView = newSuperview
    mirrorSuperView.alwaysBounceVertical = true
    
    panGestureRecognizer = mirrorSuperView.panGestureRecognizer
    
    self.frame = CGRect(origin: CGPointZero, size: CGSize(width: mirrorSuperView.frame.width, height: 0))
    
    configureObservers()
    
  }
  
  // MARK: - Drawing
  override func drawRect(rect: CGRect) {
    
    let path = UIBezierPath()
    path.moveToPoint(CGPointZero)
    
    switch refreshControlState {
    case .Idle:
      path.addLineToPoint(CGPoint(x: 0, y: self.frame.size.height))
      path.addLineToPoint(CGPoint(x: self.frame.size.width, y: self.frame.size.height))
    case .Charging:
      controlPoint = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height + abs(currentOffsetY) - DCRefreshControlConstant.drawPathThreshold)
      path.addLineToPoint(CGPoint(x: 0, y: abs(currentOffsetY)))
      path.addQuadCurveToPoint(CGPoint(x: self.frame.size.width, y: abs(currentOffsetY)), controlPoint: controlPoint)
      
    case .Refreshing:
      path.addLineToPoint(CGPoint(x: 0, y: abs(currentOffsetY)))
      path.addQuadCurveToPoint(CGPoint(x: self.frame.size.width, y: abs(currentOffsetY)), controlPoint: controlPoint)
    
    default:
      path.addLineToPoint(CGPoint(x: self.frame.size.width, y: self.frame.size.height))
    }
    
    path.addLineToPoint(CGPoint(x: self.frame.size.width, y: 0))
    path.closePath()
    
    let context = UIGraphicsGetCurrentContext()
    CGContextAddPath(context, path.CGPath)
    self.color.set()
    CGContextFillPath(context)
    
    /* Ball layer begin transforming */
    let ballLayerTransforming = (frameCount > DCRefreshControlConstant.ballLayerTransformKeyFrame.0) && (frameCount <= DCRefreshControlConstant.ballLayerTransformKeyFrame.1)
    
    if ballLayerTransforming == true {
      
      /* Disable the implicit animation in CALayer */
      CATransaction.setDisableActions(true)
      
      /* There are 12, 9, 6, 3 and finally it stay at abs(currentOffsetY)/2 */
      ballLayer.setCenter(CGPoint(x: controlPoint.x, y: abs(currentOffsetY)*(3/5)-CGFloat(frameCount-DCRefreshControlConstant.ballLayerTransformKeyFrame.0)*1))
      
      if transformPathAssociatePoint == nil {
        transformPathAssociatePoint = ballLayer.center
      }
      
//      let topLeftPoint = CGPoint(x: ballLayer.frame.origin.x, y: ballLayer.center.y)
      
      let topLeftPoint:CGPoint = {
        let x = self.frame.size.width/2-sqrt(CGFloat(powf(Float(ballLayer.frame.size.width/2), 2)-powf(Float(transformPathAssociatePoint.y-ballLayer.center.y), 2)))
        let y = transformPathAssociatePoint.y

        return CGPoint(x: x, y: y)
      }()
      
      let bottomLeftPoint:CGPoint = {
        
        let x = min(topLeftPoint.x - (CGFloat(DCRefreshControlConstant.ballLayerTransformKeyFrame.1-frameCount)*3), self.ballLayer.frame.origin.x-5)

        let lowerBounds = Int((abs(currentOffsetY)+controlPoint.y)/2)
        let upperBounds = Int(abs(currentOffsetY))
        guard let point = path.crossPointAt(x, range: (lowerBounds, upperBounds)) else { fatalError() }
        
        return CGPoint(x: point.x, y: point.y+2)
        
      }()
      let bottomRightPoint = CGPoint(x: self.frame.size.width - bottomLeftPoint.x, y: bottomLeftPoint.y)
      let topRightPoint = CGPoint(x: self.frame.size.width-topLeftPoint.x, y: topLeftPoint.y)
      
      let leftControlPoint = CGPoint(x: topLeftPoint.x+CGFloat(frameCount-DCRefreshControlConstant.ballLayerTransformKeyFrame.0)*3 , y: bottomLeftPoint.y-CGFloat(frameCount-DCRefreshControlConstant.ballLayerTransformKeyFrame.0)*1.8)
      let rightControlPoint = CGPoint(x: topRightPoint.x-CGFloat(frameCount-DCRefreshControlConstant.ballLayerTransformKeyFrame.0)*3, y: bottomLeftPoint.y-CGFloat(frameCount-DCRefreshControlConstant.ballLayerTransformKeyFrame.0)*1.8)
      
//      print("\(topLeftPoint)\n ||\(leftControlPoint)\n\(bottomLeftPoint)\n\(topRightPoint)\n ||\(rightControlPoint)\n\(bottomRightPoint)\n")
      
      let path = UIBezierPath()
      path.moveToPoint(topLeftPoint)
      path.addQuadCurveToPoint(bottomLeftPoint, controlPoint: leftControlPoint)
      path.addLineToPoint(bottomRightPoint)
      path.addQuadCurveToPoint(topRightPoint, controlPoint: rightControlPoint)
      path.closePath()
      
      let context = UIGraphicsGetCurrentContext()
      CGContextAddPath(context, path.CGPath)
      UIColor.whiteColor().set()
      CGContextFillPath(context)
      
      /*
       Debug:
       UIColor.redColor().setStroke()
       path.stroke()
       */
    }
    
    /* Ball layer transform completed */
    let ballLayerDidTransformed = (frameCount == DCRefreshControlConstant.ballLayerTransformLastKeyFrame)
    
    if ballLayerDidTransformed == true {
      
      CATransaction.setDisableActions(true)
      ballLayer.setCenter(CGPoint(x: controlPoint.x, y: abs(currentOffsetY)*(3/5)-CGFloat(frameCount-DCRefreshControlConstant.ballLayerTransformKeyFrame.0)*1))
      
      let bottomLeft:CGPoint = {
        let x = ballLayer.frame.origin.x-5
        let lowerBounds = Int((abs(currentOffsetY)+controlPoint.y)/2)
        let upperBounds = Int(abs(currentOffsetY))
        guard let point = path.crossPointAt(x, range: (lowerBounds, upperBounds)) else { fatalError() }
        return CGPoint(x: point.x, y: point.y+1)
      }()
      let bottomRight = CGPoint(x: self.frame.size.width-bottomLeft.x, y: bottomLeft.y)
      let topControlPoint = CGPoint(x: self.frame.size.width/2, y: bottomLeft.y-12)
      
      let path = UIBezierPath()
      path.moveToPoint(bottomLeft)
      path.addQuadCurveToPoint(bottomRight, controlPoint: topControlPoint)
      path.closePath()
      
      let context = UIGraphicsGetCurrentContext()
      CGContextAddPath(context, path.CGPath)
      UIColor.whiteColor().set()
      CGContextFillPath(context)

    }
    
    /* Circle layer begin transforming */
    let circleLayerTransforming = (frameCount >= DCRefreshControlConstant.circlePathLayerTransformKeyFrame.0) && (frameCount <= DCRefreshControlConstant.circlePathLayerTransformKeyFrame.1)
    
    if circleLayerTransforming == true {
      
      circlePathLayer.setCenter(ballLayer.center)
      
      let percentage = CGFloat(frameCount-DCRefreshControlConstant.circlePathLayerTransformKeyFrame.0+1)
      let total = CGFloat(DCRefreshControlConstant.circlePathLayerTransformKeyFrame.1-DCRefreshControlConstant.circlePathLayerTransformKeyFrame.0)
      
      CATransaction.setDisableActions(true)
      circlePathLayer.strokeEnd = percentage/total

//      print("\(percentage)/\(total)=\(percentage/total)")
      
    }
    
  }
  
  // MARK: - Ball Layer Animation
  func performBallLayerAnimation() {
    
    isAnimating = true
    
    ballLayerAnimationWillAppear()
    
    UIView.animateWithDuration(0.7, delay: 0, usingSpringWithDamping: 0.12, initialSpringVelocity: 2, options: .CurveEaseOut,
    animations: {
      
      self.controlPointAssociateView.center = CGPoint(x: self.frame.size.width/2, y: abs(self.currentOffsetY))
      
    },
    completion: { finished in
      
      let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.3 * Double(NSEC_PER_SEC)))
      dispatch_after(delayTime, dispatch_get_main_queue()) {
        
        self.ballLayerAnimationDidEnd()
        
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.3 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
          
          self.performCircleLayerAnimation()
          
        }
        
      }
      
    })
    
  }

  func ballLayerAnimationWillAppear() {
    
    if displayLink == nil {
      displayLink = CADisplayLink(target: self, selector: #selector(displayLinkHandler))
      displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
      
      frameCount = 0
    }
    
    controlPointAssociateView = {
      let view = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
      view.center = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height)
      view.backgroundColor = UIColor.clearColor()
      return view
    }()
    self.addSubview(controlPointAssociateView)
    
    ballLayer = {
      let layer = CAShapeLayer()
      layer.frame = CGRect(x: 0, y: 0, width: 38, height: 38)
      layer.setCenter(CGPoint(x: self.frame.size.width/2, y: self.frame.size.height * 2))
      
      let path = UIBezierPath()
      path.addArcWithCenter(layer.middle, radius: 19, startAngle: 0, endAngle: CGFloat(M_PI)*2, clockwise: true)
      
      layer.path = path.CGPath
      layer.fillColor = UIColor.whiteColor().CGColor
      
      return layer
    }()
    self.layer.addSublayer(ballLayer)
    
    circlePathLayer = {
      
      let layer = CAShapeLayer()
      layer.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
      layer.setCenter(CGPoint(x: self.frame.size.width/2, y: self.frame.size.height * 2))
      
      let path = UIBezierPath()
      path.addArcWithCenter(layer.middle, radius: 22, startAngle: CGFloat(M_PI)/2, endAngle: CGFloat(M_PI)*5/2, clockwise: true)
      
      layer.path = path.CGPath
      layer.lineWidth = 2
      layer.fillColor = UIColor.clearColor().CGColor
      layer.strokeColor = UIColor.whiteColor().CGColor
      
      return layer
    }()
    self.layer.addSublayer(circlePathLayer)
    
  }
  
  func ballLayerAnimationDidEnd() {
    
    self.displayLink.invalidate()
    self.displayLink = nil
    controlPointAssociateView.removeFromSuperview()
    
  }
  
  func displayLinkHandler() {
    
    guard let controlPointLayer = controlPointAssociateView.layer.presentationLayer() else { return }
    controlPoint = controlPointLayer.center
    
//    print("\(frameCount):\(controlPoint)")
    
    frameCount += 1
    
    self.setNeedsDisplay()
    
  }
  
  // MARK: - Circle Layer Animation
  func performCircleLayerAnimation() {
    
    let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
    scaleAnimation.fromValue = 1.0
    scaleAnimation.toValue = 1.5
    
    let alphaAnimation = CABasicAnimation(keyPath: "opacity")
    alphaAnimation.fromValue = 1.0
    alphaAnimation.toValue = 0
    
    let animationGroup = CAAnimationGroup()
    animationGroup.duration = 1
    animationGroup.animations = [scaleAnimation, alphaAnimation]
    animationGroup.repeatCount = Float.infinity
    animationGroup.fillMode = kCAFillModeForwards
    
    circlePathLayer.addAnimation(animationGroup, forKey: nil)
    
    guard let refreshHandler = refreshHandler else { fatalError() }
    performRefreshHandler(refreshHandler)
    
  }
  
  func circleLayerAnimationDidEnd() {
    
    circlePathLayer.removeAllAnimations()
    circlePathLayer.removeFromSuperlayer()
    
  }
  
  // MARK: - Layer dismiss
  
  func performDismissAnimation() {
    
    UIView.animateWithDuration(0.7, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .CurveEaseIn,
    animations: {
      
      
      
    },
    completion: { finished in
      
    })
    
  }
  
  func dismissAnimationWillAppear() {
    
    if displayLink == nil {
      displayLink = CADisplayLink(target: self, selector: #selector(displayLinkHandler))
      displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
      
      frameCount = 0
    }

  }
  
  // MARK: -The User's completion handler
  func performRefreshHandler(handler:DCRefreshControlHander) {
    
    if queue == nil {
      queue = NSOperationQueue()
    }

    /* Perform the handler in background queue */
    queue.addOperationWithBlock {
      handler()
      /* Always up  date the UI in main queue */
      NSOperationQueue.mainQueue().addOperationWithBlock {
        self.circleLayerAnimationDidEnd()
      }
    }
    
  }
  
  // MARK: - KVO
  func configureObservers() {
    
    let options = NSKeyValueObservingOptions([.Old, .New])
    self.mirrorSuperView.addObserver(self, forKeyPath: "contentInset", options: options, context: nil)
    self.mirrorSuperView.addObserver(self, forKeyPath: "contentOffset", options: options, context: nil)
    self.panGestureRecognizer.addObserver(self, forKeyPath: "state", options: options, context: nil)
    
  }
  
  func removeObservers() {
    
    self.superview?.removeObserver(self, forKeyPath: "contentInset")
    self.superview?.removeObserver(self, forKeyPath: "contentOffset")
    self.panGestureRecognizer.removeObserver(self, forKeyPath: "state")
    
  }
  
  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    
    guard let keyPath = keyPath else { return }
    guard let change = change else { return }
    
    if keyPath == "contentInset" {
      
      guard let oldEdgeInset = change["old"]?.UIEdgeInsetsValue() else { return }
      guard let newEdgeInset = change["new"]?.UIEdgeInsetsValue() else { return }
      
      let condition = (originContentInset == nil) && (oldEdgeInset.top != newEdgeInset.top)
      
      if condition {
        originContentInset = change["new"]?.UIEdgeInsetsValue()
      }
      
    }

    if keyPath == "contentOffset" {
      
      scrollViewContentOffsetDidChanged(change)
    }
    
    if keyPath == "state" {
      
      panGestureRecognizerStateDidChanged(change)
      
    }
    
  }
  
  func panGestureRecognizerStateDidChanged(change:[String: AnyObject]) {
    
    guard let newState = change["new"]?.integerValue else { return }
    
    let condition = (self.refreshControlState == .Refreshing) && (newState == UIGestureRecognizerState.Ended.rawValue) && (isAnimating == false)
    
    if condition == true {
      
      let maxOffsetY = DCRefreshControlConstant.beginRefreshingThreshold + originContentInset.top
      mirrorSuperView.contentInset = UIEdgeInsets(top: maxOffsetY, left: 0, bottom: 0, right: 0)
      
      performBallLayerAnimation()
    }
    
  }
  
  func scrollViewContentOffsetDidChanged(change:[String: AnyObject]) {
    
    guard let originContentInset = originContentInset else { return }
    
    /* For example, a tableView will make a -64 offset in Y axis if there is a navigation bar */
    
    currentOffsetY = originContentInset.top + mirrorSuperView.contentOffset.y
    
    /* When the tableView scroll to top, return immediately */
    
    guard currentOffsetY < 0 else { return }
    
    /* Prevent some naughty guy */
    
    if refreshControlState == .Refreshing {
      self.frame = {
        let height = abs(currentOffsetY) + abs(currentOffsetY) - DCRefreshControlConstant.drawPathThreshold
        let y = currentOffsetY
        return CGRectMake(0, y, mirrorSuperView.frame.width, height)
      }()
      
      let maxOffsetY = DCRefreshControlConstant.beginRefreshingThreshold + originContentInset.top
      mirrorSuperView.setContentOffset(CGPoint(x: 0, y: -maxOffsetY), animated: false)
    }
    
    switch abs(currentOffsetY) {
  
    case let y where y > 0 && y < DCRefreshControlConstant.drawPathThreshold:
      
      refreshControlState = DCRefreshControlState.Idle
      
      self.frame = {
        let height = abs(currentOffsetY)
        let y = currentOffsetY
        return CGRectMake(0, y, mirrorSuperView.frame.width, height)
      }()
      
      self.setNeedsDisplay()

    case let y where y >= DCRefreshControlConstant.drawPathThreshold && y < DCRefreshControlConstant.beginRefreshingThreshold:
      refreshControlState = DCRefreshControlState.Charging
      
      self.frame = {
        let height = abs(currentOffsetY) + abs(currentOffsetY) - DCRefreshControlConstant.drawPathThreshold
        let y = currentOffsetY
        return CGRectMake(0, y, mirrorSuperView.frame.width, height)
      }()
      
      self.setNeedsDisplay()
      
    case let y where y >= DCRefreshControlConstant.beginRefreshingThreshold:
      refreshControlState = DCRefreshControlState.Refreshing
      
      self.frame = {
        let height = abs(currentOffsetY) + abs(currentOffsetY) - DCRefreshControlConstant.drawPathThreshold
        let y = currentOffsetY
        return CGRectMake(0, y, mirrorSuperView.frame.width, height)
      }()
      
      let maxOffsetY = DCRefreshControlConstant.beginRefreshingThreshold + originContentInset.top
      mirrorSuperView.setContentOffset(CGPoint(x: 0, y: -maxOffsetY), animated: false)
      
    default:
      return
    }
    
  }
  
}

// MARK: - Convenience

extension UIBezierPath {
  
  func crossPointAt(x: CGFloat, range:(Int, Int)) -> CGPoint? {
    
    for y in range.0...range.1 {
      let point = CGPoint(x: x, y: CGFloat(y))
      if self.containsPoint(point) {
        return point
      }
    }
    return nil
    
  }
  
  func crossPointAt(x: CGFloat) -> CGPoint? {
    
    let upperBounds = Int(self.bounds.origin.y + self.bounds.size.height)
    let lowerBounds = Int(self.topPoint.y)
    
    return self.crossPointAt(x, range: (lowerBounds, upperBounds))
  }
 
  var topPoint:CGPoint {
    return CGPoint(x: self.bounds.size.width/2, y: self.bounds.origin.y)
  }

}

extension CALayer {
  
  var middle:CGPoint {
    return CGPoint(x: self.frame.size.width/2, y: self.frame.size.height/2)
  }
  
  var center:CGPoint {
    return CGPoint(x: self.frame.origin.x + self.frame.size.width/2, y: self.frame.origin.y + self.frame.size.height/2)
  }
  
  func setCenter(point: CGPoint) {
    self.frame.origin = CGPoint(x: point.x - self.frame.size.width/2, y: point.y - self.frame.size.height/2)
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
