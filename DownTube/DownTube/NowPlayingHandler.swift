//
//  NowPlayingHandler.swift
//  DownTube
//
//  Created by Adam on 8/12/17.
//  Copyright © 2017 Adam. All rights reserved.
//

import Foundation
import MediaPlayer

class NowPlayingHandler {
    var player: AVPlayer
    
    init(player: AVPlayer) {
        self.player = player
        
        //Allows control center title to be set
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        MPRemoteCommandCenter.shared().playCommand.addTarget() { _ in
            //Play
            self.player.play()
            self.setNewNowPlayingTime(CMTimeGetSeconds(player.currentTime()))
            return .success
        }
        MPRemoteCommandCenter.shared().pauseCommand.addTarget() { _ in
            //Pause
            self.player.pause()
            self.setNewNowPlayingTime(CMTimeGetSeconds(player.currentTime()))
            return .success
        }
        MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget() { _ in
            //Skip backwards 15 seconds
            let currentSeconds = CMTimeGetSeconds(self.player.currentItem!.currentTime())
            self.player.seek(to: CMTime(seconds: max(currentSeconds - 15, 0), preferredTimescale: 1))
            let newSeconds = max(currentSeconds - 15, 0)
            self.setNewNowPlayingTime(newSeconds)
            return .success
        }
        MPRemoteCommandCenter.shared().skipForwardCommand.addTarget() { _ in
            //Skip forward 15 seconds
            let currentSeconds = CMTimeGetSeconds(self.player.currentItem!.currentTime())
            player.seek(to: CMTime(seconds: currentSeconds + 15, preferredTimescale: 1))
            let newSeconds = currentSeconds + 15
            self.setNewNowPlayingTime(newSeconds)
            return .success
        }
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.addTarget() { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 1))
            self.setNewNowPlayingTime(event.positionTime)
            return .success
        }
    }
    
    /// Sets the time and if the current item is playing.
    ///
    /// - Parameters:
    ///   - time: current timestamp
    ///   - currentlyPlaying: if true, media item is playing. false otherwise
    fileprivate func setNewNowPlayingTime(_ time: Double) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: time)
        let isPlaying = self.player.timeControlStatus == .playing
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1 : 0
    }
    
    /// Observes the time for the AVPlayer. Updates the timestamp in the media center and saves the timestamp to core data
    ///
    /// - Parameter progressCallback: callback whenever progress should be saved
    func addTimeObserverToPlayer(_ progressCallback: @escaping (WatchState) -> Void) {
        self.player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 10, preferredTimescale: 1), queue: DispatchQueue.main) { time in
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
    
    deinit {
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
}
