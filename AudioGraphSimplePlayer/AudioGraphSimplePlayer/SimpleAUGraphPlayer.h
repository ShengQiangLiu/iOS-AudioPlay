//
//  SimpleAUPlayer.h
//  AudioGraphSimplePlayer
//
//  Created by Sniper on 16/4/2.
//  Copyright © 2016年 ShengQiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface SimpleAUGraphPlayer : NSObject

- (id)initWithURL:(NSURL *)inURL;
- (void)play;
- (void)pause;

@property (readonly, nonatomic) CFArrayRef iPodEQPresetsArray;
- (void)selectEQPreset:(NSInteger)value;

@end
