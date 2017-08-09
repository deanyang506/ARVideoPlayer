//
//  ARVideoPlayerLayerView.m
//  AipaiReconsitution
//
//  Created by Dean.Yang on 2017/7/24.
//  Copyright © 2017年 Dean.Yang. All rights reserved.
//

#import "ARVideoPlayerLayerView.h"
#import <AVFoundation/AVFoundation.h>

@implementation ARVideoPlayerLayerView {
    NSString* _videoFillMode;
}

+ (Class)layerClass { // default is CALayer，AVPlayerlayer instead
    return [AVPlayerLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _videoFillMode = AVLayerVideoGravityResizeAspect;
    }
    return self;
}

- (void)setPlayer:(AVPlayer *)player {
    [(AVPlayerLayer *)[self layer] setPlayer:player];
    [self setVideoFillMode:_videoFillMode];
}

- (void)setVideoFillMode:(AVLayerVideoGravity)fillMode {
    _videoFillMode = fillMode;
    AVPlayerLayer *playerLayer = (AVPlayerLayer*)[self layer];
    playerLayer.videoGravity = fillMode;
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    [super setContentMode:contentMode];
    
    switch (contentMode) {
        case UIViewContentModeScaleToFill:
            [self setVideoFillMode:AVLayerVideoGravityResize];
            break;
        case UIViewContentModeCenter:
            [self setVideoFillMode:AVLayerVideoGravityResizeAspect];
            break;
        case UIViewContentModeScaleAspectFill:
            [self setVideoFillMode:AVLayerVideoGravityResizeAspectFill];
            break;
        case UIViewContentModeScaleAspectFit:
            [self setVideoFillMode:AVLayerVideoGravityResizeAspect];
        default:
            break;
    }
}

@end
