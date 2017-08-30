#import "ViewController.h"
#import "TPOscilloscopeLayer.h"
#import "AEPlaythroughChannel.h"
#import "AEExpanderFilter.h"
#import "AELimiterFilter.h"
#import "AERecorder.h"
#import "AEReverbFilter.h"
#import <QuartzCore/QuartzCore.h>
#import <BlocksKit/UIControl+BlocksKit.h>
#import <BlocksKit/BlocksKit.h>
@import DotzuObjc;
@import TheAmazingAudioEngine;

static const int kInputChannelsChangedContext;

@interface ViewController () {
    AudioFileID _audioUnitFile;
    AEChannelGroupRef _group;
    NSMutableArray *loops;
    AnyMesh *anymesh;
    NSMutableArray *messages;
    NSMutableArray *peers;
    
    MeshDeviceInfo *dInfo;
}
#define kAuxiliaryViewTag 251


@property (nonatomic, strong) AEBlockChannel *oscillator;
@property (nonatomic, strong) AEAudioUnitChannel *audioUnitPlayer;
@property (nonatomic, strong) AEAudioFilePlayer *oneshot;
@property (nonatomic, strong) AEPlaythroughChannel *playthrough;
@property (nonatomic, strong) AELimiterFilter *limiter;
@property (nonatomic, strong) AEExpanderFilter *expander;
@property (nonatomic, strong) AEReverbFilter *reverb;
@property (nonatomic, strong) TPOscilloscopeLayer *outputOscilloscope;
@property (nonatomic, strong) TPOscilloscopeLayer *inputOscilloscope;
@property (nonatomic, strong) CALayer *inputLevelLayer;
@property (nonatomic, strong) CALayer *outputLevelLayer;
@property (nonatomic, weak) NSTimer *levelsTimer;
@property (nonatomic, strong) AERecorder *recorder;
@property (nonatomic, strong) AEAudioFilePlayer *player;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *oneshotButton;
@property (nonatomic, strong) UIButton *oneshotAudioUnitButton;
@end

@implementation ViewController


- (void)prepareLoops {
    [loops removeAllObjects];
    
    @autoreleasepool
    {
        NSArray *extensions = @[@"caf", @"m4a", @"mp4", @"mp3", @"wav", @"aif"];
        NSArray *paths = nil;
        BOOL foundSound = NO;
        int x = 0;
        for (NSString *extension in extensions) {
                uint64_t now = AECurrentTimeInHostTicks() + AEHostTicksFromSeconds(2);
            paths = [[NSBundle mainBundle] pathsForResourcesOfType:extension inDirectory:nil];
            if ([paths count]) {
                for (NSString *path in paths) {
                    NSURL *URL = [NSURL fileURLWithPath:path];
                    AEAudioFilePlayer *loop = [[AEAudioFilePlayer alloc ] initWithURL:URL error:nil];
                    loop.volume = 1.0;
                    loop.channelIsMuted = YES;
                    loop.loop = YES;
                    [loop playAtTime:now];
                    [loops addObject:loop];
                    x++;
                    foundSound = YES;

                }
            }
        }
        if (!foundSound) {
            LogVerbose(@"SoundManager prepareToPlay failed to find sound in application bundle. Use prepareToPlayWithSound: instead to specify a suitable sound file.");
        }
    }
}
-(void)suspend{
    [anymesh  suspend];
}
-(void)connectToPeers{
     [anymesh connectWithName:dInfo.name subscriptions:dInfo.subscriptions];
}

- (id)initWithAudioController:(AEAudioController*)audioController {
    if ( !(self = [super initWithStyle:UITableViewStyleGrouped]) ) return nil;
    
    self.audioController = audioController;
    
    anymesh = [[AnyMesh alloc] init];
    anymesh.delegate = self;
    messages = [[NSMutableArray alloc] init];
    peers = [[NSMutableArray alloc] init];
    loops = [[NSMutableArray alloc]init];
    
    dInfo = [[MeshDeviceInfo alloc] init];
    NSString *uuid = [self getUUID];
    dInfo.name = uuid;
    //  LogInfo(@"uuid:%@", uuid);
    dInfo.subscriptions =  [NSMutableArray array];
   
    
    
    [self prepareLoops];
    

    _group = [_audioController createChannelGroup];
    NSArray *arr = [NSArray arrayWithArray:loops];
    _group = [_audioController createChannelGroup];
    [_audioController addChannels:arr toChannelGroup:_group];
    
    // Finally, add the audio unit player
    [_audioController addChannels:@[_audioUnitPlayer]];
    
    [_audioController addObserver:self forKeyPath:@"numberOfInputChannels" options:0 context:(void*)&kInputChannelsChangedContext];
    
    
    return self;
}

