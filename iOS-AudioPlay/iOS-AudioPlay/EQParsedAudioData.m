//
//  EQParsedAudioData.m
//  iOS-AudioPlay
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import "EQParsedAudioData.h"

@implementation EQParsedAudioData

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes
                       packetDescription:(AudioStreamPacketDescription)packetDescription
{
    return [[self alloc] initWithBytes:bytes
                     packetDescription:packetDescription];
}

- (instancetype)initWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)packetDescription
{
    if (bytes == NULL || packetDescription.mDataByteSize == 0)
    {
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _data = [NSData dataWithBytes:bytes length:packetDescription.mDataByteSize];
        _packetDescription = packetDescription;
    }
    return self;
}

@end
