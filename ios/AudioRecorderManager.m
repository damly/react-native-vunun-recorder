//
//  AudioRecorderManager.m
//  RNRecorder
//
//  Created by damly on 16/6/25.
//  Copyright © 2016年 damly. All rights reserved.
//

#import "AudioRecorderManager.h"
#import "RCTConvert.h"
#import "RCTBridge.h"
#import "RCTUtils.h"
#import "RCTEventDispatcher.h"
#import <AVFoundation/AVFoundation.h>

NSString *const AudioRecorderEventProgress = @"recordingProgress";
NSString *const AudioRecorderEventFinished = @"recordingFinished";

@implementation AudioRecorderManager {
    
    AVAudioRecorder *_audioRecorder;
    AVAudioPlayer *_audioPlayer;
    
    NSTimeInterval _currentTime;
    id _progressUpdateTimer;
    int _progressUpdateInterval;
    NSDate *_prevProgressUpdateTime;
    NSURL *_audioFileURL;
    NSNumber *_audioQuality;
    NSNumber *_audioEncoding;
    NSNumber *_audioChannels;
    NSNumber *_audioSampleRate;
    AVAudioSession *_recordSession;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (void)sendProgressUpdate {
    if (_audioRecorder && _audioRecorder.recording) {
        _currentTime = _audioRecorder.currentTime;
    } else if (_audioPlayer && _audioPlayer.playing) {
        _currentTime = _audioPlayer.currentTime;
    } else {
        return;
    }
    
    if (_prevProgressUpdateTime == nil ||
        (([_prevProgressUpdateTime timeIntervalSinceNow] * -1000.0) >= _progressUpdateInterval)) {
        [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventProgress body:@{
                                                                                            @"currentTime": [NSNumber numberWithFloat:_currentTime]
                                                                                            }];
        
        _prevProgressUpdateTime = [NSDate date];
    }
}

- (void)stopProgressTimer {
    [_progressUpdateTimer invalidate];
}

- (void)startProgressTimer {
    _progressUpdateInterval = 250;
    _prevProgressUpdateTime = nil;
    
    [self stopProgressTimer];
    
    _progressUpdateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(sendProgressUpdate)];
    [_progressUpdateTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventFinished body:@{
                                                                                        @"status": flag ? @"OK" : @"ERROR",
                                                                                        @"audioFileURL": [_audioFileURL absoluteString]
                                                                                        }];
}

- (NSString *) applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

RCT_EXPORT_METHOD(prepareRecordingAtPath:(NSString *)path sampleRate:(float)sampleRate channels:(nonnull NSNumber *)channels quality:(NSString *)quality)
{
    _prevProgressUpdateTime = nil;
    [self stopProgressTimer];
    
    _audioFileURL = [NSURL fileURLWithPath:path];
    
    // Default options
    _audioQuality = [NSNumber numberWithInt:AVAudioQualityHigh];
    _audioEncoding = [NSNumber numberWithInt:kAudioFormatAppleIMA4];
    _audioChannels = [NSNumber numberWithInt:2];
    _audioSampleRate = [NSNumber numberWithFloat:44100.0];
    
    // Set audio quality from options
    if (quality != nil) {
        if ([quality  isEqual: @"Low"]) {
            _audioQuality =[NSNumber numberWithInt:AVAudioQualityLow];
        } else if ([quality  isEqual: @"Medium"]) {
            _audioQuality =[NSNumber numberWithInt:AVAudioQualityMedium];
        } else if ([quality  isEqual: @"High"]) {
            _audioQuality =[NSNumber numberWithInt:AVAudioQualityHigh];
        }
    }
    
    // Set channels from options
    if (channels != nil) {
        _audioChannels = channels;
    }
    
    // Set audio encoding from options
    _audioEncoding = [NSNumber numberWithInt:kAudioFormatMPEG4AAC];
    // Set sample rate from options
    _audioSampleRate = [NSNumber numberWithFloat:sampleRate];
    
    NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    _audioQuality, AVEncoderAudioQualityKey,
                                    _audioEncoding, AVFormatIDKey,
                                    _audioChannels, AVNumberOfChannelsKey,
                                    _audioSampleRate, AVSampleRateKey,
                                    nil];
    
    NSError *error = nil;
    
    _recordSession = [AVAudioSession sharedInstance];
    [_recordSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    _audioRecorder = [[AVAudioRecorder alloc]
                      initWithURL:_audioFileURL
                      settings:recordSettings
                      error:&error];
    
    _audioRecorder.delegate = self;
    
    if (error) {
        NSLog(@"error: %@", [error localizedDescription]);
        // TODO: dispatch error over the bridge
    } else {
        [_audioRecorder prepareToRecord];
    }
}

