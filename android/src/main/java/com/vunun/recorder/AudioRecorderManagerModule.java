package com.vunun.recorder;


import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import javax.annotation.Nullable;
import java.io.*;

import android.content.res.AssetFileDescriptor;
import android.media.MediaRecorder;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.util.Log;

import java.util.Timer;
import java.util.TimerTask;


public class AudioRecorderManagerModule extends ReactContextBaseJavaModule {
    private final ReactApplicationContext _reactContext;
    private MediaRecorder audioRecorder = null;
    private MediaPlayer   audioPlayer = null;
    private String audioFileName = "";
    private Timer  timer = null;
    private int    currentTime = 0;
    private double sampleRate = 44100.0;
    private int    channels = 2;
    private String audioQuality = "High";
    private String TAG = "wangyuman";

    public AudioRecorderManagerModule(ReactApplicationContext reactContext) {
        super(reactContext);
        _reactContext = reactContext;      
    }
    @Override
    public String getName() {
        return "AudioRecorderManager";
    }

    @ReactMethod
    public void prepareRecordingAtPath(final String path, final double SampleRate,
                                       final int Channels, final String AudioQuality) {
        audioFileName = path;
        sampleRate = SampleRate;
        channels = Channels;

        try {
            if(audioRecorder == null)
                audioRecorder = new MediaRecorder();

            audioRecorder.reset();
            audioRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            audioRecorder.setAudioChannels(Channels);
            audioRecorder.setAudioSamplingRate((int)SampleRate);
            audioRecorder.setOutputFormat(MediaRecorder.OutputFormat.DEFAULT);

            if(AudioQuality.equals("High")) {
                audioQuality = "High";
                audioRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.HE_AAC);
            }
            else if(AudioQuality.equals("Low")) {
                audioQuality = "Low";
                audioRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            }
            else{
                audioQuality = "Medium/ELD";
                audioRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC_ELD);
            }

            audioRecorder.setOutputFile(audioFileName);
            audioRecorder.prepare();
        } catch (IOException e) {
            recordingFail("prepareRecordingAtPath:"+e.getMessage());
        }
    }

    private void sendEvent(ReactContext reactContext,
                           String eventName,
                           @Nullable WritableMap params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    private void recordingFail(String err) {
        WritableMap params = Arguments.createMap();
        params.putBoolean("finished", false);
        params.putString("message", err);
        params.putString("File", audioFileName);
        params.putDouble("SampleRate", sampleRate);
        params.putInt("Channels", channels);
        params.putString("AudioQuality", audioQuality);
        sendEvent(_reactContext, "recordingFinished", params);
    }

    private void recordingSuccess() {
        WritableMap params = Arguments.createMap();
        params.putBoolean("finished", true);
        params.putString("File", audioFileName);
        params.putDouble("SampleRate", sampleRate);
        params.putInt("Channels", channels);
        params.putString("AudioQuality", audioQuality);
        sendEvent(_reactContext, "recordingFinished", params);
    }


    @ReactMethod
    public void startRecording() {

        try {
            currentTime = 0;
            audioRecorder.start();
            startProgress();
        } catch (Exception e) {
            recordingFail("startRecording:"+e.getMessage());
        }
    }

    private void startProgress() {

        stopProgress();

        TimerTask task = new TimerTask() {
            @Override
            public void run() {
                WritableMap params = Arguments.createMap();
                params.putInt("currentTime", currentTime);
                sendEvent(_reactContext, "recordingProgress", params);
                currentTime = currentTime + 1;

            }
        };
        timer = new Timer();
        timer.schedule(task, 1000, 1000);
    }

    private void stopProgress() {
        if(timer != null) {
            timer.cancel();
            timer = null;
            currentTime = 0;
        }
    }

    @ReactMethod
    public void stopRecording() {
        stopProgress();
        if (audioRecorder != null) {
            try {
                audioRecorder.stop();
                recordingSuccess();
            } catch (Exception e) {
                recordingFail("stopRecording:"+e.getMessage());
            }

          //  audioRecorder.release();
           // audioRecorder = null;
        }
    }

    @ReactMethod
    public void playRecording() {

        Log.v(TAG, audioFileName);

        if(audioFileName.isEmpty()) {
            recordingFail("playRecording:audioFileName is null");
        }

        try {
            stopRecording();
            audioPlayer = new MediaPlayer();
            audioPlayer.reset();
            audioPlayer.setDataSource(audioFileName);
            audioPlayer.prepare();
            audioPlayer.start();
            startProgress();
            audioPlayer.setOnCompletionListener(new OnCompletionListener() {
                @Override
                public void onCompletion(MediaPlayer mp) {
                    audioPlayer.reset();
                    audioPlayer.release();
                    audioPlayer = null;
                    stopProgress();
                    recordingSuccess();
                }
            });
        }catch (IOException ex) {
            recordingFail("playRecording:"+ex.getMessage());
        }

    }

    @ReactMethod
    public void playAudio(String file) {
        try {
            stopRecording();
            audioPlayer = new MediaPlayer();
            audioPlayer.reset();
            audioPlayer.setDataSource(file);
            audioPlayer.prepare();
            audioPlayer.start();
            startProgress();
            audioPlayer.setOnCompletionListener(new OnCompletionListener() {
                @Override
                public void onCompletion(MediaPlayer mp) {
                    audioPlayer.reset();
                    audioPlayer.release();
                    audioPlayer = null;
                    stopProgress();
                    recordingSuccess();
                }
            });
        }catch (IOException ex) {
            recordingFail("playAudio:"+ex.getMessage());
        }
    }

    @ReactMethod
    public void stopPlaying() {
        if(audioPlayer != null) {
            audioPlayer.stop();
            audioPlayer = null;
            stopProgress();
        }
    }

}