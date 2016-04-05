//
//  SimpleAudioUnitPlayer.m
//  AudioGraphSimplePlayer
//
//  Created by Sniper on 16/4/3.
//  Copyright © 2016年 ShengQiang. All rights reserved.
//

#import "SimpleAudioUnitPlayer.h"

static void KKAudioFileStreamPropertyListener(void* inClientData,
                                              AudioFileStreamID inAudioFileStream,
                                              AudioFileStreamPropertyID inPropertyID,
                                              UInt32* ioFlags);
static void KKAudioFileStreamPacketsCallback(void* inClientData,
                                             UInt32 inNumberBytes,
                                             UInt32 inNumberPackets,
                                             const void* inInputData,
                                             AudioStreamPacketDescription *inPacketDescriptions);
static OSStatus KKPlayerAURenderCallback(void *userData,
                                         AudioUnitRenderActionFlags *ioActionFlags,
                                         const AudioTimeStamp *inTimeStamp,
                                         UInt32 inBusNumber,
                                         UInt32 inNumberFrames,
                                         AudioBufferList *ioData);

static OSStatus KKPlayerConverterFiller(AudioConverterRef inAudioConverter,
                                        UInt32* ioNumberDataPackets,
                                        AudioBufferList* ioData,
                                        AudioStreamPacketDescription** outDataPacketDescription,
                                        void* inUserData);

static const OSStatus KKAudioConverterCallbackErr_NoData = 'kknd';

static AudioStreamBasicDescription KKSignedIntLinearPCMStreamDescription();

@interface SimpleAudioUnitPlayer () <NSURLConnectionDelegate>
{
    NSURLConnection *URLConnection;
    struct {
        BOOL stopped;
        BOOL loaded;
    } playerStatus ;
    
    AudioComponentInstance audioUnit;
    
    AudioFileStreamID audioFileStreamID;
    AudioStreamBasicDescription streamDescription;
    AudioConverterRef converter;
    AudioBufferList *renderBufferList;
    UInt32 renderBufferSize;
    
    NSMutableArray *packetsArray;
    size_t readHead;
}
- (double)packetsPerSecond;
@end

AudioStreamBasicDescription KKSignedIntLinearPCMStreamDescription()
{
    AudioStreamBasicDescription destFormat;
    bzero(&destFormat, sizeof(AudioStreamBasicDescription));
    destFormat.mSampleRate = 44100.0;
    destFormat.mFormatID = kAudioFormatLinearPCM;
    destFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    destFormat.mFramesPerPacket = 1;
    destFormat.mBytesPerPacket = 4;
    destFormat.mBytesPerFrame = 4;
    destFormat.mChannelsPerFrame = 2;
    destFormat.mBitsPerChannel = 16;
    destFormat.mReserved = 0;
    return destFormat;
}


@implementation SimpleAudioUnitPlayer

- (void)dealloc
{
    AudioFileStreamClose(audioFileStreamID);
    AudioConverterDispose(converter);
    free(renderBufferList->mBuffers[0].mData);
    free(renderBufferList);
    renderBufferList = NULL;
    
    [URLConnection cancel];
}

- (void)buildOutputUnit
{
    // 建立 remote IO node
    AudioComponentDescription outputUnitDescription;
    bzero(&outputUnitDescription, sizeof(AudioComponentDescription));
    outputUnitDescription.componentType = kAudioUnitType_Output;
    outputUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputUnitDescription.componentFlags = 0;
    outputUnitDescription.componentFlagsMask = 0;
    
    AudioComponent outputComponent = AudioComponentFindNext(NULL, &outputUnitDescription);
    OSStatus status = AudioComponentInstanceNew(outputComponent, &audioUnit);
    NSAssert(noErr == status, @"Must be no error.");
    
    // 設定 remote IO node 的輸入格式
    AudioStreamBasicDescription audioFormat = KKSignedIntLinearPCMStreamDescription();
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input, 0,
                         &audioFormat, sizeof(audioFormat));
    
    // 設定 render callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    callbackStruct.inputProc = KKPlayerAURenderCallback;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global, 0,
                                  &callbackStruct, sizeof(callbackStruct));
    NSAssert(noErr == status, @"Must be no error.");
    
    //  建立 converter 要使用的 buffer list
    UInt32 bufferSize = 4096 * 4;
    renderBufferSize = bufferSize;
    renderBufferList = (AudioBufferList *)calloc(1, sizeof(UInt32) + sizeof(AudioBuffer));
    renderBufferList->mNumberBuffers = 1;
    renderBufferList->mBuffers[0].mNumberChannels = 2;
    renderBufferList->mBuffers[0].mDataByteSize = bufferSize;
    renderBufferList->mBuffers[0].mData = calloc(1, bufferSize);
}

