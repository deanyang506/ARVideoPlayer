//
//  ARMediaPlayerService.h
//  AipaiReconsitution
//
//  Created by Dean.Yang on 2017/7/24.
//  Copyright © 2017年 Dean.Yang. All rights reserved.
//

#import <Foundation/Foundation.h>



@protocol ARMediaPlayerService <NSObject>

- (void)prepareToPlay;
- (void)play;
- (void)pause;
- (void)stop;

- (void)seekToTime:(NSTimeInterval)time completion:(void(^)(BOOL finished))completion;

@property (nonatomic, assign, readonly) BOOL isSeeking;;
@property (nonatomic, assign, readonly) BOOL isPrepareToPlay; // 预加载是否完成

@property (nonatomic, assign ,readonly) NSTimeInterval currentPlaybackTime;
@property (nonatomic, assign ,readonly) NSTimeInterval duration;
@property (nonatomic, assign ,readonly) NSTimeInterval playableDuration;

/** 设置播放速率，0.0表示暂停，1.0正常播放 最高2.0 具体值（0, 0.5, 0.666667, 0.8, 1.0, 1.25, 1.5, 2.0）*/
@property (nonatomic) float playbackRate;
/** 设置播音量 0 ~ 1 */
@property (nonatomic) float playbackVolume;
/** 设置请求头，预加载前有效 */
@property NSDictionary *headers;

@end
