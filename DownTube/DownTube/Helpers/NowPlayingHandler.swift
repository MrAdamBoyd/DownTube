//
//  NowPlayingHandler.swift
//  DownTube
//
//  Created by Adam on 8/12/17.
//  Copyright © 2017 Adam. All rights reserved.
//

import Foundation
import MediaPlayer

final class NowPlayingHandler {
    var player: AVPlayer
    var playCommandTarget: Any!
    var pauseCommandTarget: Any!
    var skipBackwardTarget: Any!
    var skipForwardTarget: Any!
    var playbackPositionTarget: Any!
    
    init(player: AVPlayer) {
        self.player = player
        
        //Allows control center title to be set
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        self.playCommandTarget = MPRemoteCommandCenter.shared().playCommand.addTarget() { [weak self] _ in
            guard let strongSelf = self else { return .commandFailed }
            //Play
            strongSelf.player.play()
            strongSelf.setNewNowPlayingTime(CMTimeGetSeconds(strongSelf.player.currentTime()))
            return .success
        }
        self.pauseCommandTarget = MPRemoteCommandCenter.shared().pauseCommand.addTarget() { [weak self] _ in
            guard let strongSelf = self else { return .commandFailed }
            //Pause
            strongSelf.player.pause()
            strongSelf.setNewNowPlayingTime(CMTimeGetSeconds(strongSelf.player.currentTime()))
            return .success
        }
        self.skipBackwardTarget = MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget() { [weak self] _ in
            guard let strongSelf = self else { return .commandFailed }
            //Skip backwards 15 seconds
            let currentSeconds = CMTimeGetSeconds(strongSelf.player.currentItem!.currentTime())
            let newSeconds = max(currentSeconds - 15, 0)
            strongSelf.player.seek(to: CMTime(seconds: newSeconds, preferredTimescale: 1))
            strongSelf.setNewNowPlayingTime(newSeconds)
            return .success
        }
        self.skipForwardTarget = MPRemoteCommandCenter.shared().skipForwardCommand.addTarget() { [weak self] _ in
            guard let strongSelf = self else { return .commandFailed }
            //Skip forward 15 seconds
            let currentSeconds = CMTimeGetSeconds(strongSelf.player.currentItem!.currentTime())
            let newSeconds = currentSeconds + 15
            player.seek(to: CMTime(seconds: newSeconds, preferredTimescale: 1))
            strongSelf.setNewNowPlayingTime(newSeconds)
            return .success
        }
        self.playbackPositionTarget = MPRemoteCommandCenter.shared().changePlaybackPositionCommand.addTarget() { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            guard let strongSelf = self else { return .commandFailed }
            strongSelf.player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 1))
            strongSelf.setNewNowPlayingTime(event.positionTime)
            return .success
        }
        
        //For background playback automatically continuing
        NotificationCenter.default.addObserver(self, selector: #selector(self.disableVideoTracksInPlayerItem), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.enableVideoTracksInPlayerItem), name: UIApplication.didBecomeActiveNotification, object: nil)
        
    }
    
    /// Sets the time and if the current item is playing.
    ///
    /// - Parameters:
    ///   - time: current timestamp
    ///   - currentlyPlaying: if true, media item is playing. false otherwise
    private func setNewNowPlayingTime(_ time: Double) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: time)
        let isPlaying = self.player.timeControlStatus == .playing
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1 : 0
    }
    
    /// Observes the time for the AVPlayer. Updates the timestamp in the media center and saves the timestamp to core data
    ///
    /// - Parameter progressCallback: callback whenever progress should be saved
    func addTimeObserverToPlayer(_ progressCallback: @escaping (WatchState) -> Void) {
        self.player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: DispatchQueue.main) { time in
            //Set the time on the media center every second
            
            let currentPosition = Int(CMTimeGetSeconds(time))
            let totalVideoTime = CMTimeGetSeconds(self.player.currentItem!.duration)
            
            //Every 10 seconds, update the progress of the video in core data
            let progressPercent = Double(currentPosition) / totalVideoTime
            
            print("User progress on video in seconds: \(currentPosition)")
            
            let newWatchProgress: WatchState
            
            //If user is 95% done with the video, mark it as done
            if progressPercent > 0.95 {
                newWatchProgress = .watched
            } else {
                newWatchProgress = .partiallyWatched(NSNumber(value: currentPosition as Int))
            }
            
            progressCallback(newWatchProgress)
        }
    }
    
    // MARK: - Background playback when app opens/closes
    
    /// Disables all video tracks. This is necessary if we want to automatically continue playback in background
    @objc
    private func disableVideoTracksInPlayerItem() {
        self.setAllVideoTracksToEnabled(false, forPlayerItem: self.player.currentItem)
    }
    
    /// Enables all video tracks. This is necessary because video tracks are disabled when app enters background due to background play
    @objc
    private func enableVideoTracksInPlayerItem() {
        self.setAllVideoTracksToEnabled(true, forPlayerItem: self.player.currentItem)
    }
    
    /// Goes through all the tracks in the player item, and if they are videos, sets whether or not they are enabled
    ///
    /// - Parameter isEnabled: if the tracks should be enabled
    private func setAllVideoTracksToEnabled(_ shouldBeEnabled: Bool, forPlayerItem playerItem: AVPlayerItem?) {
        guard let tracks = playerItem?.tracks else { return }
        
        for track in tracks {
			if track.assetTrack!.hasMediaCharacteristic(.visual) {
                track.isEnabled = shouldBeEnabled
            }
        }
    }
    
    // MARK: - Deinit
    
    deinit {
        //For background playback automatically continuing
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        
        MPRemoteCommandCenter.shared().playCommand.removeTarget(self.playCommandTarget)
        MPRemoteCommandCenter.shared().pauseCommand.removeTarget(self.pauseCommandTarget)
        MPRemoteCommandCenter.shared().skipBackwardCommand.removeTarget(self.skipBackwardTarget)
        MPRemoteCommandCenter.shared().skipForwardCommand.removeTarget(self.skipForwardTarget)
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.removeTarget(self.playbackPositionTarget)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
}
