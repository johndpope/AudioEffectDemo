#import <UIKit/UIKit.h>
#import "AppDelegate.h"


@class AEAudioController;
@interface ViewController : UITableViewController 

- (id)initWithAudioController:(AEAudioController*)audioController;

@property (nonatomic, strong) AEAudioController *audioController;
- (void)stopAllLoops;
@end
