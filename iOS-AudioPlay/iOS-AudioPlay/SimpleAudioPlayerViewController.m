//
//  SimpleAudioPlayerViewController.m
//  iOS-AudioPlay
//
//  Created by admin on 16/1/23.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import "SimpleAudioPlayerViewController.h"
#import "MCSimpleAudioPlayer.h"
#import "NSTimer+BlocksSupport.h"

@interface SimpleAudioPlayerViewController ()
{
@private
    MCSimpleAudioPlayer *_player;
    NSTimer *_timer;
}

@property (weak, nonatomic) IBOutlet UIButton *playOrPauseButton;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;

@end

@implementation SimpleAudioPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    if (!_player)
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
        _player = [[MCSimpleAudioPlayer alloc] initWithFilePath:path fileType:kAudioFileMP3Type];
        
        //        NSString *path = [[NSBundle mainBundle] pathForResource:@"M4ASample" ofType:@"m4a"];
        //        _player = [[MCSimpleAudioPlayer alloc] initWithFilePath:path fileType:kAudioFileAAC_ADTSType];
        
        //        NSString *path = [[NSBundle mainBundle] pathForResource:@"CAFSample" ofType:@"caf"];
        //        _player = [[MCSimpleAudioPlayer alloc] initWithFilePath:path fileType:kAudioFileCAFType];
        
        [_player addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    }
    [_player play];
    
}

#pragma mark - status kvo
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _player)
    {
        if ([keyPath isEqualToString:@"status"])
        {
            [self performSelectorOnMainThread:@selector(handleStatusChanged) withObject:nil waitUntilDone:NO];
        }
    }
}

- (void)handleStatusChanged
{
    if (_player.isPlayingOrWaiting)
    {
        [self.playOrPauseButton setTitle:@"Pause" forState:UIControlStateNormal];
        [self startTimer];
        
    }
    else
    {
        [self.playOrPauseButton setTitle:@"Play" forState:UIControlStateNormal];
        [self stopTimer];
        [self progressMove];
    }
}

#pragma mark - timer
- (void)startTimer
{
    if (!_timer)
    {
        __weak typeof(self)weakSelf = self;
        _timer = [NSTimer bs_scheduledTimerWithTimeInterval:1 block:^{
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf progressMove];
        } repeats:YES];
        [_timer fire];
    }
}

- (void)stopTimer
{
    if (_timer)
    {
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)progressMove
{
    if (!self.progressSlider.tracking)
    {
        if (_player.duration != 0)
        {
            self.progressSlider.value = _player.progress / _player.duration;
        }
        else
        {
            self.progressSlider.value = 0;
        }
    }
}


- (IBAction)playOrPause:(UIButton *)sender
{
    
    if (_player.isPlayingOrWaiting)
    {
        [_player pause];
    }
    else
    {
        [_player play];
    }

}

- (IBAction)stop:(UIButton *)sender
{
    [_player stop];

}

- (IBAction)seek:(UISlider *)sender
{
    _player.progress = _player.duration * self.progressSlider.value;
}


@end
