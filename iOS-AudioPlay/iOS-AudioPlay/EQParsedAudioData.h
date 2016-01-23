//
//  EQParsedAudioData.h
//  iOS-AudioPlay
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>


@interface EQParsedAudioData : NSObject

@property (nonatomic,readonly) NSData *data;
@property (nonatomic,readonly) AudioStreamPacketDescription packetDescription;

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes
                       packetDescription:(AudioStreamPacketDescription)packetDescription;

@end
