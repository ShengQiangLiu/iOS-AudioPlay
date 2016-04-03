//
//  SimpleAudioUnitPlayer.h
//  AudioGraphSimplePlayer
//
//  Created by Sniper on 16/4/3.
//  Copyright © 2016年 ShengQiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface SimpleAudioUnitPlayer : NSObject
- (id)initWithURL:(NSURL *)inURL;
- (void)play;
- (void)pause;
@property (readonly, getter=isPlaying) BOOL playing;
@end
