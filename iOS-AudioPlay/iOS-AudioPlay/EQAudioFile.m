//
//  EQAudioFile.m
//  iOS-AudioPlay
//
//  Created by admin on 16/1/23.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import "EQAudioFile.h"

static const UInt32 packetPerRead = 15;

@interface EQAudioFile ()
{
@private
    SInt64 _packetOffset;
    NSFileHandle *_fileHandler;
    
    SInt64 _dataOffset;
    NSTimeInterval _packetDuration;
    
    AudioFileID _audioFileID;
}
@end

@implementation EQAudioFile


#pragma mark - init & dealloc
- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType
{
    self = [super init];
    if (self)
    {
        _filePath = filePath;
        _fileType = fileType;
        
        _fileHandler = [NSFileHandle fileHandleForReadingAtPath:_filePath];
        _fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:nil] fileSize];
        if (_fileHandler && _fileSize > 0)
        {
            if ([self _openAudioFile])
            {
                [self _fetchFormatInfo];
            }
        }
        else
        {
            [_fileHandler closeFile];
        }
    }
    return self;
}

- (void)dealloc
{
    [_fileHandler closeFile];
    [self _closeAudioFile];
}

#pragma mark - audiofile
- (BOOL)_openAudioFile
{
    
    /**
     *  打开文件
     *
     *  @param inClientData 上下文信息
     *  @param inReadFunc 当AudioFile需要读音频数据时进行的回调（调用Open和Read方式后同步回调）
     *  @param inWriteFunc 当AudioFile需要写音频数据时进行的回调（写音频文件功能时使用）
     *  @param inGetSizeFunc 当AudioFile需要用到文件的总大小时回调（调用Open和Read方式后同步回调）
     *  @param inSetSizeFunc 当AudioFile需要设置文件的大小时回调（写音频文件功能时使用）
     *  @param inFileTypeHint 和AudioFileStream的open方法中一样是一个帮助AudioFile解析文件的类型提示，如果文件类型确定的话应当传入
     *  @param outAudioFile 返回AudioFile实例对应的AudioFileID，这个ID需要保存起来作为后续一些方法的参数使用
     *
     *  @return 用来判断是否成功打开文件（OSSStatus == noErr）
     */
    OSStatus status = AudioFileOpenWithCallbacks((__bridge void *)self,
                                                 EQAudioFileReadCallBack,
                                                 NULL,
                                                 EQAudioFileGetSizeCallBack,
                                                 NULL,
                                                 _fileType,
                                                 &_audioFileID);
    if (status != noErr)
    {
        _audioFileID = NULL;
        return NO;
    }
    return YES;
    
}

- (void)_fetchFormatInfo
{
    // 获取格式信息
    UInt32 formatListSize;
    
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, NULL);
    if (status == noErr)
    {
        BOOL found = NO;
        AudioFormatListItem *formatList = malloc(formatListSize);
        OSStatus status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyFormatList, &formatListSize, formatList);
        if (status == noErr)
        {
            UInt32 supportedFormatsSize;
            status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
            if (status != noErr)
            {
                free(formatList);
                [self _closeAudioFile];
                return;
            }
            
            UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
            OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
            status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, supportedFormats);
            if (status != noErr)
            {
                free(formatList);
                free(supportedFormats);
                [self _closeAudioFile];
                return;
            }
            
            for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem))
            {
                AudioStreamBasicDescription format = formatList[i].mASBD;
                for (UInt32 j = 0; j < supportedFormatCount; ++j)
                {
                    if (format.mFormatID == supportedFormats[j])
                    {
                        _format = format;
                        found = YES;
                        break;
                    }
                }
            }
            free(supportedFormats);
        }
        free(formatList);
        
        if (!found)
        {
            [self _closeAudioFile];
            return;
        }
        else
        {
            [self _calculatepPacketDuration];
        }
    }
    
    // 获取码率
    UInt32 size = sizeof(_bitRate);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyBitRate, &size, &_bitRate);
    if (status != noErr)
    {
        [self _closeAudioFile];
        return;
    }
    
    size = sizeof(_dataOffset);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyDataOffset, &size, &_dataOffset);
    if (status != noErr)
    {
        [self _closeAudioFile];
        return;
    }
    _audioDataByteCount = _fileSize - _dataOffset;
    
    size = sizeof(_duration);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyEstimatedDuration, &size, &_duration);
    if (status != noErr)
    {
        [self _calculateDuration];
    }
    
    size = sizeof(_maxPacketSize);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &_maxPacketSize);
    if (status != noErr || _maxPacketSize == 0)
    {
        status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMaximumPacketSize, &size, &_maxPacketSize);
        if (status != noErr)
        {
            [self _closeAudioFile];
            return;
        }
    }
}

