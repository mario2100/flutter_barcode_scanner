import Flutter
import UIKit
import AVFoundation

public class SwiftFlutterBarcodeScannerPlugin: NSObject, FlutterPlugin, ScanBarcodeDelegate {
    public static var viewController = UIViewController()
    public static var lineColor:String=""
    public static var cancelButtonText:String=""
    public static var isShowFlashIcon:Bool=false
    var pendingResult:FlutterResult!
    public static func register(with registrar: FlutterPluginRegistrar) {
        viewController = (UIApplication.shared.delegate?.window??.rootViewController)!
        let channel = FlutterMethodChannel(name: "flutter_barcode_scanner", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterBarcodeScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        var args:Dictionary<String, AnyObject> = call.arguments as! Dictionary<String, AnyObject>;
        if let colorCode = args["lineColor"] as? String{
            SwiftFlutterBarcodeScannerPlugin.lineColor = colorCode
        }else {
            SwiftFlutterBarcodeScannerPlugin.lineColor = "#ff6666"
        }
        if let buttonText = args["cancelButtonText"] as? String{
            SwiftFlutterBarcodeScannerPlugin.cancelButtonText = buttonText
        }else {
            SwiftFlutterBarcodeScannerPlugin.cancelButtonText = "Cancel"
        }
        if let flashStatus = args["isShowFlashIcon"] as? Bool{
            SwiftFlutterBarcodeScannerPlugin.isShowFlashIcon = flashStatus
        }else {
            SwiftFlutterBarcodeScannerPlugin.isShowFlashIcon = false
        }
        
        pendingResult=result
        let controller = BarcodeScannerViewController()
        controller.delegate = self
        SwiftFlutterBarcodeScannerPlugin.viewController.present(controller
        , animated: true) {
            
        }
    }
    
    public func userDidScanWith(barcode: String){
        pendingResult(barcode)
    }
}

protocol ScanBarcodeDelegate {
    func userDidScanWith(barcode: String)
}

class BarcodeScannerViewController: UIViewController {
    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]
    public var delegate: ScanBarcodeDelegate? = nil
    private var captureSession = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var qrCodeFrameView: UIView?
    private var scanlineRect = CGRect.zero
    private var scanlineStartY: CGFloat = 0
    private var scanlineStopY: CGFloat = 0
    private var topBottomMargin: CGFloat = 80
    private var scanLine: UIView = UIView()
    let screenSize = UIScreen.main.bounds
    private lazy var xCor: CGFloat! = {
        return (screenSize.width - (screenSize.width*0.8))/2
    }()
    private lazy var yCor: CGFloat! = {
        return (screenSize.height - (screenSize.width*0.8))/2
    }()
    //Bottom view
    private lazy var bottomView : UIView! = {
        let view = UIView()
        view.backgroundColor = UIColor.black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var flashIcon : UIButton! = {
        let flashButton = UIButton()
        flashButton.setTitle("Flash",for:.normal)
        flashButton.translatesAutoresizingMaskIntoConstraints=false
        
        flashButton.setImage(UIImage(named: "ic_flash_on", in: Bundle(identifier: "org.cocoapods.flutter-barcode-scanner"), compatibleWith: nil),for:.normal)
        
        flashButton.addTarget(self, action: #selector(BarcodeScannerViewController.flashButtonClicked), for: .touchUpInside)
        
        return flashButton
    }()
    
    
    
    public lazy var cancelButton: UIButton! = {
        let view = UIButton()
        view.setTitle(SwiftFlutterBarcodeScannerPlugin.cancelButtonText, for: .normal)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addTarget(self, action: #selector(BarcodeScannerViewController.playButtonClicked), for: .touchUpInside)
        return view
    }()
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        let captureMetadataOutput = AVCaptureMetadataOutput()
        setConstraintsForControls()
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        // Get the back-facing camera for capturing videos
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Set the input device on the capture session.
            if captureSession.inputs.isEmpty {
                captureSession.addInput(input)
            }
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            
            captureMetadataOutput.rectOfInterest = CGRect(x: xCor, y: yCor, width: (screenSize.width*0.8), height: (screenSize.width*0.8))
            if captureSession.outputs.isEmpty {
                captureSession.addOutput(captureMetadataOutput)
            }
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            //            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        
        let overlayPath = UIBezierPath(rect: view.bounds)
        
        let transparentPath = UIBezierPath(rect: CGRect(x: xCor, y: yCor, width: (screenSize.width*0.8), height: (screenSize.width*0.8)))
        overlayPath.append(transparentPath)
        overlayPath.usesEvenOddFillRule = true
        let fillLayer = CAShapeLayer()
        
        fillLayer.path = overlayPath.cgPath
        fillLayer.fillRule = CAShapeLayerFillRule.evenOdd
        fillLayer.fillColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor
        
        view.layer.addSublayer(videoPreviewLayer!)
        
        
        // Start video capture.
        captureSession.startRunning()
        let scanRect = CGRect(x: xCor, y: yCor, width: (screenSize.width*0.8), height: (screenSize.width*0.8))
        let rectOfInterest = videoPreviewLayer?.metadataOutputRectConverted(fromLayerRect: scanRect)
        if let rOI = rectOfInterest{
            captureMetadataOutput.rectOfInterest = rOI
        }
        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()
        qrCodeFrameView!.frame = CGRect(x: 0, y: 0, width: (screenSize.width), height: (screenSize.width))
        
        if let qrCodeFrameView = qrCodeFrameView {
            self.view.addSubview(qrCodeFrameView)
            self.view.bringSubviewToFront(qrCodeFrameView)
            qrCodeFrameView.layer.insertSublayer(fillLayer, below: videoPreviewLayer!)
            self.view.bringSubviewToFront(bottomView)
            if(!SwiftFlutterBarcodeScannerPlugin.isShowFlashIcon){
                flashIcon.isHidden=true
            }
            self.view.bringSubviewToFront(cancelButton)
        }
        self.drawLine()
    }
    
    
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.moveVertically()
    }
    
    private func setConstraintsForControls() {
        self.view.addSubview(bottomView)
        self.view.addSubview(cancelButton)
        self.view.addSubview(flashIcon)
        
        bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant:0).isActive = true
        bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant:0).isActive = true
        bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant:0).isActive = true
        bottomView.heightAnchor.constraint(equalToConstant:100.0).isActive=true

        flashIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        flashIcon.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant:-40).isActive = true
        flashIcon.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        flashIcon.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.widthAnchor.constraint(equalToConstant: 100.0).isActive = true
        cancelButton.heightAnchor.constraint(equalToConstant: 70.0).isActive = true
        cancelButton.bottomAnchor.constraint(equalTo:view.bottomAnchor,constant:-40).isActive=true
        cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant:10).isActive = true
        
    }
    
    @IBAction private func flashButtonClicked() {
        if #available(iOS 10.0, *) {
            if flashIcon.image(for: .normal) == UIImage(named: "ic_flash_on", in: Bundle(identifier: "org.cocoapods.flutter-barcode-scanner"), compatibleWith: nil){
                flashIcon.setImage(UIImage(named: "ic_flash_off", in: Bundle(identifier: "org.cocoapods.flutter-barcode-scanner"), compatibleWith: nil),for:.normal)
                
            }else{
                flashIcon.setImage(UIImage(named: "ic_flash_on", in: Bundle(identifier: "org.cocoapods.flutter-barcode-scanner"), compatibleWith: nil),for:.normal)
            }
            toggleFlash()
        } else {
            
        }
    }
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                device.torchMode = AVCaptureDevice.TorchMode.off
            } else {
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    print(error)
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    @IBAction private func playButtonClicked() {
        if #available(iOS 10.0, *) {
            self.dismiss(animated: true) {
            }
        } else {
            self.dismiss(animated: true) {
            }
        }
    }
    
    private func drawLine() {
        self.view.addSubview(scanLine)
        scanLine.backgroundColor = hexStringToUIColor(hex: SwiftFlutterBarcodeScannerPlugin.lineColor) // green color
        scanlineRect = CGRect(x: xCor, y: yCor, width:(screenSize.width*0.8), height: 2)
        scanlineStartY = yCor
        scanlineStopY = yCor + (screenSize.width*0.8)
    }
    
    private func moveVertically() {
        scanLine.frame  = scanlineRect
        scanLine.center = CGPoint(x: scanLine.center.x, y: scanlineStartY)
        scanLine.isHidden = false
        weak var weakSelf = scanLine
        UIView.animate(withDuration: 2.0, delay: 0.0, options: [.repeat, .autoreverse, .beginFromCurrentState], animations: {() -> Void in
            weakSelf!.center = CGPoint(x: weakSelf!.center.x, y: self.scanlineStopY)
        }, completion: nil)
    }
    
    
    // MARK: - Helper methods
    private func launchApp(decodedURL: String) {
        if presentedViewController != nil {
            return
        }
        if self.delegate != nil {
            self.dismiss(animated: true, completion: {
                self.delegate?.userDidScanWith(barcode: decodedURL)
            })
        }
    }
}

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            if metadataObj.stringValue != nil {
                launchApp(decodedURL: metadataObj.stringValue!)
            }
        }
    }
}

func hexStringToUIColor (hex:String) -> UIColor {
    var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    
    if (cString.hasPrefix("#")) {
        cString.remove(at: cString.startIndex)
    }
    
    if ((cString.count) != 6) {
        return UIColor.gray
    }
    var rgbValue:UInt32 = 0
    Scanner(string: cString).scanHexInt32(&rgbValue)
    
    
    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}