- (NSString *)getUUID {
    NSString *UUID = [[NSUserDefaults standardUserDefaults] objectForKey:@"uniqueID"];
    if (!UUID) {
        CFUUIDRef theUUID = CFUUIDCreate(NULL);
        CFStringRef string = CFUUIDCreateString(NULL, theUUID);
        CFRelease(theUUID);
        UUID = [(__bridge NSString *)string stringByReplacingOccurrencesOfString : @"-"withString : @""];
        [[NSUserDefaults standardUserDefaults] setValue:UUID forKey:@"uniqueID"];
    }
    return UUID;
}

- (void)setAudioController:(AEAudioController *)audioController {
    if ( _audioController ) {
        [_audioController removeObserver:self forKeyPath:@"numberOfInputChannels"];
        
        NSMutableArray *channelsToRemove = [NSMutableArray arrayWithObjects: _oscillator, _audioUnitPlayer, nil];
        

        self.oscillator = nil;
        self.audioUnitPlayer = nil;
        
        if ( _player ) {
            [channelsToRemove addObject:_player];
            self.player = nil;
        }
        
        if ( _oneshot ) {
            [channelsToRemove addObject:_oneshot];
            self.oneshot = nil;
        }
        
        if ( _playthrough ) {
            [channelsToRemove addObject:_playthrough];
            [_audioController removeInputReceiver:_playthrough];
            self.playthrough = nil;
        }
        
        [_audioController removeChannels:channelsToRemove];
        
        if ( _limiter ) {
            [_audioController removeFilter:_limiter];
            self.limiter = nil;
        }
        
        if ( _expander ) {
            [_audioController removeFilter:_expander];
            self.expander = nil;
        }
        
        if ( _reverb ) {
            [_audioController removeFilter:_reverb];
            self.reverb = nil;
        }
        
        [_audioController removeChannelGroup:_group];
        _group = NULL;
        
        if ( _audioUnitFile ) {
            AudioFileClose(_audioUnitFile);
            _audioUnitFile = NULL;
        }
    }
    
    _audioController = audioController;
    
    if ( _audioController ) {
       
        
        // Create a block-based channel, with an implementation of an oscillator
        __block float oscillatorPosition = 0;
        __block float oscillatorRate = 622.0/44100.0;
        self.oscillator = [AEBlockChannel channelWithBlock:^(const AudioTimeStamp  *time,
                                                             UInt32           frames,
                                                             AudioBufferList *audio) {
            for ( int i=0; i<frames; i++ ) {
                // Quick sin-esque oscillator
                float x = oscillatorPosition;
                x *= x; x -= 1.0; x *= x;       // x now in the range 0...1
                x *= INT16_MAX;
                x -= INT16_MAX / 2;
                oscillatorPosition += oscillatorRate;
                if ( oscillatorPosition > 1.0 ) oscillatorPosition -= 2.0;
                
                ((SInt16*)audio->mBuffers[0].mData)[i] = x;
                ((SInt16*)audio->mBuffers[1].mData)[i] = x;
            }
        }];
        _oscillator.audioDescription = AEAudioStreamBasicDescriptionNonInterleaved16BitStereo;
        _oscillator.channelIsMuted = YES;
        
        // Create an audio unit channel (a file player)
        self.audioUnitPlayer = [[AEAudioUnitChannel alloc] initWithComponentDescription:AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_Generator, kAudioUnitSubType_AudioFilePlayer)];
        
        

     

    }
}

