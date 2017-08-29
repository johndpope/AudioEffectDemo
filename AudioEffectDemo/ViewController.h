
#import <UIKit/UIKit.h>


@class AEAudioController;
@interface ViewController : UITableViewController

- (id)initWithAudioController:(AEAudioController*)audioController;

@property (nonatomic, strong) AEAudioController *audioController;

@end