- (id)initWithURL:(NSURL *)inURL
{
    self = [super init];
    if (self) {
        [self buildOutputUnit];
        
        playerStatus.stopped = NO;
        packetsArray = [[NSMutableArray alloc] init];
        
        // 第一步：建立 Audio Parser，指定 callback，以及建立 HTTP 連線，
        // 開始下載檔案
        AudioFileStreamOpen((__bridge void *)(self),
                            KKAudioFileStreamPropertyListener,
                            KKAudioFileStreamPacketsCallback,
                            kAudioFileMP3Type, &audioFileStreamID);
        URLConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:inURL] delegate:self];
        playerStatus.stopped = YES;
    }
    return self;
}

- (double)packetsPerSecond
{
    if (streamDescription.mFramesPerPacket) {
        return streamDescription.mSampleRate / streamDescription.mFramesPerPacket;
    }
    return 44100.0/1152.0;
}

- (void)play
{
    OSStatus status = AudioOutputUnitStart(audioUnit);
    NSAssert(noErr == status, @"AudioOutputUnitStart, error: %ld", (signed long)status);
}

- (void)pause
{
    OSStatus status = AudioOutputUnitStop(audioUnit);
    NSAssert(noErr == status, @"AudioOutputUnitStop, error: %ld", (signed long)status);
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]])
    {
        if ([(NSHTTPURLResponse *)response statusCode] != 200)
        {
            NSLog(@"HTTP code:%ld", [(NSHTTPURLResponse *)response statusCode]);
            [connection cancel];
            playerStatus.stopped = YES;
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // 第二步：抓到了部分檔案，就交由 Audio Parser 開始 parse 出 data
    // stream 中的 packet。
    AudioFileStreamParseBytes(audioFileStreamID, (UInt32)[data length], [data bytes], 0);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"Complete loading data");
    playerStatus.loaded = YES;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"Failed to load data: %@", [error localizedDescription]);
    [self pause];
}

#pragma mark -
#pragma mark Audio Parser and Audio Queue callbacks

- (void)_createAudioQueueWithAudioStreamDescription:(AudioStreamBasicDescription *)audioStreamBasicDescription
{
    memcpy(&streamDescription, audioStreamBasicDescription, sizeof(AudioStreamBasicDescription));
    AudioStreamBasicDescription destFormat = KKSignedIntLinearPCMStreamDescription();
    AudioConverterNew(&streamDescription, &destFormat, &converter);
}

- (void)_storePacketsWithNumberOfBytes:(UInt32)inNumberBytes
                       numberOfPackets:(UInt32)inNumberPackets
                             inputData:(const void *)inInputData
                    packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions
{
    for (int i = 0; i < inNumberPackets; ++i) {
        SInt64 packetStart = inPacketDescriptions[i].mStartOffset;
        UInt32 packetSize = inPacketDescriptions[i].mDataByteSize;
        assert(packetSize > 0);
        NSData *packet = [NSData dataWithBytes:inInputData + packetStart length:packetSize];
        [packetsArray addObject:packet];
    }
    
    //  第五步，因為 parse 出來的 packets 夠多，緩衝內容夠大，因此開始
    //  播放
    
    if (readHead == 0 && [packetsArray count] > (int)([self packetsPerSecond] * 3))
    {
        if (playerStatus.stopped)
        {
            [self play];
        }
    }
}

#pragma mark -
#pragma mark Properties

- (BOOL)isStopped
{
    return playerStatus.stopped;
}

- (OSStatus)callbackWithNumberOfFrames:(UInt32)inNumberOfFrames
                                ioData:(AudioBufferList  *)inIoData
                             busNumber:(UInt32)inBusNumber
{
    @synchronized(self) {
        if (readHead < [packetsArray count]) {
            @autoreleasepool {
                UInt32 packetSize = inNumberOfFrames;
                // 第七步： Remote IO node 的 render callback 中，呼叫 converter 將 packet 轉成 LPCM
                OSStatus status =
                AudioConverterFillComplexBuffer(converter,
                                                KKPlayerConverterFiller,
                                                (__bridge void *)(self),
                                                &packetSize, renderBufferList, NULL);
                if (noErr != status && KKAudioConverterCallbackErr_NoData != status) {
                    [self pause];
                    return -1;
                }
                else if (!packetSize) {
                    inIoData->mNumberBuffers = 0;
                }
                else {
                    // 在這邊改變 renderBufferList->mBuffers[0].mData
                    // 可以產生各種效果
                    inIoData->mNumberBuffers = 1;
                    inIoData->mBuffers[0].mNumberChannels = 2;
                    inIoData->mBuffers[0].mDataByteSize = renderBufferList->mBuffers[0].mDataByteSize;
                    inIoData->mBuffers[0].mData = renderBufferList->mBuffers[0].mData;
                    renderBufferList->mBuffers[0].mDataByteSize = renderBufferSize;
                }
            }
        }
        else {
            inIoData->mNumberBuffers = 0;
            return -1;
        }
    }
    
    return noErr;
}


