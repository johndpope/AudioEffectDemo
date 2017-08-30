import Foundation
import UIKit
import MultipeerConnectivity


class MCViewController: ViewController, MCBrowserViewControllerDelegate, MCSessionDelegate {
    var browserVC: MCBrowserViewController?
    var advertiser: MCAdvertiserAssistant?
    var mySession: MCSession?
    var myPeerID: MCPeerID?
    
    var isSendData: Bool = false
    var marrFileData = [Any]()
    var marrReceiveData = [Any]()
    var noOfdata: Int = 0
    var noOfDataSend: Int = 0
    
    
    func viewDidLoad() {
        super.viewDidLoad()
        marrFileData = [Any]()
        marrReceiveData = [Any]()
    }
    
    // MARK: - Action Methods
    @IBAction func buttonShareClick(_ sender: UIButton) {
        if !mySession {
            setUpMultipeer()
        }
        showBrowserVC()
    }
    
    @IBAction func buttonSendClick(_ sender: UIButton) {
        sendData()
    }
    
    // MARK: - Wifi Sharing Methods
    func setUpMultipeer() {
        //  Setup peer ID
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
        //  Setup session
        mySession = MCSession(peer: myPeerID)
        mySession.delegate = self
        //  Setup BrowserViewController
        browserVC = MCBrowserViewController(serviceType: "chat", session: mySession)
        browserVC.delegate = self
        //  Setup Advertiser
        advertiser = MCAdvertiserAssistant(serviceType: "chat", discoveryInfo: nil, session: mySession)
        advertiser.start()
    }
    
    func showBrowserVC() {
        present(browserVC, animated: true) { _ in }
    }
    
    func dismissBrowserVC() {
        browserVC.dismiss(animated: true, completion: {(_: Void) -> Void in
            self.invokeAlertMethod("连接成功", body: "Both device connected successfully.", delegate: nil)
        })
    }
    
    func stopWifiSharing(_ isClear: Bool) {
        if isClear && mySession != nil {
            mySession.disconnect()
            mySession.delegate = nil
            mySession = nil
            browserVC = nil
        }
    }
    
    // MARK:s MCBrowserViewControllerDelegate
    // Notifies the delegate, when the user taps the done button
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismissBrowserVC()
        marrReceiveData.removeAll()
    }
    
    // Notifies delegate that the user taps the cancel button.
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismissBrowserVC()
    }
    
    // MARK:s MCSessionDelegate
    // Received data from remote peer
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("data receiveddddd : \(UInt(data.length))")
        if data.length > 0 {
            if data.length < 2 {
                noOfDataSend += 1
                print("noofdatasend : \(noOfDataSend)")
                print("array count : \(marrFileData.count)")
                if noOfDataSend < (marrFileData.count()) {
                    try? mySession.send(marrFileData[noOfDataSend], toPeers: mySession.connectedPeers, with: MCSessionSendDataReliable)
                }
                else {
                    try? mySession.send("File Transfer Done".data(using: String.Encoding.utf8), toPeers: mySession.connectedPeers, with: MCSessionSendDataReliable)
                }
            }
            else {
                if (String(data: data, encoding: String.Encoding.utf8) == "File Transfer Done") {
                    appendFileData()
                }
                else {
                    try? mySession.send("1".data(using: String.Encoding.utf8), toPeers: mySession.connectedPeers, with: MCSessionSendDataReliable)
                    marrReceiveData.append(data)
                }
            }
        }
    }
    
    // Received a byte stream from remote peer
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("did receive stream")
    }
    
    // Start receiving a resource from remote peer
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("start receiving")
    }
    
    // Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        print("finish receiving resource")
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("change state : \(state)")
    }
    
    // MARK: - Other Methods
    func sendData() {
        marrFileData.removeAll()
        let sendData: Data? = UIImagePNGRepresentation(UIImage(named: "test2.png"))
        let length: Int? = sendData?.count
        let chunkSize: Int = 100 * 1024
        var offset: Int = 0
        repeat {
            let thisChunkSize: Int = length - offset > chunkSize ? chunkSize : length - offset
            let chunk = Data(bytesNoCopy: CChar(sendData?.bytes) + offset, length: thisChunkSize, freeWhenDone: false)
            print("chunk length : \(UInt(chunk?.count))")
            marrFileData.append(Data(data: chunk!))
            offset += thisChunkSize
        } while offset < length
        noOfdata = marrFileData.count()
        noOfDataSend = 0
        if marrFileData.count() > 0 {
            try? mySession.send(marrFileData[noOfDataSend], toPeers: mySession.connectedPeers, with: MCSessionSendDataReliable)
        }
    }
    
    func appendFileData() {
        var fileData = Data()
        for i in 0..<marrReceiveData.count() {
            fileData.append(marrReceiveData[i])
        }
        fileData.write(toFile: "\(URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents").absoluteString)/Image.png", atomically: true)
        UIImageWriteToSavedPhotosAlbum(UIImage(data: fileData), self, Selector("image:didFinishSavingWithError:contextInfo:"), nil)
    }
    
    func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer) {
        if error == nil {
            invokeAlertMethod("发送成功", body: "图片已保存到手机相册", delegate: nil)
        }
    }
    
    func invokeAlertMethod(_ strTitle: String, body strBody: String, delegate: Any) {
        var alert = UIAlertView(title: strTitle, message: strBody, delegate: delegate, cancelButtonTitle: "OK", otherButtonTitles: "")
        alert.show()
        alert = nil
    }
    
}

