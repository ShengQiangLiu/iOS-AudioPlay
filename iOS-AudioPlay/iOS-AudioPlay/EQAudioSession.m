//
//  EQAudioSession.m
//  iOS-AudioPlay
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import "EQAudioSession.h"

NSString *const EQAudioSessionRouteChangeNotification = @"EQAudioSessionRouteChangeNotification";
NSString *const EQAudioSessionRouteChangeReason = @"EQAudioSessionRouteChangeReason";
NSString *const EQAudioSessionInterruptionNotification = @"EQAudioSessionInterruptionNotification";
NSString *const EQAudioSessionInterruptionStateKey = @"EQAudioSessionInterruptionStateKey";
NSString *const EQAudioSessionInterruptionTypeKey = @"EQAudioSessionInterruptionTypeKey";


static void EQAudioSessionInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
    AudioSessionInterruptionType interruptionType = kAudioSessionInterruptionType_ShouldNotResume;
    UInt32 interruptionTypeSize = sizeof(interruptionType);
    AudioSessionGetProperty(kAudioSessionProperty_InterruptionType,
                            &interruptionTypeSize,
                            &interruptionType);
    
    NSDictionary *userInfo = @{EQAudioSessionInterruptionStateKey:@(inInterruptionState),
                               EQAudioSessionInterruptionTypeKey:@(interruptionType)};
    __unsafe_unretained EQAudioSession *audioSession = (__bridge EQAudioSession *)inClientData;
    [[NSNotificationCenter defaultCenter] postNotificationName:EQAudioSessionInterruptionNotification object:audioSession userInfo:userInfo];
}

static void EQAudioSessionRouteChangeListener(void *inClientData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue)
{
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange)
    {
        return;
    }
    CFDictionaryRef routeChangeDictionary = inPropertyValue;
    CFNumberRef routeChangeReasonRef = CFDictionaryGetValue (routeChangeDictionary, CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
    SInt32 routeChangeReason;
    CFNumberGetValue (routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
    
    NSDictionary *userInfo = @{EQAudioSessionRouteChangeReason:@(routeChangeReason)};
    __unsafe_unretained EQAudioSession *audioSession = (__bridge EQAudioSession *)inClientData;
    [[NSNotificationCenter defaultCenter] postNotificationName:EQAudioSessionRouteChangeNotification object:audioSession userInfo:userInfo];
}



@implementation EQAudioSession


+ (id)sharedInstance
{
    static dispatch_once_t once;
    static EQAudioSession *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [self _initializeAudioSession];
    }
    return self;
}

- (void)dealloc
{
    AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange, EQAudioSessionRouteChangeListener, (__bridge void *)self);
}

#pragma mark - private
- (void)_errorForOSStatus:(OSStatus)status error:(NSError *__autoreleasing *)outError
{
    if (status != noErr && outError != NULL)
    {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
}


/**
 *  初始化AudioSession
 */
- (void)_initializeAudioSession
{
    /**
     *  初始化AudioSession
     *
     *  @param NULL                               前两个参数一般填NULL表示AudioSession运行在主线程上（但并不代表音频的相关处理运行在主线程上，只是AudioSession）
     *  @param NULL
     *  @param EQAudioSessionInterruptionListener 传入一个AudioSessionInterruptionListener类型的方法，作为AudioSession被打断时的回调
     *  @param self                               代表打断回调时需要附带的对象
     *
     *  @return <#return value description#>
     */
    AudioSessionInitialize(NULL, NULL, EQAudioSessionInterruptionListener, (__bridge void *)self);
    
    
    /**
     *  监听RouteChange事件
     *  如果想要实现类似于“拔掉耳机就把歌曲暂停”的功能就需要监听RouteChange事件
     *
     *  @param kAudioSessionProperty_AudioRouteChange <#kAudioSessionProperty_AudioRouteChange description#>
     *  @param EQAudioSessionRouteChangeListener      <#EQAudioSessionRouteChangeListener description#>
     *  @param void                                   <#void description#>
     *
     *  @return <#return value description#>
     */
    AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, EQAudioSessionRouteChangeListener, (__bridge void *)self);
}

