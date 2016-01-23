//
//  EQAudioFile.h
//  iOS-AudioPlay
//
//  Created by admin on 16/1/23.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "EQParsedAudioData.h"

@interface EQAudioFile : NSObject

@property (nonatomic,copy,readonly) NSString *filePath;
@property (nonatomic,assign,readonly) AudioFileTypeID fileType;

@property (nonatomic,assign,readonly) BOOL available;

@property (nonatomic,assign,readonly) AudioStreamBasicDescription format;
@property (nonatomic,assign,readonly) unsigned long long fileSize;
@property (nonatomic,assign,readonly) NSTimeInterval duration;
@property (nonatomic,assign,readonly) UInt32 bitRate;
@property (nonatomic,assign,readonly) UInt32 maxPacketSize;
@property (nonatomic,assign,readonly) UInt64 audioDataByteCount;

- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType;
- (NSArray *)parseData:(BOOL *)isEof;
- (NSData *)fetchMagicCookie;
- (void)seekToTime:(NSTimeInterval)time;
- (void)close;

@end
