//
//  InstantTrackerViewController.swift
//  MaxstARSampleSwift
//
//  Created by Kimseunglee on 2017. 12. 12..
//  Copyright © 2017년 Maxst. All rights reserved.
//

import UIKit
import Metal
import MetalKit
import MaxstARSDKFramework

class InstantFusionTrackerViewController: UIViewController, MTKViewDelegate {

    var cameraDevice:MasCameraDevice = MasCameraDevice()
    var trackingManager:MasTrackerManager = MasTrackerManager()
    var cameraResultCode:MasResultCode = MasResultCode.CameraPermissionIsNotResolved
    
    var textureCube:TextureCube! = nil
    var backgroundCameraQuad:BackgroundCameraQuad?
    
    @IBOutlet var metalView: MTKView!
    var commandQueue:MTLCommandQueue?
    var device:MTLDevice!
    
    var screenSizeWidth:Float = 0.0
    var screenSizeHeight:Float = 0.0
    
    var panTranslateX:Float = 0.0
    var panTranslateY:Float = 0.0
    
    var beforeTranslateX:Float = 0.0
    var beforeTranslateY:Float = 0.0
    
    var touchFirstX:Float = 0.0
    var touchFirstY:Float = 0.0
    
    var pinchScale:Float = 0.0
    
    var rotateValue:Float = 0.0
    var rotationValue:Float = 0.0
    
    @IBOutlet weak var guideView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMetal()
       
        let maxstAR_cubePath = Bundle.main.path(forResource: "MaxstAR_Cube", ofType: "png", inDirectory: "data/Texture")!
        let maxst_CubeImage = UIImage(contentsOfFile: maxstAR_cubePath)!
        textureCube?.setTexture(textureImage: maxst_CubeImage)
        
