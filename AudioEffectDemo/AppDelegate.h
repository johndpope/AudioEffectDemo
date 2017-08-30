
#import <UIKit/UIKit.h>
#import "Reachability.h"
@class ViewController;
@class AEAudioController;


static const int ddLogLevel = 1;


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UINavigationController *nc;

@property (strong, nonatomic) ViewController *viewController;
@property (strong, nonatomic) AEAudioController *audioController;
@end
