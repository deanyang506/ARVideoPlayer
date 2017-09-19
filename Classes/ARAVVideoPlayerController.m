//
//  ARAVVideoPlayerController.m
//  AipaiReconsitution
//
//  Created by Dean.Yang on 2017/7/24.
//  Copyright © 2017年 Dean.Yang. All rights reserved.
//

#import "ARAVVideoPlayerController.h"
#import <AVFoundation/AVFoundation.h>
#import "ARVideoPlayerLayerView.h"
#import "ARVideoResourceLoader.h"

inline static bool isFloatZero(float value) {
    return fabsf(value) <= 0.00001f;
}

static NSError *createError(NSInteger code,NSString *description, NSString *reason) {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                               description, NSLocalizedDescriptionKey,
                               reason, NSLocalizedFailureReasonErrorKey,
                               nil];
    return [NSError errorWithDomain:@"ARAVVideoPlayerController" code:code userInfo:userInfo];
}

@interface ARAVVideoPlayerController()

@property (nonatomic, assign, readwrite) ARAVVideoPlayerState state;
@property (nonatomic, assign) BOOL isShutdown;
@end

@implementation ARAVVideoPlayerController {
    AVPlayer*                   _player;
    AVPlayerItem*               _playerItem;
    AVURLAsset*                 _urlAsset;
    id                          _playTimerObserve;
    ARVideoPlayerLayerView*     _view;
    
    BOOL                _isCompleted;
    BOOL                _isSeeking;
    NSTimeInterval      _seekingTime;
    BOOL _isPrepareToPlay;
    
    float   _playbackVolume;
    float   _playbackRate;
}

@synthesize isSeeking = _isSeeking;
@synthesize isPrepareToPlay = _isPrepareToPlay;

@synthesize playbackVolume = _playbackVolume;
@synthesize playbackRate = _playbackRate;
@synthesize headers = _headers;

#pragma mark - life cycle

- (void)dealloc {
    [self shutDown];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    if (self = [super init]) {
        _view = [[ARVideoPlayerLayerView alloc] initWithFrame:CGRectZero];
        self.scalingMode = ARAVVideoScalingModeFill;
        
        _playbackRate = 1.0; // rate default
        _playbackVolume = 1.0;
    }
    
    return self;
}

#pragma mark - public

- (instancetype)initWithUrl:(NSString *)aUrl delegate:(id<ARAVVideoPlayerDelegate>)delegate {
    if (self = [self init]) {
        
        NSURL *url;
        if (aUrl == nil) {
            aUrl = @"";
        }
        
        if ([aUrl rangeOfString:@"/"].location == 0) {
            url = [NSURL fileURLWithPath:aUrl];
        } else {
            url = [NSURL URLWithString:aUrl];
        }
        
        self.url = url;
        _delegate = delegate;
    }
    
    return self;
}

+ (instancetype)playerWithUrl:(NSString *)aUrl delegate:(id<ARAVVideoPlayerDelegate>)delegate {
    return [[[self class] alloc] initWithUrl:aUrl delegate:delegate];
}

#pragma mark - setter & getter

- (void)setUrl:(NSURL *)url {
    if ([url isFileURL]) {
        _url = url;
    } else {
        NSString *scheme = [url scheme];
        if (scheme && ([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame ||
                       [scheme caseInsensitiveCompare:@"https"] == NSOrderedSame)) {
            _url = url;
        }
    }
}

- (void)setState:(ARAVVideoPlayerState)state {
    if (!(_state == state)) {
        _state = state;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(ARAVVideoPlayerController:didChangedState:)]) {
                [self.delegate ARAVVideoPlayerController:self didChangedState:_state];
            }
        });
    }
}

- (void)setScalingMode:(ARAVVideoScalingMode)scalingMode {
    _scalingMode = scalingMode;
    switch (scalingMode) {
        case ARAVVideoScalingModeCenter:
            [_view setContentMode:UIViewContentModeCenter];
            break;
        case ARAVVideoScalingModeAspectFit:
            [_view setContentMode:UIViewContentModeScaleAspectFit];
            break;
        case ARAVVideoScalingModeAspectFill:
            [_view setContentMode:UIViewContentModeScaleAspectFill];
            break;
        case ARAVVideoScalingModeFill:
            [_view setContentMode:UIViewContentModeScaleToFill];
            break;
    }
}