-(void)dealloc {
    self.audioController = nil;
    
    if ( _levelsTimer ) [_levelsTimer invalidate];
}

-(void)viewDidLoad {
    [super viewDidLoad];

    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 100)];
    headerView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    self.outputOscilloscope = [[TPOscilloscopeLayer alloc] initWithAudioDescription:_audioController.audioDescription];
    _outputOscilloscope.frame = CGRectMake(0, 0, headerView.bounds.size.width, 80);
    [headerView.layer addSublayer:_outputOscilloscope];
    [_audioController addOutputReceiver:_outputOscilloscope];
    [_outputOscilloscope start];
    
    self.inputOscilloscope = [[TPOscilloscopeLayer alloc] initWithAudioDescription:_audioController.audioDescription];
    _inputOscilloscope.frame = CGRectMake(0, 0, headerView.bounds.size.width, 80);
    _inputOscilloscope.lineColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    [headerView.layer addSublayer:_inputOscilloscope];
    [_audioController addInputReceiver:_inputOscilloscope];
    [_inputOscilloscope start];
    
    self.inputLevelLayer = [CALayer layer];
    _inputLevelLayer.backgroundColor = [[UIColor colorWithWhite:0.0 alpha:0.3] CGColor];
    _inputLevelLayer.frame = CGRectMake(headerView.bounds.size.width/2.0 - 5.0 - (0.0), 90, 0, 10);
    [headerView.layer addSublayer:_inputLevelLayer];
    
    self.outputLevelLayer = [CALayer layer];
    _outputLevelLayer.backgroundColor = [[UIColor colorWithWhite:0.0 alpha:0.3] CGColor];
    _outputLevelLayer.frame = CGRectMake(headerView.bounds.size.width/2.0 + 5.0, 90, 0, 10);
    [headerView.layer addSublayer:_outputLevelLayer];
    
    self.tableView.tableHeaderView = headerView;
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 80)];
    self.recordButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_recordButton setTitle:@"Record" forState:UIControlStateNormal];
    [_recordButton setTitle:@"Stop" forState:UIControlStateSelected];
    [_recordButton addTarget:self action:@selector(record:) forControlEvents:UIControlEventTouchUpInside];
    _recordButton.frame = CGRectMake(20, 10, ((footerView.bounds.size.width-50) / 2), footerView.bounds.size.height - 20);
    _recordButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.playButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_playButton setTitle:@"Play" forState:UIControlStateNormal];
    [_playButton setTitle:@"Stop" forState:UIControlStateSelected];
    [_playButton addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    _playButton.frame = CGRectMake(CGRectGetMaxX(_recordButton.frame)+10, 10, ((footerView.bounds.size.width-50) / 2), footerView.bounds.size.height - 20);
    _playButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [footerView addSubview:_recordButton];
    [footerView addSubview:_playButton];
    self.tableView.tableFooterView = footerView;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.levelsTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateLevels:) userInfo:nil repeats:YES];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_levelsTimer invalidate];
    self.levelsTimer = nil;
}

