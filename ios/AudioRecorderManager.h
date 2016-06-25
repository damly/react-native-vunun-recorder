//
//  AudioRecorderManager.h
//  RNRecorder
//
//  Created by damly on 16/6/25.
//  Copyright © 2016年 damly. All rights reserved.
//

#ifndef AudioRecorderManager_h
#define AudioRecorderManager_h

#import "RCTBridgeModule.h"
#import "RCTLog.h"
#import <AVFoundation/AVFoundation.h>

@interface AudioRecorderManager : NSObject <RCTBridgeModule, AVAudioRecorderDelegate>

@end

#endif /* AudioRecorderManager_h */
