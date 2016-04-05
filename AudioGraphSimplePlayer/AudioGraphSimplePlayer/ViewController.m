//
//  ViewController.m
//  AudioGraphSimplePlayer
//
//  Created by Sniper on 16/4/2.
//  Copyright © 2016年 ShengQiang. All rights reserved.
//

#import "ViewController.h"
#import "SimpleAUGraphPlayer.h"
#import "SimpleAudioQueuePlayer.h"
#import "SimpleAudioUnitPlayer.h"

#import <Endian.h>

@interface ViewController ()
@property (nonatomic, strong) SimpleAUGraphPlayer *player;

@property (nonatomic, strong) SimpleAudioQueuePlayer *aqPlayer;

@property (nonatomic, strong) SimpleAudioUnitPlayer *auPlayer;
@end

@implementation ViewController

- (IBAction)startButtonClicked:(UIButton *)sender
{
    [self.player play];
}

- (IBAction)stopButtonClicked:(UIButton *)sender
{
    [self.player pause];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    /*
     邱永传 - 真心喜欢你mp3
     http://up.haoduoge.com/mp3/2016-04-02/1459604288.mp3
     */
    
//    self.player = [[SimpleAUPlayer alloc] initWithURL:[NSURL URLWithString:@"http://up.haoduoge.com/mp3/2016-04-02/1459604288.mp3"]];
    
//    self.aqPlayer = [[SimpleAudioQueuePlayer alloc] initWithURL:[NSURL URLWithString:@"http://up.haoduoge.com/mp3/2016-04-02/1459604288.mp3"]];
    
    self.auPlayer = [[SimpleAudioUnitPlayer alloc] initWithURL:[NSURL URLWithString:@"http://up.haoduoge.com/mp3/2016-04-02/1459604288.mp3"]];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end


/*OSStatus转成string的方法*/
NSString * OSStatusToString(OSStatus status)
{
    size_t len = sizeof(UInt32);
    long addr = (unsigned long)&status;
    char cstring[5];
    
    len = (status >> 24) == 0 ? len - 1 : len;
    len = (status >> 16) == 0 ? len - 1 : len;
    len = (status >>  8) == 0 ? len - 1 : len;
    len = (status >>  0) == 0 ? len - 1 : len;
    
    addr += (4 - len);
    
    status = EndianU32_NtoB(status);        // strings are big endian
    
    strncpy(cstring, (char *)addr, len);
    cstring[len] = 0;
    
    return [NSString stringWithCString:(char *)cstring encoding:NSMacOSRomanStringEncoding];
}