- (CGSize)naturalSize {
    if (_urlAsset == nil)
        return CGSizeZero;
    
    NSArray<AVAssetTrack *> *videoTracks = [_urlAsset tracksWithMediaType:AVMediaTypeVideo];
    if (videoTracks == nil || videoTracks.count <= 0)
        return CGSizeZero;
    
    return [videoTracks objectAtIndex:0].naturalSize;
}

#pragma mark - observer

- (void)registerObserver {
    
    if (_player) {
        [_player addObserver:self
                      forKeyPath:@"rate"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
    }
    
    if (_playerItem) {
        [_playerItem addObserver:self
                      forKeyPath:@"status"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
        
        [_playerItem addObserver:self
                      forKeyPath:@"loadedTimeRanges"
                         options:NSKeyValueObservingOptionNew
                         context:nil];
        
        [_playerItem addObserver:self forKeyPath:@"playbackBufferEmpty"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
        
        [_playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
    }
}

- (void)removeObserver {
    @try {
        [_player removeObserver:self forKeyPath:@"rate" context:nil];
        [_playerItem removeObserver:self forKeyPath:@"status" context:nil];
        [_playerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
        [_playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty" context:nil];
        [_playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp" context:nil];
    } @catch (NSException *exception) {
        
    } @finally {
        
    }
}

- (void)registerPlayTimerObserver {
    __weak typeof(self) weakSelf = self;
    _playTimerObserve = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:nil usingBlock:^(CMTime time) {
        __strong typeof(weakSelf) self = weakSelf;
        [self observerForPlayTimer:time];
    }];
}

- (void)registerPlayerItemNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:_playerItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemFailedToPlayToEndTime:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:_playerItem];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == _player) {
        if ([keyPath isEqualToString:@"rate"]) {
            _playbackRate = [change[NSKeyValueChangeNewKey] floatValue];
            if (!isFloatZero(_player.rate)) {
                if (!_playerItem.isPlaybackBufferEmpty) {
                    self.state = ARAVVideoPlayerStatePlaying;
                }
            } else {
                if (_playerItem.status == AVPlayerItemStatusReadyToPlay) {
                    self.state = ARAVVideoPlayerStatePaused;
                }
            }
        }
    } else if (object == _playerItem) {
        if ([keyPath isEqualToString:@"status"]) {
            switch (_playerItem.status) {
                case AVPlayerItemStatusReadyToPlay: {
                    if (_isPrepareToPlay) {
                        return;
                    }
                    _isPrepareToPlay = YES;
                    self.state = ARAVVideoPlayerStateReadlyToPlay;
                    [self assetToPrepareForPlayback:nil];
                }
                    break;
                case AVPlayerItemStatusFailed:
                    [self onError:_playerItem.error];
                    break;
                default:break;
            }
        } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            [self didPlayableDurationUpdate];
        } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            if ([change[NSKeyValueChangeNewKey] isEqualToValue:change[NSKeyValueChangeOldKey]]) {
                return;
            }
            if (!_playerItem.isPlaybackBufferEmpty) {
                 return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(ARAVVideoPlayerControllerPlayBufferEmpty:)]) {
                    [self.delegate ARAVVideoPlayerControllerPlayBufferEmpty:self];
                }
            });
        } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            if ([change[NSKeyValueChangeNewKey] isEqualToValue:change[NSKeyValueChangeOldKey]]) {
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(ARAVVideoPlayerControllerBufferToPlay:)]) {
                    [self.delegate ARAVVideoPlayerControllerBufferToPlay:self];
                }
            });
        }
    }
}

