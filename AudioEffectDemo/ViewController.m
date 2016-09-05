//
//  ViewController.m
//  AudioEffectDemo
//
//  Created by 李银涛 on 16/8/30.
//  Copyright © 2016年 李银涛. All rights reserved.
//

#import "ViewController.h"
#import <TheAmazingAudioEngine.h>
#import <AEHighPassFilter.h>
#import <AEParametricEqFilter.h>
#import <AEVarispeedFilter.h>

@interface ViewController ()

@property (nonatomic, strong) AEAudioController *audioController;
@property (nonatomic, strong) AEHighPassFilter *filter;
@property (nonatomic, strong) AEAudioFilePlayer *player;
@property (nonatomic, strong) AEAudioFilePlayer *player1;
@property (nonatomic, strong) AEAudioFilePlayer *player2;

@property (nonatomic, strong) UIButton *progressButton;
@property (nonatomic, strong) UISlider *pSlider;

@property (nonatomic, strong) NSMutableArray *players;

@property (nonatomic, strong) NSMutableArray *seliderArr;
@property (nonatomic, strong) NSMutableArray *seliderValueArr;

@property (nonatomic, assign) BOOL isPlay;
@property (nonatomic, assign) BOOL isAudioMix;


@end

@implementation ViewController {
    
    AEParametricEqFilter *_eq31HzFilter;
    AEParametricEqFilter *_eq62HzFilter;
    AEParametricEqFilter *_eq125HzFilter;
    AEParametricEqFilter *_eq250HzFilter;
    AEParametricEqFilter *_eq500HzFilter;
    AEParametricEqFilter *_eq1kFilter;
    AEParametricEqFilter *_eq2kFilter;
    AEParametricEqFilter *_eq4kFilter;
    AEParametricEqFilter *_eq8kFilter;
    AEParametricEqFilter *_eq16kFilter;
    AEVarispeedFilter    *_playbackRateFilter;
    NSArray * _eqFilters;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1.0];
    
    self.seliderArr = [NSMutableArray array];
    self.seliderValueArr = [NSMutableArray array];
    self.players = [NSMutableArray array];
    self.audioController = [[AEAudioController alloc] initWithAudioDescription:AEAudioStreamBasicDescriptionNonInterleaved16BitStereo inputEnabled:YES];
    
    NSError *error = NULL;
    BOOL result = [_audioController start:&error];
    if ( !result ) {
        NSLog(@"发生错误:%@",error);
    }
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"qianqianquege" ofType:@"mp3"];
    self.player = [[AEAudioFilePlayer alloc] initWithURL:[NSURL fileURLWithPath:path] error:&error];
    [self.players addObject:self.player];
    
    [self creatEqFliters];
    [self setSubViews];
    
}
#pragma mark - 界面初始化

- (void)creatEqFliters {
    
    _eq31HzFilter           = [[AEParametricEqFilter alloc] init];
    _eq62HzFilter           = [[AEParametricEqFilter alloc] init];
    _eq125HzFilter          = [[AEParametricEqFilter alloc] init];
    _eq250HzFilter          = [[AEParametricEqFilter alloc] init];
    _eq500HzFilter          = [[AEParametricEqFilter alloc] init];
    _eq1kFilter             = [[AEParametricEqFilter alloc] init];
    _eq2kFilter             = [[AEParametricEqFilter alloc] init];
    _eq4kFilter             = [[AEParametricEqFilter alloc] init];
    _eq8kFilter            = [[AEParametricEqFilter alloc] init];
    _eq16kFilter            = [[AEParametricEqFilter alloc] init];
    _playbackRateFilter     = [[AEVarispeedFilter alloc] init];
    
    _eqFilters              = @[_eq31HzFilter, _eq62HzFilter, _eq125HzFilter, _eq250HzFilter, _eq500HzFilter, _eq1kFilter, _eq2kFilter, _eq4kFilter, _eq8kFilter, _eq16kFilter, _playbackRateFilter];
}

