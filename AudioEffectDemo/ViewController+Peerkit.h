#import "ViewController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MCViewController : ViewController <MCBrowserViewControllerDelegate, MCSessionDelegate>
{
    __block BOOL _isSendData;
    NSMutableArray *marrFileData, *marrReceiveData;
    NSInteger noOfdata, noOfDataSend;
}

@property (nonatomic, strong) MCBrowserViewController *browserVC;
@property (nonatomic, strong) MCAdvertiserAssistant *advertiser;
@property (nonatomic, strong) MCSession *mySession;
@property (nonatomic, strong) MCPeerID *myPeerID;

@end