//
//class ViewController: UIViewController {
//
//    fileprivate lazy var pcm : PeerConnectionManager = {
//        var pcm = PeerConnectionManager(serviceType: "local")
//        pcm.listenOn({ [weak self] (event) in
//
//            switch event {
//            case .devicesChanged(let peer, let connectedPeers):
//
//                _ = connectedPeers.map { print($0.displayName) }
//
//                defer {
//                    if let origin = self?.userStatusLabel?.frame.origin,
//                        let size = self?.userStatusLabel?.intrinsicContentSize {
//                        self?.userStatusLabel?.frame = CGRect(origin: origin, size: size)
//                    }
//                }
//
//                guard !connectedPeers.isEmpty else {
//                    self?.userStatusLabel?.text = "Not Connected!"
//                    return
//                }
//
//                if peer.status == .connected || peer.status == .notConnected {
//                    self?.userStatusLabel?.text = connectedPeers.map { $0.displayName }.reduce("Connected to:") { $0 + "\n" + $1 }
//                }
//
//            default: break
//            }
//
//            }, withKey: "configurationKey")
//        return pcm
//    }()
//
//    fileprivate var isConnecting = false
//
//    fileprivate var connectionButton : UIButton!
//    fileprivate var userStatusLabel : UILabel!
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // Do any additional setup after loading the view, typically from a nib.
//
//        connectionButton = UIButton(type: UIButtonType.system)
//        connectionButton.setTitle("Start networking!", for: .normal)
//        connectionButton.setTitleColor(.blue, for: .normal)
//        connectionButton.sizeToFit()
//        connectionButton.center = view.center
//        connectionButton.addTarget(self, action: #selector(tappedConnectionButton(sender:)), for: UIControlEvents.touchUpInside)
//        view.addSubview(connectionButton)
//
//        userStatusLabel = UILabel()
//        userStatusLabel.numberOfLines = 0
//        userStatusLabel.text = "Not Connected!"
//        userStatusLabel.sizeToFit()
//        userStatusLabel.center = view.center
//        let frame = userStatusLabel.frame
//        userStatusLabel.frame = frame.offsetBy(dx: 0, dy: frame.size.height*2)
//        view.addSubview(userStatusLabel)
//    }
//
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Dispose of any resources that can be recreated.
//    }
//
//    internal func tappedConnectionButton(sender: UIButton) {
//        switch isConnecting {
//        case false:
//            pcm.start()
//            isConnecting = true
//
//            connectionButton.setTitle("Stop networking!", for: .normal)
//            connectionButton.setTitleColor(.red, for: .normal)
//
//        case true:
//            pcm.stop()
//            isConnecting = false
//
//            connectionButton.setTitle("Start networking!", for: .normal)
//            connectionButton.setTitleColor(.blue, for: .normal)
//
//            userStatusLabel.text = "Not Connected!"
//        }
//    }
//}