- (OSStatus)_fillConverterBufferWithBufferlist:(AudioBufferList *)ioData
                             packetDescription:(AudioStreamPacketDescription** )outDataPacketDescription
{
    static AudioStreamPacketDescription aspdesc;
    
    if (readHead >= [packetsArray count]) {
        return KKAudioConverterCallbackErr_NoData;
    }
    
    ioData->mNumberBuffers = 1;
    NSData *packet = packetsArray[readHead];
    void const *data = [packet bytes];
    UInt32 length = (UInt32)[packet length];
    ioData->mBuffers[0].mData = (void *)data;
    ioData->mBuffers[0].mDataByteSize = length;
    
    *outDataPacketDescription = &aspdesc;
    aspdesc.mDataByteSize = length;
    aspdesc.mStartOffset = 0;
    aspdesc.mVariableFramesInPacket = 1;
    
    readHead++;
    return 0;
}

@end


void KKAudioFileStreamPropertyListener(void * inClientData,
                                       AudioFileStreamID inAudioFileStream,
                                       AudioFileStreamPropertyID inPropertyID,
                                       UInt32 * ioFlags)
{
    SimpleAudioUnitPlayer *self = (__bridge SimpleAudioUnitPlayer *)inClientData;
    if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        UInt32 dataSize  = 0;
        OSStatus status = 0;
        AudioStreamBasicDescription audioStreamDescription;
        Boolean writable = false;
        status = AudioFileStreamGetPropertyInfo(inAudioFileStream,
                                                kAudioFileStreamProperty_DataFormat, &dataSize, &writable);
        status = AudioFileStreamGetProperty(inAudioFileStream,
                                            kAudioFileStreamProperty_DataFormat, &dataSize, &audioStreamDescription);
        
        NSLog(@"mSampleRate: %f", audioStreamDescription.mSampleRate);
        NSLog(@"mFormatID: %u", audioStreamDescription.mFormatID);
        NSLog(@"mFormatFlags: %u", audioStreamDescription.mFormatFlags);
        NSLog(@"mBytesPerPacket: %u", audioStreamDescription.mBytesPerPacket);
        NSLog(@"mFramesPerPacket: %u", audioStreamDescription.mFramesPerPacket);
        NSLog(@"mBytesPerFrame: %u", audioStreamDescription.mBytesPerFrame);
        NSLog(@"mChannelsPerFrame: %u", audioStreamDescription.mChannelsPerFrame);
        NSLog(@"mBitsPerChannel: %u", audioStreamDescription.mBitsPerChannel);
        NSLog(@"mReserved: %u", audioStreamDescription.mReserved);
        
        // 第三步： Audio Parser 成功 parse 出 audio 檔案格式，我們根據
        // 檔案格式資訊，建立 converter
        
        [self _createAudioQueueWithAudioStreamDescription:&audioStreamDescription];
    }
}

void KKAudioFileStreamPacketsCallback(void* inClientData,
                                      UInt32 inNumberBytes,
                                      UInt32 inNumberPackets,
                                      const void* inInputData,
                                      AudioStreamPacketDescription* inPacketDescriptions)
{
    // 第四步： Audio Parser 成功 parse 出 packets，我們將這些資料儲存
    // 起來
    
    SimpleAudioUnitPlayer *self = (__bridge SimpleAudioUnitPlayer *)inClientData;
    [self _storePacketsWithNumberOfBytes:inNumberBytes
                         numberOfPackets:inNumberPackets
                               inputData:inInputData
                      packetDescriptions:inPacketDescriptions];
}

OSStatus KKPlayerAURenderCallback(void *userData,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData)
{
    // 第六步： Remote IO node 的 render callback
    SimpleAudioUnitPlayer *self = (__bridge SimpleAudioUnitPlayer *)userData;
    OSStatus status = [self callbackWithNumberOfFrames:inNumberFrames
                                                ioData:ioData busNumber:inBusNumber];
    if (status != noErr) {
        ioData->mNumberBuffers = 0;
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
    }
    return status;
}

OSStatus KKPlayerConverterFiller (AudioConverterRef inAudioConverter,
                                  UInt32* ioNumberDataPackets,
                                  AudioBufferList* ioData,
                                  AudioStreamPacketDescription** outDataPacketDescription,
                                  void* inUserData)
{
    // 第八步： AudioConverterFillComplexBuffer 的 callback
    SimpleAudioUnitPlayer *self = (__bridge SimpleAudioUnitPlayer *)inUserData;
    *ioNumberDataPackets = 0;
    OSStatus result = [self _fillConverterBufferWithBufferlist:ioData
                                             packetDescription:outDataPacketDescription];
    if (result == noErr) {
        *ioNumberDataPackets = 1;
    }
    return result;
}

