//
//  AudioFileStreamViewController.m
//  iOS-AudioPlay
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import "AudioFileStreamViewController.h"
#import "EQAudioFileStream.h"

@interface AudioFileStreamViewController () <EQAudioFileStreamDelegate>
{
@private
    EQAudioFileStream *_audioFileStream;
}
@end

@implementation AudioFileStreamViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
    NSError *error = nil;
    _audioFileStream = [[EQAudioFileStream alloc] initWithFileType:kAudioFileMP3Type fileSize:fileSize error:&error];
    _audioFileStream.delegate = self;
    if (error)
    {
        _audioFileStream = nil;
        NSLog(@"create audio file stream failed, error: %@",[error description]);
    }
    else
    {
        NSLog(@"audio file opened.");
        if (file)
        {
            NSUInteger lengthPerRead = 10000;
            while (fileSize > 0)
            {
                NSData *data = [file readDataOfLength:lengthPerRead];
                fileSize -= [data length];
                [_audioFileStream parseData:data error:&error];
                if (error)
                {
                    if (error.code == kAudioFileStreamError_NotOptimized)
                    {
                        NSLog(@"audio not optimized.");
                    }
                    break;
                }
            }
            [_audioFileStream close];
            _audioFileStream = nil;
            NSLog(@"audio file closed.");
            [file closeFile];
        }
    }

    
}

- (void)audioFileStreamReadyToProducePackets:(EQAudioFileStream *)audioFileStream
{
    NSLog(@"audio format: bitrate = %zd, duration = %lf.",_audioFileStream.bitRate,_audioFileStream.duration);
    NSLog(@"audio ready to produce packets.");
}

- (void)audioFileStream:(EQAudioFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData
{
    NSLog(@"data parsed, should be filled in buffer.");
}


@end