- (void)observerForPlayTimer:(CMTime)time {
    NSArray *loadedRanges = _playerItem.seekableTimeRanges;
    if (loadedRanges.count > 0 && _playerItem.duration.timescale != 0) {
        CGFloat currentSecond = [self currentPlaybackTime];
        double playbackProgress = currentSecond / [self duration];
        if ([self.delegate respondsToSelector:@selector(ARAVVideoPlayerController:playbackProgress:)]) {
            [self.delegate ARAVVideoPlayerController:self playbackProgress:playbackProgress];
        }
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    
    if (_state == ARAVVideoPlayerStateStoped) {
        return;
    }
    
    _isCompleted = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(ARAVVideoPlayerControllerDidFinshPlayVideo:)]) {
            [self.delegate ARAVVideoPlayerControllerDidFinshPlayVideo:self];
        }
    });
}

- (void)playerItemFailedToPlayToEndTime:(NSNotification *)notification {
    
    if (_state == ARAVVideoPlayerStateStoped) {
        return;
    }
    
    [self onError:[notification.userInfo objectForKey:@"error"]];
}

- (void)didPlayableDurationUpdate {
    NSTimeInterval timeInterval = [self playableDuration];
    double loadedProgress = timeInterval * 1.0 / [self duration];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(ARAVVideoPlayerController:bufferProgress:)]) {
            [self.delegate ARAVVideoPlayerController:self bufferProgress:loadedProgress];
        }
    });
}

#pragma mark - private

- (void)didPrepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys {
    
    for (NSString *thisKey in requestedKeys) {
        NSError *error = nil;
        AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
        if (keyStatus == AVKeyValueStatusFailed) {
            [self assetToPrepareForPlayback:error];
            return;
        } else if (keyStatus == AVKeyValueStatusCancelled) {
            [asset cancelLoading];
            error = createError(-1, @"player item is cancelled", nil);
            [self assetToPrepareForPlayback:error];
            return;
        }
    }
    
    if (!asset.playable) {
        NSError *assetCannotBePlayedError = createError(1, @"asset cannot play", nil);
        [self assetToPrepareForPlayback:assetCannotBePlayedError];
        return;
    }
    
    _playerItem = [AVPlayerItem playerItemWithAsset:asset];
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    [_view setPlayer:_player];
    
    [self registerObserver];
    [self registerPlayTimerObserver];
    [self registerPlayerItemNotification];
}

- (void)assetToPrepareForPlayback:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(ARAVVideoPlayerController:didPrepareToPlay:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate ARAVVideoPlayerController:self didPrepareToPlay:error == nil];
        });
    }
    
    if (error) {
        [self onError:error];
    } else {
        if (self.autoPlay) {
            [self play];
        }
    }
}

- (void)clearUp {
    _state = ARAVVideoPlayerStateUnKnow;
    _isPrepareToPlay = NO;
    _isCompleted = NO;
    _isSeeking = NO;
    _seekingTime = 0.0;
}

#pragma mark - ARMediaPlayerService method

- (void)prepareToPlay {
    NSAssert(_url, @"media url is invalid");
    
    if (_isPrepareToPlay) {
        return;
    }
    
    AVURLAsset *asset;
    if ([_url isFileURL]) {
        asset = [AVURLAsset URLAssetWithURL:_url options:nil];
    } else {
        asset = [AVURLAsset URLAssetWithURL:_url options:_headers == nil ? nil : @{@"AVURLAssetHTTPHeaderFieldsKey":_headers}];
    }
    
    NSArray *requestedKeys = @[@"playable"];
    
    _urlAsset = asset;
    __weak typeof(self) wself = self;
    [asset loadValuesAsynchronouslyForKeys:requestedKeys
                         completionHandler:^{
                             __strong typeof(wself) self = wself;
                             dispatch_async( dispatch_get_main_queue(), ^{
                                 if (!self.isShutdown) {
                                     [self didPrepareToPlayAsset:asset withKeys:requestedKeys];
                                     [self setPlaybackVolume:_playbackVolume];
                                 }
                             });
                         }];
}

- (void)play {
    if (_isPrepareToPlay && _player.rate == 0.0) {
        [_player play];
        self.state = ARAVVideoPlayerStatePlaying;
    }
}

- (void)pause {
    if (_state == ARAVVideoPlayerStatePlaying && _player.rate != 0.0) {
        [_player pause];
        self.state = ARAVVideoPlayerStatePaused;
    }
}