        startEngine()
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseAR), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterBackgournd), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeAR), name: UIApplication.didBecomeActiveNotification, object: nil)
        // Do any additional setup after loading the view.
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pauseAR()
        trackingManager.destroyTracker()
        MasMaxstAR.deinit()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupMetal() {
        self.metalView?.delegate = self
        self.metalView?.device = MTLCreateSystemDefaultDevice()!
        self.device = self.metalView?.device
        self.commandQueue = device!.makeCommandQueue()
        
        textureCube = TextureCube(device: self.device)
        backgroundCameraQuad = BackgroundCameraQuad(device: self.device)
        
        screenSizeWidth = Float(UIScreen.main.nativeBounds.size.width)
        screenSizeHeight = Float(UIScreen.main.nativeBounds.size.height)
        
        MasMaxstAR.onSurfaceChanged(Int32(screenSizeWidth), height: Int32(screenSizeHeight))
    }
    
    
    @IBAction func doTrackingState(_ sender: Any) {
        let button:UIButton = sender as! UIButton
        
        if button.titleLabel?.text == "Start Tracking" {
            beforeTranslateX = 0.0
            beforeTranslateY = 0.0
            panTranslateX = 0.0
            panTranslateY = 0.0
            pinchScale = 0.0
            rotateValue = 0.0
            
            DispatchQueue.main.async {
                self.trackingManager.findSurface()
            }
            
            button.setTitle("Stop Tracking", for: .normal)
        } else if button.titleLabel?.text == "Stop Tracking" {
            trackingManager.quitFindingSurface()
            button.setTitle("Start Tracking", for: .normal)
        }
    }
    
    @IBAction func panScreen(_ sender: Any) {
        let pan:UIPanGestureRecognizer = sender as! UIPanGestureRecognizer
        let translation:CGPoint = pan.location(in: self.view)
        
        let x:CGFloat = translation.x
        let y:CGFloat = translation.y
        let resolutionWidth = UIScreen.main.nativeBounds.size.width
        let resolutionHeight = UIScreen.main.nativeBounds.size.height
        var realX:CGFloat = 0.0
        var realY:CGFloat = 0.0
        
        if UIDevice.current.orientation == UIDeviceOrientation.portrait {
            realX = (resolutionWidth/self.view.bounds.size.width) * x
            realY = (resolutionHeight/self.view.bounds.size.height) * y
        } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft {
            realX = (resolutionHeight/self.view.bounds.size.width) * x
            realY = (resolutionWidth/self.view.bounds.size.height) * y
        } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight {
            realX = resolutionHeight - (resolutionHeight/self.view.bounds.size.width) * x
            realY = resolutionWidth - (resolutionWidth/self.view.bounds.size.height) * y
        }
        
        var screenCoordinate:[Float] = [Float(realX), Float(realY)]
        var worldCoordinate:[Float] = [0.0, 0.0, 0.0]
        
        if pan.state == UIGestureRecognizer.State.began {
            trackingManager.getWorldPosition(fromScreenCoordinate: &screenCoordinate, world: &worldCoordinate)
            touchFirstX = worldCoordinate[0]
            touchFirstY = worldCoordinate[1]
        } else if pan.state == UIGestureRecognizer.State.changed {
            trackingManager.getWorldPosition(fromScreenCoordinate: &screenCoordinate, world: &worldCoordinate)
            
            panTranslateX = beforeTranslateX + worldCoordinate[0] - touchFirstX
            panTranslateY = beforeTranslateY + worldCoordinate[1] - touchFirstY
        } else if pan.state == UIGestureRecognizer.State.ended {
            beforeTranslateX = panTranslateX
            beforeTranslateY = panTranslateY
        }
    }
    
    @IBAction func rotateScreen(_ sender: Any) {
        let rotateRecognizer:UIRotationGestureRecognizer = sender as! UIRotationGestureRecognizer
        let rotation:CGFloat = rotateRecognizer.rotation
        rotateValue = Float( -(rotation * 90.0))
    }
    
    @IBAction func pinchScreen(_ sender: Any) {
        let pinchRecognizer:UIPinchGestureRecognizer = sender as! UIPinchGestureRecognizer
        let factor:CGFloat = pinchRecognizer.scale
        pinchScale = Float((factor - 1.0) / 2.0)
    }
    
    func startEngine() {
        MasMaxstAR.setLicenseKey("")
        setStatusBarOrientaionChange()
        if(trackingManager.isFusionSupported()) {
            cameraDevice.setFusionEnable()
            cameraResultCode = cameraDevice.start(0, width: 1920, height: 1440)
            trackingManager.start(.TRACKER_TYPE_INSTANT_FUSION)
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        _depthTexture = nil
    }
    
    func draw(in view: MTKView) {
        if let drawable = view.currentDrawable {
            let commandBuffer:MTLCommandBuffer = self.commandQueue!.makeCommandBuffer()!
            let renderPass:MTLRenderPassDescriptor = self.renderPassForDrawable(drawable: drawable)
            
            let commandEncoder:MTLRenderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)!
            
            let trackingState:MasTrackingState = trackingManager.updateTrackingState()
            let result:MasTrackingResult = trackingState.getTrackingResult()
            let fusionState = trackingManager.getFusionTrackingState()
            
            let backgroundImage:MasTrackedImage = trackingState.getImage()
            let backgroundProjectionMatrix:matrix_float4x4 = cameraDevice.getBackgroundPlaneProjectionMatrix()

            let projectionMatrix:matrix_float4x4 = cameraDevice.getProjectionMatrix()
        
            if let cameraQuad = backgroundCameraQuad {
                cameraQuad.setProjectionMatrix(projectionMatrix: backgroundProjectionMatrix)
                cameraQuad.draw(commandEncoder: commandEncoder, image: backgroundImage)
            }
            
            if fusionState == 1 {
                 DispatchQueue.main.async {
                     self.guideView.isHidden = true
                 }
             } else {
                 DispatchQueue.main.async {
                     self.guideView.isHidden = false
                 }
             }
            
            let trackingCount:Int32 = result.getCount()
            
            if trackingCount > 0 && fusionState == 1 {
                let trackable:MasTrackable = result.getTrackable(0)
                let poseMatrix:matrix_float4x4 = trackable.getPose()
                textureCube!.setProjectionMatrix(projectionMatrix: projectionMatrix)
                textureCube!.setPoseMatrix(poseMatrix: poseMatrix)
                textureCube!.setTranslation(x: panTranslateX, y:0.0 , z: panTranslateY)
                textureCube!.setScale(x: 0.1, y:  0.1, z: 0.00001)
                textureCube!.draw(commandEncoder: commandEncoder)
            }
            
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    var _depthTexture:MTLTexture?
    
    func renderPassForDrawable(drawable: CAMetalDrawable) -> MTLRenderPassDescriptor {
        let renderPass:MTLRenderPassDescriptor = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = drawable.texture
        renderPass.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPass.colorAttachments[0].storeAction = MTLStoreAction.store
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        
        if _depthTexture == nil {
            let textureDescriptor:MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: drawable.texture.width, height: drawable.texture.height, mipmapped: false)
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = .renderTarget
            
            _depthTexture = device?.makeTexture(descriptor: textureDescriptor)
        }
        
        renderPass.depthAttachment.texture = _depthTexture
        
        return renderPass
    }
    
    @objc func pauseAR() {
        trackingManager.quitFindingSurface()
        trackingManager.stopTracker()
        cameraDevice.stop()
    }
    
    @objc func enterBackgournd() {
        pauseAR()
    }
    
    @objc func resumeAR() {
        if(trackingManager.isFusionSupported()) {
            cameraDevice.setFusionEnable()
            cameraResultCode = cameraDevice.start(0, width: 1920, height: 1440)
            trackingManager.start(.TRACKER_TYPE_INSTANT_FUSION)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        setOrientaionChange()
    }
    
    func setOrientaionChange() {
        if UIDevice.current.orientation == UIDeviceOrientation.portrait {
            screenSizeWidth = Float(UIScreen.main.nativeBounds.size.width)
            screenSizeHeight = Float(UIScreen.main.nativeBounds.size.height)
            MasMaxstAR.setScreenOrientation(.PORTRAIT_UP)
        } else if UIDevice.current.orientation == UIDeviceOrientation.portraitUpsideDown {
            screenSizeWidth = Float(UIScreen.main.nativeBounds.size.width)
            screenSizeHeight = Float(UIScreen.main.nativeBounds.size.height)
            MasMaxstAR.setScreenOrientation(.PORTRAIT_DOWN)
        } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft {
            screenSizeWidth = Float(UIScreen.main.nativeBounds.size.height)
            screenSizeHeight = Float(UIScreen.main.nativeBounds.size.width)
            MasMaxstAR.setScreenOrientation(.LANDSCAPE_LEFT)
        } else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight {
            screenSizeWidth = Float(UIScreen.main.nativeBounds.size.height)
            screenSizeHeight = Float(UIScreen.main.nativeBounds.size.width)
            MasMaxstAR.setScreenOrientation(.LANDSCAPE_RIGHT)
        }
        
        MasMaxstAR.onSurfaceChanged(Int32(screenSizeWidth), height: Int32(screenSizeHeight))
        
    }
    
    func setStatusBarOrientaionChange() {
        let orientation:UIInterfaceOrientation = UIApplication.shared.statusBarOrientation
        
        if orientation == UIInterfaceOrientation.portrait {
            screenSizeWidth = Float(UIScreen.main.nativeBounds.size.width)
            screenSizeHeight = Float(UIScreen.main.nativeBounds.size.height)
            MasMaxstAR.setScreenOrientation(.PORTRAIT_UP)
        } else if orientation == UIInterfaceOrientation.portraitUpsideDown {
            screenSizeWidth = Float(UIScreen.main.nativeBounds.size.width)
            screenSizeHeight = Float(UIScreen.main.nativeBounds.size.height)
            MasMaxstAR.setScreenOrientation(.PORTRAIT_DOWN)
        } else if orientation == UIInterfaceOrientation.landscapeLeft {
            screenSizeWidth = Float(UIScreen.main.nativeBounds.size.height)
            screenSizeHeight = Float(UIScreen.main.nativeBounds.size.width)
            MasMaxstAR.setScreenOrientation(.LANDSCAPE_RIGHT)
        } else if orientation == UIInterfaceOrientation.landscapeRight {
            screenSizeWidth = Float(UIScreen.main.nativeBounds.size.height)
            screenSizeHeight = Float(UIScreen.main.nativeBounds.size.width)
            MasMaxstAR.setScreenOrientation(.LANDSCAPE_LEFT)
        }
        
        MasMaxstAR.onSurfaceChanged(Int32(screenSizeWidth), height: Int32(screenSizeHeight))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
