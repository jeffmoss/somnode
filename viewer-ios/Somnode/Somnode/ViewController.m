//
//  ViewController.m
//  Somnode
//
//  Created by Jeff Moss on 3/18/18.
//  Copyright © 2018 Jeff Moss. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "ViewController.h"

@interface ViewController ()
{
    AVAudioEngine     *_engine;
    AVAudioPlayerNode *_player;
    AVAudioMixerNode  *_mixer;
    AVAudioFile       *_file;
    AVAudioPCMBuffer  *_buffer;
    __weak IBOutlet UIButton *playButton;
    __weak IBOutlet UILabel  *infoLabel;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self createPlayerEngine];
    [self startEngine];
}

// Create audio player object, engine object and attach them
- (void)createPlayerEngine {
    NSError *error;
    BOOL success = NO;

    // Construct URL to sound file
    NSString *path = [NSString stringWithFormat:@"%@/8k16bitpcm.wav", [[NSBundle mainBundle] resourcePath]];
    NSURL *soundUrl = [NSURL fileURLWithPath:path];
    
    _file = [[AVAudioFile alloc] initForReading:soundUrl error:&error];
    _player = [[AVAudioPlayerNode alloc] init];
    _engine = [[AVAudioEngine alloc] init];
    _mixer = [_engine mainMixerNode];

    [_engine attachNode:_player];
    [_engine connect:_player to:_mixer format:[_file processingFormat]];
}

- (void)startEngine {
    /*  Starts the audio hardware via the AVAudioInputNode and/or AVAudioOutputNode instances in
     the engine. Audio begins flowing through the engine. */
    if (!_engine.isRunning) {
        NSError *error;
        BOOL success;
        success = [_engine startAndReturnError:&error];
        NSAssert(success, @"couldn't start engine, %@", [error localizedDescription]);
        NSLog(@"Started Engine");
    }
}

- (IBAction)sineClick:(id)sender {
    if ( [_player isPlaying] ) {
        [_player stop];
    }
//    for(int i = 0; i < _buffer.frameLength; i+=1 {
//        var val = sinf(441.0*Float(i)*2*Float(M_PI)/sr)
//        
//        buffer.floatChannelData.memory[i] = val * 0.5
//    }
}

- (IBAction)playClick:(id)sender {
    NSError *error;
    BOOL success = NO;

    // Create a custom audio format
//    AVAudioChannelLayout *chLayout = [[AVAudioChannelLayout alloc] initWithLayoutTag:kAudioChannelLayoutTag_Mono];
//
//    AVAudioFormat *chFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
//                                                               sampleRate:8000.0
//                                                                 channels:2
//                                                              interleaved:NO
//                                                            channelLayout:chLayout];

    // Create PCM audio buffer
    _buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:[_file processingFormat] frameCapacity:(AVAudioFrameCount)[_file length]];
    _buffer.frameLength = 100;

    success = [_file readIntoBuffer:_buffer error:nil];

    NSAssert(success, @"couldn't read 8k16bitpcm.wav into buffer, %@", [error localizedDescription]);

    [_player scheduleBuffer:_buffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
    [_player play];
}

- (IBAction)streamClick:(id)sender {
    infoLabel.text=[NSString stringWithFormat:@"Connecting..."];
    NSString *urlStr = @"http://192.168.1.108:9999";
    if (![urlStr isEqualToString:@""]) {
        NSURL *website = [NSURL URLWithString:urlStr];
        if (!website) {
            NSLog(@"%@ is not a valid URL", urlStr);
            return;
        }
        
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)[website host], 9999, &readStream, &writeStream);
        
        NSInputStream *inputStream = (__bridge_transfer NSInputStream *)readStream;
        NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;
        [inputStream setDelegate:self];
        [outputStream setDelegate:self];
        [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [inputStream open];
        [outputStream open];
        
        /* Read data from the input stream */
        
    }
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch(eventCode) {
        case NSStreamEventOpenCompleted:
        {
            infoLabel.text=[NSString stringWithFormat:@"Connected!"];
            break;
        }
        case NSStreamEventNone:
        {
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
            infoLabel.text=[NSString stringWithFormat:@"Receiving..."];
            uint8_t buf[1024];
            NSInteger len = 0;
            len = [(NSInputStream *)stream read:buf maxLength:1024];
            if(len) {
                if(len > 0) {
                    NSMutableData* data=[[NSMutableData alloc] initWithLength:0];
                    
                    [data appendBytes: (const void *)buf length:len];
                    
                    NSString *s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                    
                    
                }
            } else {
                NSLog(@"no buffer!");
            }
            break;
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
