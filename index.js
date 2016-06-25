'use strict';

import {
    NativeModules,
    NativeAppEventEmitter,
    DeviceEventEmitter
} from 'react-native';

var AudioRecorderManager = NativeModules.AudioRecorderManager;

var AudioRecorder = {
    prepareRecordingAtPath: function(path, options) {
        var defaultOptions = {
            SampleRate: 44100.0,
            Channels: 2,
            AudioQuality: 'High'
        };
        var recordingOptions = {...defaultOptions, ...options};

        AudioRecorderManager.prepareRecordingAtPath(
            path,
            recordingOptions.SampleRate,
            recordingOptions.Channels,
            recordingOptions.AudioQuality
        );

        if (this.progressSubscription) this.progressSubscription.remove();
        this.progressSubscription = NativeAppEventEmitter.addListener('recordingProgress',
            (data) => {
                if (this.onProgress) {
                    this.onProgress(data);
                }
            }
        );

        if (this.finishedSubscription) this.finishedSubscription.remove();
        this.finishedSubscription = NativeAppEventEmitter.addListener('recordingFinished',
            (data) => {
                if (this.onFinished) {
                    this.onFinished(data);
                }
            }
        );
    },
    startRecording: function() {
        AudioRecorderManager.startRecording();
    },
    stopRecording: function() {
        AudioRecorderManager.stopRecording();
    },
    playRecording: function() {
        AudioRecorderManager.playRecording();
    },
    stopPlaying: function() {
        AudioRecorderManager.stopPlaying();
    },
};

module.exports = {AudioRecorder};