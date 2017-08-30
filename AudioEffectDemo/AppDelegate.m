
#import "AppDelegate.h"
#import "ViewController.h"
#import "TheAmazingAudioEngine.h"

@import DotzuObjc;
@import Dotzu;

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize audioController = _audioController;

- (void)addlistenerForInternetReachability{

    // setup reachabilty
    __weak AppDelegate *weakSelf = self;
    self.reach = [Reachability reachabilityForInternetConnection];
    self.reach.reachableBlock  = ^(Reachability *reach) {
        LogInfo(@"Reachable");
    };
    
    [self.reach startNotifier];
    if (self.reach.isReachable) {
        LogInfo(@"Reachable");
        [self.viewController connectToPeers];
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Create an instance of the audio controller, set it up and start it running
    self.audioController = [[AEAudioController alloc] initWithAudioDescription:AEAudioStreamBasicDescriptionNonInterleavedFloatStereo inputEnabled:YES];
    _audioController.preferredBufferDuration = 0.005;
    _audioController.useMeasurementMode = YES;
    [_audioController start:NULL];
    
    // Create and display view controller
    
    self.viewController = [[ViewController alloc] initWithAudioController:_audioController];
    self.nc = [[UINavigationController alloc]initWithRootViewController:self.viewController];
    self.viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Stop Peers" style:UIBarButtonItemStylePlain target:self.viewController action:@selector(stopBroadcastToPeers)];
    self.viewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self.viewController action:@selector(startBroadcastToPeers)];
    self.window.rootViewController = self.nc;
    [self.window makeKeyAndVisible];
    
    
    [[Dotzu sharedManager] enable];
    [self addlistenerForInternetReachability];
    
    return YES;
}

@end