- (NSData *)fetchMagicCookie
{
    UInt32 cookieSize;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyMagicCookieData, &cookieSize, NULL);
    if (status != noErr)
    {
        return nil;
    }
    
    void *cookieData = malloc(cookieSize);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMagicCookieData, &cookieSize, cookieData);
    if (status != noErr)
    {
        return nil;
    }
    
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);
    
    return cookie;
}

- (void)_closeAudioFile
{
    if (self.available)
    {
        AudioFileClose(_audioFileID);
        _audioFileID = NULL;
    }
}

- (void)close
{
    [self _closeAudioFile];
}

- (void)_calculatepPacketDuration
{
    if (_format.mSampleRate > 0)
    {
        _packetDuration = _format.mFramesPerPacket / _format.mSampleRate;
    }
}

- (void)_calculateDuration
{
    if (_fileSize > 0 && _bitRate > 0)
    {
        _duration = ((_fileSize - _dataOffset) * 8) / _bitRate;
    }
}

- (NSArray *)parseData:(BOOL *)isEof
{
    UInt32 ioNumPackets = packetPerRead;
    UInt32 ioNumBytes = ioNumPackets * _maxPacketSize;
    void * outBuffer = (void *)malloc(ioNumBytes);
    
    AudioStreamPacketDescription * outPacketDescriptions = NULL;
    OSStatus status = noErr;
    if (_format.mFormatID != kAudioFormatLinearPCM)
    {
        UInt32 descSize = sizeof(AudioStreamPacketDescription) * ioNumPackets;
        outPacketDescriptions = (AudioStreamPacketDescription *)malloc(descSize);
        status = AudioFileReadPacketData(_audioFileID, false, &ioNumBytes, outPacketDescriptions, _packetOffset, &ioNumPackets, outBuffer);
    }
    else
    {
        status = AudioFileReadPackets(_audioFileID, false, &ioNumBytes, outPacketDescriptions, _packetOffset, &ioNumPackets, outBuffer);
    }
    
    if (status != noErr)
    {
        *isEof = status == kAudioFileEndOfFileError;
        free(outBuffer);
        return nil;
    }
    
    if (ioNumBytes == 0)
    {
        *isEof = YES;
    }
    
    _packetOffset += ioNumPackets;
    
    if (ioNumPackets > 0)
    {
        NSMutableArray *parsedDataArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < ioNumPackets; ++i)
        {
            AudioStreamPacketDescription packetDescription;
            if (outPacketDescriptions)
            {
                packetDescription = outPacketDescriptions[i];
            }
            else
            {
                packetDescription.mStartOffset = i * _format.mBytesPerPacket;
                packetDescription.mDataByteSize = _format.mBytesPerPacket;
                packetDescription.mVariableFramesInPacket = _format.mFramesPerPacket;
            }
            EQParsedAudioData *parsedData = [EQParsedAudioData parsedAudioDataWithBytes:outBuffer + packetDescription.mStartOffset
                                                                      packetDescription:packetDescription];
            if (parsedData)
            {
                [parsedDataArray addObject:parsedData];
            }
        }
        return parsedDataArray;
    }
    
    return nil;
}

- (void)seekToTime:(NSTimeInterval)time
{
    _packetOffset = floor(time / _packetDuration);
}

- (UInt32)availableDataLengthAtOffset:(SInt64)inPosition maxLength:(UInt32)requestCount
{
    if ((inPosition + requestCount) > _fileSize)
    {
        if (inPosition > _fileSize)
        {
            return 0;
        }
        else
        {
            return (UInt32)(_fileSize - inPosition);
        }
    }
    else
    {
        return requestCount;
    }
}

- (NSData *)dataAtOffset:(SInt64)inPosition length:(UInt32)length
{
    [_fileHandler seekToFileOffset:inPosition];
    return [_fileHandler readDataOfLength:length];
}

#pragma mark - callback
static OSStatus EQAudioFileReadCallBack(void *inClientData,
                                        SInt64 inPosition,
                                        UInt32 requestCount,
                                        void *buffer,
                                        UInt32 *actualCount)
{
    EQAudioFile *audioFile = (__bridge EQAudioFile *)inClientData;
    
    *actualCount = [audioFile availableDataLengthAtOffset:inPosition maxLength:requestCount];
    if (*actualCount > 0)
    {
        NSData *data = [audioFile dataAtOffset:inPosition length:*actualCount];
        memcpy(buffer, [data bytes], [data length]);
    }
    
    return noErr;
}

static SInt64 EQAudioFileGetSizeCallBack(void *inClientData)
{
    EQAudioFile *audioFile = (__bridge EQAudioFile *)inClientData;
    return audioFile.fileSize;
}

#pragma mark - property
- (BOOL)available
{
    return _audioFileID != NULL;
}


@end
