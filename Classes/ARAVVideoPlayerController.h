//
//  ARAVVideoPlayerController.h
//  AipaiReconsitution
//
//  Created by Dean.Yang on 2017/7/24.
//  Copyright © 2017年 Dean.Yang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ARMediaPlayerService.h"

typedef NS_ENUM(NSInteger, ARAVVideoPlayerState) {
    ARAVVideoPlayerStateUnKnow,             // 为初始化的
    ARAVVideoPlayerStateReadlyToPlay,       // 已准备好等待播放
    ARAVVideoPlayerStatePlaying,            // 播放中
    ARAVVideoPlayerStatePaused,             // 已暂停
    ARAVVideoPlayerStateStoped              // 已停止
};

typedef NS_ENUM(NSInteger, ARAVVideoScalingMode) {
    ARAVVideoScalingModeAspectFit,
    ARAVVideoScalingModeCenter,
    ARAVVideoScalingModeAspectFill,
    ARAVVideoScalingModeFill
};

@class ARAVVideoPlayerController;
@protocol ARAVVideoPlayerDelegate <NSObject>
@optional

/**
    完成播放视频回调
    @param playerController 播放器
 */
- (void)ARAVVideoPlayerControllerDidFinshPlayVideo:(ARAVVideoPlayerController *)playerController;

/**
    完成了预加载
    @param playable 预加载是否可以达到播放
 */
- (void)ARAVVideoPlayerController:(ARAVVideoPlayerController *)playerController didPrepareToPlay:(BOOL)playable;

/**
    播放器的加载状态发生了改变
 */
- (void)ARAVVideoPlayerController:(ARAVVideoPlayerController *)playerController didChangedState:(ARAVVideoPlayerState)state;

/**
    视频播放进度回调
    @param progress 0~1
 */
- (void)ARAVVideoPlayerController:(ARAVVideoPlayerController *)playerController playbackProgress:(double)progress;

/**
    视频缓冲进度回调
    @param progress 0~1
 */
- (void)ARAVVideoPlayerController:(ARAVVideoPlayerController *)playerController bufferProgress:(double)progress;

/**
    视频播放器出错回调
    @param error 错误信息
 */
- (void)ARAVVideoPlayerController:(ARAVVideoPlayerController *)playerController reciveError:(NSError *)error;

/**
    缓冲条为空时回调
 */
- (void)ARAVVideoPlayerControllerPlayBufferEmpty:(ARAVVideoPlayerController *)playerController;

/**
    缓冲条缓冲到可以播放时回调
 */
- (void)ARAVVideoPlayerControllerBufferToPlay:(ARAVVideoPlayerController *)playerController;

@end

@interface ARAVVideoPlayerController : NSObject <ARMediaPlayerService>

@property (nonatomic, assign, readonly) ARAVVideoPlayerState state;

/**
    图像渲染层视图
    可设置视图内容模式setContentMode
 */
@property (nonatomic, strong, readonly) UIView *view;
@property (nonatomic, assign, readonly) CGSize naturalSize; // 视频原始大小

// default is ARAVVideoScalingModeFill (填充)
@property (nonatomic, assign) ARAVVideoScalingMode scalingMode;

/**
    http/htttps
    file
 */

+ (instancetype)playerWithUrl:(NSString *)aUrl delegate:(id<ARAVVideoPlayerDelegate>)delegate;
@property (nonatomic, strong) NSURL *url;

@property (nonatomic, weak) id<ARAVVideoPlayerDelegate> delegate;
@property (nonatomic, assign) BOOL autoPlay; // 自动播放

// 截取当前时间的缩略图
- (UIImage *)thumbnailImageAtCurrentTime;

@end
