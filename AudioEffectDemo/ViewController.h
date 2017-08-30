
#import <UIKit/UIKit.h>
#import <AnyMesh/MeshDeviceInfo.h>
#import <AnyMesh/MeshMessage.h>
#import <AnyMesh/AnyMesh.h>


@class AEAudioController;
@interface ViewController : UITableViewController <AnyMeshDelegate>

- (id)initWithAudioController:(AEAudioController*)audioController;

@property (nonatomic, strong) AEAudioController *audioController;
- (void)stopAllLoops;
- (void)stopBroadcastToPeers;
- (void)startBroadcastToPeers;
@end
