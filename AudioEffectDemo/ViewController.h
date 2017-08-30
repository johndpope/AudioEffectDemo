
#import <UIKit/UIKit.h>
#import <AnyMesh/MeshDeviceInfo.h>
#import <AnyMesh/MeshMessage.h>
#import <AnyMesh/AnyMesh.h>
#import "AppDelegate.h"

@class AEAudioController;
@interface ViewController : UITableViewController <AnyMeshDelegate>

- (id)initWithAudioController:(AEAudioController*)audioController;

@property (nonatomic, strong) AEAudioController *audioController;
-(void)connectToPeers;
- (void)stopBroadcastToPeers;
- (void)stopAllLoops;
-(void)startBroadcastToPeers;
-(void)suspend;
@end