#pragma mark - public
- (BOOL)setActive:(BOOL)active error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioSessionSetActive(active);
    if (status == kAudioSessionNotInitialized)
    {
        [self _initializeAudioSession];
        status = AudioSessionSetActive(active);
    }
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)setActive:(BOOL)active options:(UInt32)options error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioSessionSetActiveWithFlags(active,options);
    if (status == kAudioSessionNotInitialized)
    {
        [self _initializeAudioSession];
        status = AudioSessionSetActiveWithFlags(active,options);
    }
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)setCategory:(UInt32)category error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,sizeof(category),&category);
    if (status == kAudioSessionNotInitialized)
    {
        [self _initializeAudioSession];
        status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,sizeof(category),&category);
    }
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)setProperty:(AudioSessionPropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError *__autoreleasing *)outError
{

    OSStatus status = AudioSessionSetProperty(propertyID,dataSize,data);
    if (status == kAudioSessionNotInitialized)
    {
        [self _initializeAudioSession];
        status = AudioSessionSetProperty(propertyID,dataSize,data);
    }
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)addPropertyListener:(AudioSessionPropertyID)propertyID listenerMethod:(AudioSessionPropertyListener)listenerMethod context:(void *)context error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioSessionAddPropertyListener(propertyID,listenerMethod,context);
    if (status == kAudioSessionNotInitialized)
    {
        [self _initializeAudioSession];
        status = AudioSessionAddPropertyListener(propertyID,listenerMethod,context);
    }
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (BOOL)removePropertyListener:(AudioSessionPropertyID)propertyID listenerMethod:(AudioSessionPropertyListener)listenerMethod context:(void *)context error:(NSError *__autoreleasing *)outError
{
    OSStatus status = AudioSessionRemovePropertyListenerWithUserData(propertyID,listenerMethod,context);
    if (status == kAudioSessionNotInitialized)
    {
        [self _initializeAudioSession];
        status = AudioSessionRemovePropertyListenerWithUserData(propertyID,listenerMethod,context);
    }
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}


/**
 *  判断是否插了耳机
 *
 *  @return <#return value description#>
 */
+ (BOOL)usingHeadset
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    
    CFStringRef route;
    UInt32 propertySize = sizeof(CFStringRef);
    AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route);
    
    BOOL hasHeadset = NO;
    if((route == NULL) || (CFStringGetLength(route) == 0))
    {
        // Silent Mode
    }
    else
    {
        /* Known values of route:
         * "Headset"
         * "Headphone"
         * "Speaker"
         * "SpeakerAndMicrophone"
         * "HeadphonesAndMicrophone"
         * "HeadsetInOut"
         * "ReceiverAndMicrophone"
         * "Lineout"
         */
        NSString* routeStr = (__bridge NSString*)route;
        NSRange headphoneRange = [routeStr rangeOfString : @"Headphone"];
        NSRange headsetRange = [routeStr rangeOfString : @"Headset"];
        
        if (headphoneRange.location != NSNotFound)
        {
            hasHeadset = YES;
        }
        else if(headsetRange.location != NSNotFound)
        {
            hasHeadset = YES;
        }
    }
    
    if (route)
    {
        CFRelease(route);
    }
    
    return hasHeadset;
}


/**
 *  判断是否开了Airplay
 *
 *  @return <#return value description#>
 */
+ (BOOL)isAirplayActived
{
    CFDictionaryRef currentRouteDescriptionDictionary = nil;
    UInt32 dataSize = sizeof(currentRouteDescriptionDictionary);
    AudioSessionGetProperty(kAudioSessionProperty_AudioRouteDescription, &dataSize, &currentRouteDescriptionDictionary);
    
    BOOL airplayActived = NO;
    if (currentRouteDescriptionDictionary)
    {
        CFArrayRef outputs = CFDictionaryGetValue(currentRouteDescriptionDictionary, kAudioSession_AudioRouteKey_Outputs);
        if(outputs != NULL && CFArrayGetCount(outputs) > 0)
        {
            CFDictionaryRef currentOutput = CFArrayGetValueAtIndex(outputs, 0);
            //Get the output type (will show airplay / hdmi etc
            CFStringRef outputType = CFDictionaryGetValue(currentOutput, kAudioSession_AudioRouteKey_Type);
            
            airplayActived = (CFStringCompare(outputType, kAudioSessionOutputRoute_AirPlay, 0) == kCFCompareEqualTo);
        }
        CFRelease(currentRouteDescriptionDictionary);
    }
    return airplayActived;
}


@end
