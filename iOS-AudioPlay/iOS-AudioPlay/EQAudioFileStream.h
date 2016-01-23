//
//  EQAudioFileStream.h
//  iOS-AudioPlay
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "EQParsedAudioData.h"

@class EQAudioFileStream;
@protocol EQAudioFileStreamDelegate <NSObject>
@required
- (void)audioFileStream:(EQAudioFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData;
@optional
- (void)audioFileStreamReadyToProducePackets:(EQAudioFileStream *)audioFileStream;
@end

@interface EQAudioFileStream : NSObject

@property (nonatomic,assign,readonly) AudioFileTypeID fileType;
@property (nonatomic,assign,readonly) BOOL available;
@property (nonatomic,assign,readonly) BOOL readyToProducePackets;
@property (nonatomic,weak) id<EQAudioFileStreamDelegate> delegate;

@property (nonatomic,assign,readonly) AudioStreamBasicDescription format;
@property (nonatomic,assign,readonly) unsigned long long fileSize;
@property (nonatomic,assign,readonly) NSTimeInterval duration;
@property (nonatomic,assign,readonly) UInt32 bitRate;
@property (nonatomic,assign,readonly) UInt32 maxPacketSize;
@property (nonatomic,assign,readonly) UInt64 audioDataByteCount;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(unsigned long long)fileSize error:(NSError **)error;

- (BOOL)parseData:(NSData *)data error:(NSError **)error;

/**
 *  seek to timeinterval
 *
 *  @param time On input, timeinterval to seek.
 On output, fixed timeinterval.
 *
 *  @return seek byte offset
 */
- (SInt64)seekToTime:(NSTimeInterval *)time;

- (NSData *)fetchMagicCookie;

- (void)close;

@end
