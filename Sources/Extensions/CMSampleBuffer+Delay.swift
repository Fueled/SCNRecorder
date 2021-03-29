//
//  CMSampleBuffer+Delay.swift
//  SCNRecorder
//
//  Created by Stéphane Copin on 3/29/21.
//  Copyright © 2021 Fueled. All rights reserved.
//

import CoreMedia

extension CMSampleBuffer {
  func delayed(byInterval interval: TimeInterval) -> CMSampleBuffer? {
    self.delayed(
      by: CMTime(
        seconds: Double(interval),
        preferredTimescale: CMSampleBufferGetPresentationTimeStamp(self).timescale
      )
    )
  }

  func delayed(by time: CMTime) -> CMSampleBuffer? {
		if time.value == 0 {
			return self
		}
    var itemCount: CMItemCount = 0
    var status = CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &itemCount)
    if status != kCVReturnSuccess {
      return nil
    }

    var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: .zero, presentationTimeStamp: .zero, decodeTimeStamp: .zero), count: itemCount)
    status = CMSampleBufferGetSampleTimingInfoArray(self, entryCount: itemCount, arrayToFill: &timingInfo, entriesNeededOut: &itemCount);
    if status != kCVReturnSuccess {
      return nil
    }

    for i in 0..<itemCount {
      timingInfo[i].decodeTimeStamp = timingInfo[i].decodeTimeStamp + time;
      timingInfo[i].presentationTimeStamp = timingInfo[i].presentationTimeStamp + time;
    }

    var sampleBuffer: CMSampleBuffer? = nil
    status = CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: self, sampleTimingEntryCount: itemCount, sampleTimingArray: &timingInfo, sampleBufferOut: &sampleBuffer)
    if status != kCVReturnSuccess {
      return nil
    }

    return sampleBuffer
  }
}

