//
//  AudioSessionViewController.m
//  iOS-AudioPlay
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import "AudioSessionViewController.h"
#import "EQAudioSession.h"

@interface AudioSessionViewController ()

@end

@implementation AudioSessionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interruptionNotificationReceived:) name:EQAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChangeNotificationReceived:) name:EQAudioSessionRouteChangeNotification object:nil];
    
    [self activeAudioSession];
    
}

- (void)activeAudioSession
{
    NSError *error = nil;
    if ([[EQAudioSession sharedInstance] setActive:YES error:&error])
    {
        NSLog(@"audiosession actived");
    }
    else
    {
        NSLog(@"audiosession active failed, error: %@",[error description]);
    }
}

- (void)interruptionNotificationReceived:(NSNotification *)notification
{
    UInt32 interruptionState = [notification.userInfo[EQAudioSessionInterruptionStateKey] unsignedIntValue];
    AudioSessionInterruptionType interruptionType = [notification.userInfo[EQAudioSessionInterruptionTypeKey] unsignedIntValue];
    [self handleAudioSessionInterruptionWithState:interruptionState type:interruptionType];
}

- (void)handleAudioSessionInterruptionWithState:(UInt32)interruptionState type:(AudioSessionInterruptionType)interruptionType
{
    if (interruptionState == kAudioSessionBeginInterruption)
    {
        NSLog(@"interrupt begin");
        NSLog(@"pause the playing audio");
    }
    else if (interruptionState == kAudioSessionEndInterruption)
    {
        NSLog(@"interrupt end");
        if (interruptionType == kAudioSessionInterruptionType_ShouldResume)
        {
            OSStatus status = AudioSessionSetActive(true);
            if (status == noErr)
            {
                NSLog(@"resume the paused audio");
            }
        }
    }
}

- (void)routeChangeNotificationReceived:(NSNotification *)notification
{
    NSLog(@"route changed! %@",[EQAudioSession isAirplayActived] ? @"airplay actived" : @"airplay is actived");
    
    BOOL usingHeadset = [EQAudioSession usingHeadset];
    SInt32 routeChangeReason = [notification.userInfo[EQAudioSessionRouteChangeReason] intValue];
    if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable && !usingHeadset)
    {
        NSLog(@"headset off, pause the playing audio");
    }
}

@end