-(void)viewDidLayoutSubviews {
    _outputOscilloscope.frame = CGRectMake(0, 0, self.tableView.tableHeaderView.bounds.size.width, 80);
    _inputOscilloscope.frame = CGRectMake(0, 0, self.tableView.tableHeaderView.bounds.size.width, 80);
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ( section ) {
        case 0:
           return loops.count;
            
        case 1:
            return 2;
            
        case 2:
            return 3;
            
        case 3:
            return 4 + (_audioController.numberOfInputChannels > 1 ? 1 : 0);
            
        default:
            return 0;
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isiPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    
    static NSString *cellIdentifier = @"cell";
    UITableViewCell *cell =  cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    switch ( indexPath.section ) {
        case 0: {
            cell.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero];
            UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(cell.bounds.size.width - (isiPad ? 250 : 210), 0, 100, cell.bounds.size.height)];
            slider.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            slider.tag = kAuxiliaryViewTag;
            slider.maximumValue = 1.0;
            slider.minimumValue = 0.0;
            [cell addSubview:slider];
            
            AEAudioFilePlayer *loop = [loops objectAtIndex:indexPath.row];
            
            __weak ViewController *weakSelf = self;
            __weak AEAudioFilePlayer *weakLoop = loop;
            
            
            NSString *filename = [loop.url.absoluteString lastPathComponent];
            cell.textLabel.text = filename;
            
            UISwitch *switchy = (UISwitch *)cell.accessoryView;
            switchy.on = !loop.channelIsMuted;
            slider.value = loop.volume;
            //__weak AnyMesh *weakAnymesh = anymesh;
            
            [switchy bk_addEventHandler: ^(id sender)
             {
                 weakLoop.channelIsMuted = !((UISwitch *)sender).isOn;
                 [weakSelf broadcastToPeers:weakLoop sender:sender];
             }          forControlEvents:UIControlEventValueChanged];
            
            
            [slider bk_addEventHandler: ^(id sender)
             {
                 weakLoop.volume = ((UISlider *)sender).value;
                 [weakSelf broadcastToPeers:weakLoop sender:sender];
             }         forControlEvents:UIControlEventValueChanged];
        }
        case 1: {
            switch ( indexPath.row ) {
                case 0: {
                    cell.accessoryView = self.oneshotButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                    [_oneshotButton setTitle:@"Play" forState:UIControlStateNormal];
                    [_oneshotButton setTitle:@"Stop" forState:UIControlStateSelected];
                    [_oneshotButton sizeToFit];
                    [_oneshotButton setSelected:_oneshot != nil];
                    [_oneshotButton addTarget:self action:@selector(oneshotPlayButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                    cell.textLabel.text = @"One Shot";
                    break;
                }
                case 1: {
                    cell.accessoryView = self.oneshotAudioUnitButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                    [_oneshotAudioUnitButton setTitle:@"Play" forState:UIControlStateNormal];
                    [_oneshotAudioUnitButton setTitle:@"Stop" forState:UIControlStateSelected];
                    [_oneshotAudioUnitButton sizeToFit];
                    [_oneshotAudioUnitButton setSelected:_oneshot != nil];
                    [_oneshotAudioUnitButton addTarget:self action:@selector(oneshotAudioUnitPlayButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                    cell.textLabel.text = @"One Shot (Audio Unit)";
                    break;
                }
            }
            break;
        }
        case 2: {
            cell.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero];
            
            switch ( indexPath.row ) {
                case 0: {
                    cell.textLabel.text = @"Limiter";
                    ((UISwitch*)cell.accessoryView).on = _limiter != nil;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(limiterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
                case 1: {
                    cell.textLabel.text = @"Expander";
                    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 40)];
                    UIButton *calibrateButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                    calibrateButton.translatesAutoresizingMaskIntoConstraints = NO;
                    [calibrateButton setTitle:@"Calibrate" forState:UIControlStateNormal];
                    [calibrateButton addTarget:self action:@selector(calibrateExpander:) forControlEvents:UIControlEventTouchUpInside];
                    UISwitch * onSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
                    onSwitch.translatesAutoresizingMaskIntoConstraints = NO;
                    onSwitch.on = _expander != nil;
                    [onSwitch addTarget:self action:@selector(expanderSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    [view addSubview:calibrateButton];
                    [view addSubview:onSwitch];
                    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[calibrateButton][onSwitch]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(calibrateButton, onSwitch)]];
                    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[calibrateButton]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(calibrateButton)]];
                    [view addConstraint:[NSLayoutConstraint constraintWithItem:onSwitch attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
                    cell.accessoryView = view;
                    break;
                }
                case 2: {
                    cell.textLabel.text = @"Reverb";
                    ((UISwitch*)cell.accessoryView).on = _reverb != nil;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(reverbSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
            }
            break;
        }
        case 3: {
            cell.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero];
            
            switch ( indexPath.row ) {
                case 0: {
                    cell.textLabel.text = @"Input Playthrough";
                    ((UISwitch*)cell.accessoryView).on = _playthrough != nil;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(playthroughSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
                case 1: {
                    cell.textLabel.text = @"Measurement Mode";
                    ((UISwitch*)cell.accessoryView).on = _audioController.useMeasurementMode;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(measurementModeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
                case 2: {
                    cell.textLabel.text = @"Input Gain";
                    UISlider *inputGainSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 100, 40)];
                    inputGainSlider.minimumValue = 0.0;
                    inputGainSlider.maximumValue = 1.0;
                    inputGainSlider.value = _audioController.inputGain;
                    [inputGainSlider addTarget:self action:@selector(inputGainSliderChanged:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = inputGainSlider;
                    break;
                }
                case 3: {
                    cell.textLabel.text = @"Use 48K Audio";
                    ((UISwitch*)cell.accessoryView).on = fabs(_audioController.audioDescription.mSampleRate - 48000) < 1.0;
                    [((UISwitch*)cell.accessoryView) addTarget:self action:@selector(sampleRateSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    break;
                }
                case 4: {
                    cell.textLabel.text = @"Channels";
                    
                    int channelCount = _audioController.numberOfInputChannels;
                    CGSize buttonSize = CGSizeMake(30, 30);
                    
                    UIScrollView *channelStrip = [[UIScrollView alloc] initWithFrame:CGRectMake(0,
                                                                                                0,
                                                                                                MIN(channelCount * (buttonSize.width+5) + 5,
                                                                                                    isiPad ? 400 : 200),
                                                                                                cell.bounds.size.height)];
                    channelStrip.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
                    channelStrip.backgroundColor = [UIColor clearColor];
                    
                    for ( int i=0; i<channelCount; i++ ) {
                        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                        button.frame = CGRectMake(i*(buttonSize.width+5), round((channelStrip.bounds.size.height-buttonSize.height)/2), buttonSize.width, buttonSize.height);
                        [button setTitle:[NSString stringWithFormat:@"%d", i+1] forState:UIControlStateNormal];
                        button.highlighted = [_audioController.inputChannelSelection containsObject:@(i)];
                        button.tag = i;
                        [button addTarget:self action:@selector(channelButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
                        [channelStrip addSubview:button];
                    }
                    
                    channelStrip.contentSize = CGSizeMake(channelCount * (buttonSize.width+5) + 5, channelStrip.bounds.size.height);
                    
                    cell.accessoryView = channelStrip;
                    
                    break;
                }
            }
            break;
        }
            
    }
    
    return cell;
}


- (void)startBroadcastToPeers {

    LogVerbose(@"requestToTarget");
    uint64_t now = AECurrentTimeInHostTicks();
    for (NSString *peer in peers) {
        [anymesh requestToTarget:peer withData:@{ @"msg":@"start",@"uuid":[self getUUID],@"hostTime":[NSString stringWithFormat:@"%llu",now] }];
    }
    

}

- (void)stopAllLoops {
    uint64_t now = AECurrentTimeInHostTicks() + AEHostTicksFromSeconds(2);
    for (AEAudioFilePlayer *loop in loops) {
        [loop playAtTime:now];
        [loop setCurrentTime:0];
    }
}

#pragma mark - AnyMesh Delegate Methods
- (void)anyMesh:(AnyMesh *)anyMesh connectedTo:(MeshDeviceInfo *)device {
    LogInfo(@"connectedTo:%@", device);
    [peers addObject:device.name];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.backgroundColor = [UIColor colorWithRed:57.0/255.0 green:158.0/255 blue:209.0/255 alpha:1.0];
}

- (void)anyMesh:(AnyMesh *)anyMesh disconnectedFrom:(NSString *)name {
    LogWarning(@"disconnectedFrom:%@", name);
    [peers removeObject:name];
    self.navigationController.navigationBar.tintColor = [UIColor blueColor];
    self.navigationController.navigationBar.backgroundColor = [UIColor whiteColor];
}

- (void)anyMesh:(AnyMesh *)anyMesh receivedMessage:(MeshMessage *)message {
    LogVerbose(@"receivedMessage:%@", message.data[@"msg"]);
    
    NSString *url = message.data[@"url"];
    NSString *filename = [url lastPathComponent];
    for (AEAudioFilePlayer *loop in loops) {
        if ([[loop.url.absoluteString lastPathComponent] isEqualToString:filename]) {
            loop.channelIsMuted = YES;
            //  [loop setCurrentTime:0];
        }
    }
    
    if ([message.data[@"msg"] isEqualToString:@"start"]) {
       // [self start];
    }
    if ([message.data[@"msg"] isEqualToString:@"stop"]) {
        [self stopAllLoops];
    }
    
    [self.tableView reloadData];
}

- (void)stopBroadcastToPeers {
    [self stopAllLoops];
    LogVerbose(@"requestToTarget");
    for (NSString *peer in peers) {
        [anymesh requestToTarget:peer withData:@{ @"msg":@"stop" }];
    }
    
    LogVerbose(@"publishToTarget");
    for (NSString *peer in peers) {
        [anymesh publishToTarget:peer withData:@{ @"msg":@"stop" }];
    }
}

- (void)broadcastToPeers:(AEAudioFilePlayer *)loop sender:(UIControl *)sender {
    LogVerbose(@"requestToTarget");
    for (NSString *peer in peers) {
        [anymesh requestToTarget:peer withData:@{ @"url":loop.url.absoluteString, @"msg":@"none" }];
    }
    
    LogVerbose(@"publishToTarget");
    for (NSString *peer in peers) {
        [anymesh publishToTarget:peer withData:@{ @"url":loop.url.absoluteString, @"msg":@"none" }];
    }
}


- (void)oscillatorSwitchChanged:(UISwitch*)sender {
    _oscillator.channelIsMuted = !sender.isOn;
}

- (void)oscillatorVolumeChanged:(UISlider*)sender {
    _oscillator.volume = sender.value;
}

- (void)channelGroupSwitchChanged:(UISwitch*)sender {
    [_audioController setMuted:!sender.isOn forChannelGroup:_group];
}

- (void)channelGroupVolumeChanged:(UISlider*)sender {
    [_audioController setVolume:sender.value forChannelGroup:_group];
}

- (void)oneshotPlayButtonPressed:(UIButton*)sender {
    if ( _oneshot ) {
        [_audioController removeChannels:@[_oneshot]];
        self.oneshot = nil;
        _oneshotButton.selected = NO;
    } else {
        self.oneshot = [AEAudioFilePlayer audioFilePlayerWithURL:[[NSBundle mainBundle] URLForResource:@"123094_103319-lq" withExtension:@"mp3"] error:NULL];
        _oneshot.removeUponFinish = YES;
        __weak ViewController *weakSelf = self;
        _oneshot.completionBlock = ^{
            ViewController *strongSelf = weakSelf;
            strongSelf.oneshot = nil;
            strongSelf->_oneshotButton.selected = NO;
        };
        [_audioController addChannels:@[_oneshot]];
        _oneshotButton.selected = YES;
    }
}

- (void)oneshotAudioUnitPlayButtonPressed:(UIButton*)sender {
    if ( !_audioUnitFile ) {
        NSURL *playerFile = [[NSBundle mainBundle] URLForResource:@"123096_103319-lq" withExtension:@"mp3"];
        AECheckOSStatus(AudioFileOpenURL((__bridge CFURLRef)playerFile, kAudioFileReadPermission, 0, &_audioUnitFile), "AudioFileOpenURL");
    }
    
    // Set the file to play
    AECheckOSStatus(AudioUnitSetProperty(_audioUnitPlayer.audioUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &_audioUnitFile, sizeof(_audioUnitFile)),
                    "AudioUnitSetProperty(kAudioUnitProperty_ScheduledFileIDs)");
    
    // Determine file properties
    UInt64 packetCount;
    UInt32 size = sizeof(packetCount);
    AECheckOSStatus(AudioFileGetProperty(_audioUnitFile, kAudioFilePropertyAudioDataPacketCount, &size, &packetCount),
                    "AudioFileGetProperty(kAudioFilePropertyAudioDataPacketCount)");
    
    AudioStreamBasicDescription dataFormat;
    size = sizeof(dataFormat);
    AECheckOSStatus(AudioFileGetProperty(_audioUnitFile, kAudioFilePropertyDataFormat, &size, &dataFormat),
                    "AudioFileGetProperty(kAudioFilePropertyDataFormat)");
    
    // Assign the region to play
    ScheduledAudioFileRegion region;
    memset (&region.mTimeStamp, 0, sizeof(region.mTimeStamp));
    region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    region.mTimeStamp.mSampleTime = 0;
    region.mCompletionProc = NULL;
    region.mCompletionProcUserData = NULL;
    region.mAudioFile = _audioUnitFile;
    region.mLoopCount = 0;
    region.mStartFrame = 0;
    region.mFramesToPlay = (UInt32)packetCount * dataFormat.mFramesPerPacket;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnitPlayer.audioUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, sizeof(region)),
                    "AudioUnitSetProperty(kAudioUnitProperty_ScheduledFileRegion)");
    
    // Prime the player by reading some frames from disk
    UInt32 defaultNumberOfFrames = 0;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnitPlayer.audioUnit, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultNumberOfFrames, sizeof(defaultNumberOfFrames)),
                    "AudioUnitSetProperty(kAudioUnitProperty_ScheduledFilePrime)");
    
    // Set the start time (now = -1)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    AECheckOSStatus(AudioUnitSetProperty(_audioUnitPlayer.audioUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)),
                    "AudioUnitSetProperty(kAudioUnitProperty_ScheduleStartTimeStamp)");
    
}

- (void)playthroughSwitchChanged:(UISwitch*)sender {
    if ( sender.isOn ) {
        self.playthrough = [[AEPlaythroughChannel alloc] init];
        [_audioController addInputReceiver:_playthrough];
        [_audioController addChannels:@[_playthrough]];
    } else {
        [_audioController removeChannels:@[_playthrough]];
        [_audioController removeInputReceiver:_playthrough];
        self.playthrough = nil;
    }
}

- (void)measurementModeSwitchChanged:(UISwitch*)sender {
    _audioController.useMeasurementMode = sender.on;
}

- (void)sampleRateSwitchChanged:(UISwitch*)sender {
    AudioStreamBasicDescription audioDescription = _audioController.audioDescription;
    audioDescription.mSampleRate = sender.on ? 48000 : 44100;
    NSError * error;
    if ( ![_audioController setAudioDescription:audioDescription error:&error] ) {
        [[[UIAlertView alloc] initWithTitle:@"Sample rate change failed"
                                    message:error.localizedDescription
                                   delegate:nil
                          cancelButtonTitle:nil
                          otherButtonTitles:@"OK", nil] show];
    }
}

-(void)inputGainSliderChanged:(UISlider*)slider {
    _audioController.inputGain = slider.value;
}

- (void)limiterSwitchChanged:(UISwitch*)sender {
    if ( sender.isOn ) {
        self.limiter = [[AELimiterFilter alloc] init];
        _limiter.level = 0.1;
        [_audioController addFilter:_limiter];
    } else {
        [_audioController removeFilter:_limiter];
        self.limiter = nil;
    }
}

- (void)expanderSwitchChanged:(UISwitch*)sender {
    if ( sender.isOn ) {
        self.expander = [[AEExpanderFilter alloc] init];
        [_audioController addFilter:_expander];
    } else {
        [_audioController removeFilter:_expander];
        self.expander = nil;
    }
}

- (void)calibrateExpander:(UIButton*)sender {
    if ( !_expander ) return;
    sender.enabled = NO;
    [_expander startCalibratingWithCompletionBlock:^{
        sender.enabled = YES;
    }];
}

- (void)reverbSwitchChanged:(UISwitch*)sender {
    if ( sender.isOn ) {
        self.reverb = [[AEReverbFilter alloc] init];
        _reverb.dryWetMix = 80;
        [_audioController addFilter:_reverb];
    } else {
        [_audioController removeFilter:_reverb];
        self.reverb = nil;
    }
}

- (void)channelButtonPressed:(UIButton*)sender {
    BOOL selected = [_audioController.inputChannelSelection containsObject:@(sender.tag)];
    selected = !selected;
    if ( selected ) {
        _audioController.inputChannelSelection = [[_audioController.inputChannelSelection arrayByAddingObject:@(sender.tag)] sortedArrayUsingSelector:@selector(compare:)];
        [self performSelector:@selector(highlightButtonDelayed:) withObject:sender afterDelay:0.01];
    } else {
        NSMutableArray *channels = [_audioController.inputChannelSelection mutableCopy];
        [channels removeObject:@(sender.tag)];
        _audioController.inputChannelSelection = channels;
        sender.highlighted = NO;
    }
}

- (void)highlightButtonDelayed:(UIButton*)button {
    button.highlighted = YES;
}

- (void)record:(id)sender {
    if ( _recorder ) {
        [_recorder finishRecording];
        [_audioController removeOutputReceiver:_recorder];
        [_audioController removeInputReceiver:_recorder];
        self.recorder = nil;
        _recordButton.selected = NO;
    } else {
        self.recorder = [[AERecorder alloc] initWithAudioController:_audioController];
        NSArray *documentsFolders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [documentsFolders[0] stringByAppendingPathComponent:@"Recording.m4a"];
        NSError *error = nil;
        if ( ![_recorder beginRecordingToFileAtPath:path fileType:kAudioFileM4AType error:&error] ) {
            [[[UIAlertView alloc] initWithTitle:@"Error"
                                        message:[NSString stringWithFormat:@"Couldn't start recording: %@", [error localizedDescription]]
                                       delegate:nil
                              cancelButtonTitle:nil
                              otherButtonTitles:@"OK", nil] show];
            self.recorder = nil;
            return;
        }
        
        _recordButton.selected = YES;
        
        [_audioController addOutputReceiver:_recorder];
        [_audioController addInputReceiver:_recorder];
    }
}

- (void)play:(id)sender {
    if ( _player ) {
        [_audioController removeChannels:@[_player]];
        self.player = nil;
        _playButton.selected = NO;
    } else {
        NSArray *documentsFolders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [documentsFolders[0] stringByAppendingPathComponent:@"Recording.m4a"];
        
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:path] ) return;
        
        NSError *error = nil;
        self.player = [AEAudioFilePlayer audioFilePlayerWithURL:[NSURL fileURLWithPath:path] error:&error];
        
        if ( !_player ) {
            [[[UIAlertView alloc] initWithTitle:@"Error"
                                        message:[NSString stringWithFormat:@"Couldn't start playback: %@", [error localizedDescription]]
                                       delegate:nil
                              cancelButtonTitle:nil
                              otherButtonTitles:@"OK", nil] show];
            return;
        }
        
        _player.removeUponFinish = YES;
        __weak ViewController *weakSelf = self;
        _player.completionBlock = ^{
            ViewController *strongSelf = weakSelf;
            strongSelf->_playButton.selected = NO;
            weakSelf.player = nil;
        };
        [_audioController addChannels:@[_player]];
        
        _playButton.selected = YES;
    }
}

static inline float translate(float val, float min, float max) {
    if ( val < min ) val = min;
    if ( val > max ) val = max;
    return (val - min) / (max - min);
}

- (void)updateLevels:(NSTimer*)timer {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    Float32 inputAvg, inputPeak, outputAvg, outputPeak;
    [_audioController inputAveragePowerLevel:&inputAvg peakHoldLevel:&inputPeak];
    [_audioController outputAveragePowerLevel:&outputAvg peakHoldLevel:&outputPeak];
    UIView *headerView = self.tableView.tableHeaderView;
    
    _inputLevelLayer.frame = CGRectMake(headerView.bounds.size.width/2.0 - 5.0 - (translate(inputAvg, -20, 0) * (headerView.bounds.size.width/2.0 - 15.0)),
                                        90,
                                        translate(inputAvg, -20, 0) * (headerView.bounds.size.width/2.0 - 15.0),
                                        10);
    
    _outputLevelLayer.frame = CGRectMake(headerView.bounds.size.width/2.0,
                                         _outputLevelLayer.frame.origin.y,
                                         translate(outputAvg, -20, 0) * (headerView.bounds.size.width/2.0 - 15.0),
                                         10);
    
    [CATransaction commit];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ( context == &kInputChannelsChangedContext ) {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
    }
}

@end