RCT_EXPORT_METHOD(startRecording)
{
    if (!_audioRecorder.recording) {
        [self startProgressTimer];
        [_recordSession setActive:YES error:nil];
        [_audioRecorder record];
        
    }
}

RCT_EXPORT_METHOD(stopRecording)
{
    if (_audioRecorder.recording) {
        [_audioRecorder stop];
        [_recordSession setActive:NO error:nil];
        _prevProgressUpdateTime = nil;
    }
}

RCT_EXPORT_METHOD(pauseRecording)
{
    if (_audioRecorder.recording) {
        [self stopProgressTimer];
        [_audioRecorder pause];
    }
}

RCT_EXPORT_METHOD(playRecording)
{
    if (_audioRecorder.recording) {
        NSLog(@"stop the recording before playing");
        return;
        
    } else {
        
        NSError *error;
        
        if (!_audioPlayer.playing) {
            _audioPlayer = [[AVAudioPlayer alloc]
                            initWithContentsOfURL:_audioRecorder.url
                            error:&error];
            _audioPlayer.volume = 1;
            if (error) {
                [self stopProgressTimer];
                NSLog(@"audio playback loading error: %@", [error localizedDescription]);
                // TODO: dispatch error over the bridge
            } else {
                [self startProgressTimer];
                [_audioPlayer play];
            }
        }
    }
}

RCT_EXPORT_METHOD(playAudio:(NSString *)path)
{
    if (_audioRecorder.recording) {
        NSLog(@"stop the recording before playing");
        return;
        
    } else {
        
        NSError *error;
        
        if (!_audioPlayer.playing) {
            NSURL *audioFileURL = [NSURL fileURLWithPath:path];
            _audioPlayer = [[AVAudioPlayer alloc]
                            initWithContentsOfURL:audioFileURL
                            error:&error];
            _audioPlayer.volume = 1;
            if (error) {
                [self stopProgressTimer];
                NSLog(@"audio playback loading error: %@", [error localizedDescription]);
                // TODO: dispatch error over the bridge
            } else {
                [self startProgressTimer];
                [_audioPlayer play];
            }
        }
    }
}

RCT_EXPORT_METHOD(pausePlaying)
{
    if (_audioPlayer.playing) {
        [_audioPlayer pause];
    }
}

RCT_EXPORT_METHOD(stopPlaying)
{
    if (_audioPlayer.playing) {
        [_audioPlayer stop];
    }
}

RCT_EXPORT_METHOD(checkAuthorizationStatus:(RCTPromiseResolveBlock)resolve reject:(__unused RCTPromiseRejectBlock)reject)
{
    AVAudioSessionRecordPermission permissionStatus = [[AVAudioSession sharedInstance] recordPermission];
    switch (permissionStatus) {
        case AVAudioSessionRecordPermissionUndetermined:
            resolve(@("undetermined"));
            break;
        case AVAudioSessionRecordPermissionDenied:
            resolve(@("denied"));
            break;
        case AVAudioSessionRecordPermissionGranted:
            resolve(@("granted"));
            break;
        default:
            reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@("Error checking device authorization status.")));
            break;
    }
}

RCT_EXPORT_METHOD(requestAuthorization:(RCTPromiseResolveBlock)resolve
                  rejecter:(__unused RCTPromiseRejectBlock)reject)
{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if(granted) {
            resolve(@YES);
        } else {
            resolve(@NO);
        }
    }];
}

@end

