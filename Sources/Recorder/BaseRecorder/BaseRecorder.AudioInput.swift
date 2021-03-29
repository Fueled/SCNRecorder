//
//  BaseRecorder.AudioInput.swift
//  SCNRecorder
//
//  Created by Vladislav Grigoryev on 31.05.2020.
//  Copyright © 2020 GORA Studio. https://gora.studio
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import AVFoundation
import ARKit

extension BaseRecorder {

  final class AudioInput: NSObject, MediaSession.Input.SampleBufferAudio {

    let queue: DispatchQueue

    let captureOutput = AVCaptureAudioDataOutput()

    var audioDelay: TimeInterval = 0.0

    @UnfairAtomic var started: Bool = false

    var output: ((CMSampleBuffer) -> Void)?

    init(queue: DispatchQueue) {
      self.queue = queue
      super.init()
      self.captureOutput.setSampleBufferDelegate(self, queue: queue)
    }

    func start() { started = true }

    func stop() { started = false }

    func recommendedAudioSettingsForAssetWriter(
      writingTo outputFileType: AVFileType
    ) -> [String : Any] {
      captureOutput.recommendedAudioSettingsForAssetWriter(
        writingTo: outputFileType
      ) as? [String: Any] ?? AudioSettings().outputSettings
    }
  }
}

extension BaseRecorder.AudioInput: AVCaptureAudioDataOutputSampleBufferDelegate {

  @objc func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard started else { return }
    self.output?(sampleBuffer.delayed(byInterval: self.audioDelay) ?? sampleBuffer)
  }
}

extension BaseRecorder.AudioInput: ARSessionObserver {

  func session(
    _ session: ARSession,
    didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer
  ) {
    guard started else { return }
    queue.async { [output] in output?(audioSampleBuffer.delayed(byInterval: self.audioDelay) ?? audioSampleBuffer) }
  }
}