- (void)setSubViews {
    
    NSArray *arr = [NSArray arrayWithObjects:@"31HZ",@"62HZ",@"125HZ",@"250HZ",@"500HZ",@"1000HZ",@"2000HZ",@"4000HZ",@"8000HZ",@"16000HZ",@"音量", @"播放速度", nil];
    CGFloat margin = 40;
    for (int i = 0; i < 12; i++) {
        
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(20, margin+30*i, CGRectGetWidth(self.view.frame)-100, 20)];
        slider.tag = 1000 + i;
        slider.minimumValue = -5.0;
        slider.maximumValue = 5.0;
        slider.value = 0.0;
        
        slider.backgroundColor = [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1.0];
        
        if (i == 10) {
            
            slider.minimumValue = 0.0;
            slider.maximumValue = 1.0;
            slider.value = 0.5;
            [slider addTarget:self action:@selector(sliderValueChange:) forControlEvents:UIControlEventValueChanged];
            
        }else if (i == 11) {
            
            slider.minimumValue = 0.5;
            slider.maximumValue = 2.0;
            slider.value = 1.0;
            [slider addTarget:self action:@selector(sliderValueChange:) forControlEvents:UIControlEventValueChanged];
            
        }else {
            
            [slider addTarget:self action:@selector(sliderValueChange:) forControlEvents:UIControlEventTouchUpInside];
            [slider addTarget:self action:@selector(sliderValueChange:) forControlEvents:UIControlEventTouchUpOutside];
            [self.seliderArr addObject:slider];
            
        }
        
        [self.seliderValueArr addObject:[NSString stringWithFormat:@"%f", slider.value]];
        
        NSLog(@"%@",[NSString stringWithFormat:@"%f", slider.value]);
        
        [self.view addSubview:slider];
        
        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(slider.frame) + 10, CGRectGetMinY(slider.frame), 100, 20)];
        lab.text = [NSString stringWithFormat:@"%@",arr[i]];
        lab.backgroundColor = [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1.0];;
        lab.textColor = [UIColor blackColor];
        
        lab.font = [UIFont systemFontOfSize:15];
        [self.view addSubview:lab];
    }
    
    //进度条
    UISlider *pSlider = [[UISlider alloc] initWithFrame:CGRectMake(10, CGRectGetHeight(self.view.frame) - 100, CGRectGetWidth(self.view.frame)-20, 30)];
    pSlider.minimumValue = 0.0;
    pSlider.maximumValue = 0.0;
    pSlider.value = 0.0;
    pSlider.backgroundColor = [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1.0];
    [pSlider addTarget:self action:@selector(pSliderValueChange:) forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:pSlider];
    self.pSlider = pSlider;
    
    //恢复默认
    
    
    [self addButtnWithTitle:@"" frame:CGRectMake(CGRectGetWidth(self.view.frame)/3*2+10, CGRectGetHeight(self.view.frame) - 50, CGRectGetWidth(self.view.frame)/3-20, 30) action:@selector(resetButtonAction:)];
    
    //混音
    
    [self addButtnWithTitle:@"进度-3" frame:CGRectMake(CGRectGetWidth(self.view.frame)/3+10, CGRectGetHeight(self.view.frame) - 50, CGRectGetWidth(self.view.frame)/3-20, 30) action:@selector(audioMixing:)];
    
    //开始播放
    
    [self addButtnWithTitle:@"开始播放" frame:CGRectMake(10, CGRectGetHeight(self.view.frame) - 50, CGRectGetWidth(self.view.frame)/3-20, 30) action:@selector(startPlay:)];
    
    [self.audioController addChannels:@[self.player]];
    self.pSlider.maximumValue = self.player.duration;

//    [self.player addObserver:self forKeyPath:@"currentTime" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(progress) userInfo:nil repeats:YES];
    
    [self.audioController stop];
}

- (void)progress {
    
        self.pSlider.value = self.player.currentTime;
    [self.progressButton setTitle:[NSString stringWithFormat:@"%3.2d:%d", (int)self.player.currentTime, (int)self.player.duration] forState:UIControlStateNormal];
}

- (void)pSliderValueChange:(UISlider *)slider {
    
    self.player.currentTime = slider.value;
}

//-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
//{
//    if([keyPath isEqualToString:@"duration"]) {
//        self.pSlider.value = self.player.currentTime;
//    }
//}

- (void)addButtnWithTitle:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    button.layer.cornerRadius = 5;
    button.layer.masksToBounds = YES;
    button.layer.borderColor = [UIColor blueColor].CGColor;
    button.layer.borderWidth = 1.0;
    button.titleLabel.font = [UIFont systemFontOfSize:14];
    
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    if ([title isEqualToString:@""]) {
        self.progressButton = button;
    }
}

#pragma mark - 点击事件 & 均衡器改变事件

- (void)startPlay:(UIButton *)sender {
    
    //开始播放
    
    if (self.isPlay) {
        
        [self.audioController stop];
        
    }else {
        
        [self.audioController start:nil];
    }
    
    
    self.isPlay = !self.isPlay;
}

- (void)audioMixing:(UIButton *)sender {
    
    
//    
//    if (!_isAudioMix) {
//        
//        [self.audioController removeChannels:@[self.player]];
//        
//        NSString *path1 = [[NSBundle mainBundle] pathForResource:@"yedegangqinqu" ofType:@"mp3"];
//        self.player1 = [[AEAudioFilePlayer alloc] initWithURL:[NSURL fileURLWithPath:path1] error:nil];
//        [self.players addObject:self.player1];
//        
//        
//        NSString *path2 = [[NSBundle mainBundle] pathForResource:@"ButterFly" ofType:@"mp3"];
//        self.player2 = [[AEAudioFilePlayer alloc] initWithURL:[NSURL fileURLWithPath:path2] error:nil];
//        [self.players addObject:self.player2];
//        
//        [self.audioController addChannels:@[self.player, self.player1, self.player2]];
//        [self.audioController start:nil];
//        
//        _isAudioMix = YES;
//    }else {
//        
//        if (self.isPlay) {
//            
//            [self.audioController stop];
//            
//        }else {
//            
//            [self.audioController start:nil];
//        }
//        
//        self.isPlay = !self.isPlay;
//    }
//    
    
    if (self.player.currentTime > 3) {
        self.player.currentTime -= 3;

    }
}


