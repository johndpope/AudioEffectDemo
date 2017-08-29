//
//  AppDelegate.m
//  Audio Controller Test Suite
//
//  Created by Michael Tyson on 13/02/2012.
//  Copyright (c) 2012 A Tasty Pixel. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "TheAmazingAudioEngine.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize audioController = _audioController;


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
    self.viewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Stop" style:UIBarButtonItemStylePlain target:self.viewController action:@selector(stopAllLoops)];
    self.window.rootViewController = self.nc;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
