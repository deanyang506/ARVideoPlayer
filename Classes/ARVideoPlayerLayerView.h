//
//  ARVideoPlayerLayerView.h
//  AipaiReconsitution
//
//  Created by Dean.Yang on 2017/7/24.
//  Copyright © 2017年 Dean.Yang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVPlayer;
typedef NSString *AVLayerVideoGravity;
@interface ARVideoPlayerLayerView : UIView

- (void)setPlayer:(AVPlayer *)player;
- (void)setVideoFillMode:(AVLayerVideoGravity)fillMode;

@end
