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
		enum Mode {
			case `default`
			case echoCancellation
		}

		var audioDelay: TimeInterval = 0.0
		var output: ((CMSampleBuffer) -> Void)? {
			didSet {
				self.internalSampleBufferAudio.output = self.output.map { output in
					{ [weak self] sampleBuffer in
						sampleBuffer.delayed(byInterval: self?.audioDelay ?? 0.0) ?? sampleBuffer
					}
				}
			}
		}

		private let internalSampleBufferAudio: MediaSession.Input.SampleBufferAudio

		init(queue: DispatchQueue, mode: Mode) {
			switch mode {
			case .default:
				self.internalSampleBufferAudio = BasicSampleBufferAudio(queue: queue)
			case .echoCancellation:
				self.internalSampleBufferAudio = (try? EchoCancellationSampleBufferAudio(queue: queue)) ?? BasicSampleBufferAudio(queue: queue)
			}
		}

		func start() throws {
			try self.internalSampleBufferAudio.start()
		}

		func stop() throws {
			try self.internalSampleBufferAudio.stop()
		}

		func canAddOutput(to captureSession: AVCaptureSession) -> Bool {
			self.internalSampleBufferAudio.canAddOutput(to: captureSession)
		}

		func addOutput(to captureSession: AVCaptureSession) {
			self.internalSampleBufferAudio.addOutput(to: captureSession)
		}

		func removeOutput(from captureSession: AVCaptureSession) {
			self.internalSampleBufferAudio.removeOutput(from: captureSession)
		}

		func recommendedAudioSettingsForAssetWriter(
			writingTo outputFileType: AVFileType
		) -> [String : Any] {
			self.internalSampleBufferAudio.recommendedAudioSettingsForAssetWriter(writingTo: outputFileType)
		}
  }
}

extension BaseRecorder.AudioInput: ARSessionObserver {
	func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
		let delegate = self.internalSampleBufferAudio as? ARSessionObserver
		delegate?.session?(session, didOutputAudioSampleBuffer: audioSampleBuffer)
	}
}