- (void)resetButtonAction:(UIButton *)sender {
    
//    for (int i = 0; i < self.seliderArr.count; i++) {
//        UISlider *slider = self.seliderArr[i];
//        slider.value = [self.seliderValueArr[i] floatValue];
//        NSLog(@"%f", slider.value);
//        [self sliderValueChange:slider];
//    }
    
    [sender setTitle:[NSString stringWithFormat:@"进度：%2d", (int)self.player.currentTime] forState:UIControlStateNormal];
    
}

- (void)sliderValueChange:(UISlider *)slider {
    
        CGFloat value = slider.value;
        NSLog(@"滑块：%lf",value);
        NSInteger eqType = 31;
        switch (slider.tag) {
            case 1000:{
                
                break;
            }
            case 1001:{
                eqType = 62;
                break;
            }
            case 1002:{
                eqType = 125;
                break;
            }
            case 1003:{
                eqType = 250;
                break;
            }
            case 1004:{
                eqType = 500;
                break;
            }
            case 1005:{
                eqType = 1000;
                break;
            }
            case 1006:{
                eqType = 2000;
                break;
            }
            case 1007:{
                eqType = 4000;
                break;
            }case 1008:{
                eqType = 8000;
                break;
            }case 1009:{
                eqType = 16000;
                break;
            }case 1010:{
                
                self.player.volume = value;
                
                return;
            }case 1011:{
                
                [self setupEqFilter:_playbackRateFilter playbackRate:value];

                return;
            }
        }
    
            
            [self setupFilterEq:eqType value:value];
        
}

- (void)setVolume:(float)value {
 
    for (AEAudioFilePlayer *player in self.players) {
        player.volume = value;
    }
}



//改变音效
- (void)setupFilterEq:(NSInteger)eqType value:(double)gain {
    switch (eqType) {
        case 31: {
            
            [self setupEqFilter:_eq31HzFilter centerFrequency:31 gain:gain];
            break;
        }
        case 62: {
            [self setupEqFilter:_eq62HzFilter centerFrequency:62 gain:gain];
            break;
        }
        case 125: {
            [self setupEqFilter:_eq125HzFilter centerFrequency:125 gain:gain];
            break;
        }
        case 250: {
            [self setupEqFilter:_eq250HzFilter centerFrequency:250 gain:gain];
            break;
        }
        case 500: {
            [self setupEqFilter:_eq500HzFilter centerFrequency:500 gain:gain];
            break;
        }
        case 1000: {
            [self setupEqFilter:_eq1kFilter centerFrequency:1000 gain:gain];
            break;
        }
        case 2000: {
            [self setupEqFilter:_eq2kFilter centerFrequency:2000 gain:gain];
            break;
        }
        case 4000: {
            [self setupEqFilter:_eq4kFilter centerFrequency:4000 gain:gain];
            break;
        }
        case 8000: {
            [self setupEqFilter:_eq8kFilter centerFrequency:8000 gain:gain];
            break;
        }
        case 16000: {
            [self setupEqFilter:_eq16kFilter centerFrequency:16000 gain:gain];
            break;
        }
    }
}



- (void)setupEqFilter:(AEParametricEqFilter *)eqFilter centerFrequency:(double)centerFrequency gain:(double)gain {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if ( ![_audioController.filters containsObject:eqFilter] ) {
            for (AEParametricEqFilter *existEqFilter in _eqFilters) {
                if (eqFilter == existEqFilter) {
                    [self.audioController addFilter:eqFilter];
                    break;
                }
            }
        }
        
        eqFilter.centerFrequency = centerFrequency;
        eqFilter.qFactor         = 1.0;
        eqFilter.gain            = gain;
    });
}

- (void)setupEqFilter:(AEVarispeedFilter *)eqFilter playbackRate:(double)playbackRate {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if ( ![_audioController.filters containsObject:eqFilter] ) {
            for (AEVarispeedFilter *existEqFilter in _eqFilters) {
                if (eqFilter == existEqFilter) {
                    [self.audioController addFilter:eqFilter];
                    break;
                }
            }
        }
        eqFilter.playbackRate   = playbackRate;
    });
}

- (void)dealloc {
    [self.player removeObserver:self forKeyPath:@"duration"];
}

@end