- (void)stop {
    [self shutDown];
    self.state = ARAVVideoPlayerStateStoped;
}

- (void)shutDown {
    
    if (self.isShutdown) {
        return;
    }
    
    self.isShutdown = YES;
    
    [_urlAsset cancelLoading];
    _urlAsset = nil;
    
    if (!_isPrepareToPlay) {
        return;
    }
    
    [self removeObserver];
    [self clearUp];
    
    [_playerItem cancelPendingSeeks];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:nil
                                                  object:_playerItem];
    
    if (_playTimerObserve) {
        [_player removeTimeObserver:_playTimerObserve];
    }
    
    [_player setRate:0.0];
    [_player replaceCurrentItemWithPlayerItem:nil];
    
    [_view setPlayer:nil];
}

- (void)seekToTime:(NSTimeInterval)time completion:(void (^)(BOOL))completion {
    if (!_player || _playerItem.status != AVPlayerItemStatusReadyToPlay) {
        return;
    }
    
    _seekingTime = time;
    _isSeeking = YES;
    
    [_player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        _isSeeking = NO;
        [self play];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(finished);
            });
        }
    }];
}

#pragma mark - ARMediaPlayerService getter

- (BOOL)isSeeking {
    return _isSeeking;
}

- (BOOL)isPrepareToPlay {
    return _isPrepareToPlay;
}

- (NSTimeInterval)currentPlaybackTime {
    if (!_player) {
        return  0.0;
    }
    
    if (_isSeeking) {
        return _seekingTime;
    }
    
    return CMTimeGetSeconds(_playerItem.currentTime);
}

- (NSTimeInterval)duration {
    return CMTimeGetSeconds(_playerItem.duration);
}

- (NSTimeInterval)playableDuration {
    if (_playerItem) {
        NSArray *loadedTimeRanges = [_playerItem loadedTimeRanges];
        CMTimeRange timeRange     = [loadedTimeRanges.firstObject CMTimeRangeValue];
        float startSeconds        = CMTimeGetSeconds(timeRange.start);
        float durationSeconds     = CMTimeGetSeconds(timeRange.duration);
        NSTimeInterval result     = startSeconds + durationSeconds;
        return result;
    }
    
    return 0.0;
}

#pragma mark - playbackVolume

- (void)setPlaybackVolume:(float)playbackVolume {
    playbackVolume = MIN(MAX(playbackVolume, 0.0), 1.0);
    _playbackVolume = playbackVolume;
    if (_player != nil && _player.volume != playbackVolume) {
        _player.volume = playbackVolume;
    }
    BOOL muted = fabs(playbackVolume) < 1e-6;
    if (_player != nil && _player.muted != muted) {
        _player.muted = muted;
    }
}

- (float)playbackVolume {
    return _playbackVolume;
}

#pragma mark - playbackRate

- (void)setPlaybackRate:(float)playbackRate {
    playbackRate = MIN(MAX(playbackRate, 0.0), 2.0);
    _playbackRate = playbackRate;
    if (_player != nil && !isFloatZero(_player.rate)) {
        _player.rate = _playbackRate;
    }
}

- (float)playbackRate {
    return _playbackRate;
}

#pragma mark - error

- (void)onError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(ARAVVideoPlayerController:reciveError:)]) {
            [self.delegate ARAVVideoPlayerController:self reciveError:error];
        }
    });
}

#pragma mark - thumbnailImage

- (UIImage *)thumbnailImageAtCurrentTime {
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:_urlAsset];
    CMTime expectedTime = _playerItem.currentTime;
    CGImageRef cgImage = NULL;
    
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    cgImage = [imageGenerator copyCGImageAtTime:expectedTime actualTime:NULL error:NULL];
    
    if (!cgImage) {
        imageGenerator.requestedTimeToleranceBefore = kCMTimePositiveInfinity;
        imageGenerator.requestedTimeToleranceAfter = kCMTimePositiveInfinity;
        cgImage = [imageGenerator copyCGImageAtTime:expectedTime actualTime:NULL error:NULL];
    }
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    return image;
}

@end
