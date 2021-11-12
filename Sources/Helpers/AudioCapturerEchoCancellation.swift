//
//  AudioCapturerEchoCancellation.swift
//  SCNRecorder
//
//  Created by Stéphane Copin on 11/12/21.
//

import AudioToolbox
import AVFoundation
import CoreMedia

final class AudioCapturerEchoCancellation {
	enum Error: Swift.Error {
		case noInputs
		case code(OSStatus)
	}

	var queue: DispatchQueue?
	var output: ((CMSampleBuffer) -> Void)?

	var isPlaying: Bool {
		get throws {
			var isPlaying: UInt32 = 0
			var size = UInt32(memoryLayout(of: isPlaying).size)
			try doCall {
				AudioUnitGetProperty(
					self.inputAudioUnit,
					kAudioOutputUnitProperty_IsRunning,
					kAudioUnitScope_Global,
					Self.inputBus,
					&isPlaying,
					&size
				)
			}
			return isPlaying != 0
		}
	}

	private let inputAudioUnit: AudioComponentInstance
	private var inputBuffer: AudioBufferList?
	private var inputNumberOfFrames: UInt32 = 0

	private static let sampleRate = 44100
	private static let bytesPerSample: UInt32 = 2
	private static let audioStreamDescription = AudioStreamBasicDescription(
		mSampleRate: Float64(AudioCapturerEchoCancellation.sampleRate),
		mFormatID: kAudioFormatLinearPCM,
		mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
		mBytesPerPacket: AudioCapturerEchoCancellation.bytesPerSample,
		mFramesPerPacket: 1,
		mBytesPerFrame: AudioCapturerEchoCancellation.bytesPerSample,
		mChannelsPerFrame: 1,
		mBitsPerChannel: 8 * AudioCapturerEchoCancellation.bytesPerSample,
		mReserved: 0
	)
	private static let inputBus: AudioUnitElement = 1
	private static let outputBus: AudioUnitElement = 0

	init(
		queue: DispatchQueue? = nil,
		subType: OSType = kAudioUnitSubType_VoiceProcessingIO
	) throws {
		self.queue = queue

		//		try AVAudioSession.sharedInstance().setCategory(.playAndRecord)
		////		try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(10.0)
		//		try AVAudioSession.sharedInstance().setActive(false)

		var audioComponentDescription = AudioComponentDescription(
			componentType: kAudioUnitType_Output,
			componentSubType: subType,
			componentManufacturer: kAudioUnitManufacturer_Apple,
			componentFlags: 0,
			componentFlagsMask: 0
		)
		guard let inputComponent = AudioComponentFindNext(nil, &audioComponentDescription) else {
			throw Error.noInputs
		}
		var audioUnit: AudioComponentInstance!
		try doCall {
			AudioComponentInstanceNew(inputComponent, &audioUnit)
		}

		var flag: UInt32 = 1
		try doCall {
			AudioUnitSetProperty(
				audioUnit,
				kAudioOutputUnitProperty_EnableIO,
				kAudioUnitScope_Input,
				Self.inputBus,
				&flag,
				UInt32(memoryLayout(of: flag).size)
			)
		}

		flag = 0
		try doCall {
			AudioUnitSetProperty(
				audioUnit,
				kAudioOutputUnitProperty_EnableIO,
				kAudioUnitScope_Output,
				Self.outputBus,
				&flag,
				UInt32(memoryLayout(of: flag).size)
			)
		}

		var audioStreamDescription = Self.audioStreamDescription
		try doCall {
			AudioUnitSetProperty(
				audioUnit,
				kAudioUnitProperty_StreamFormat,
				kAudioUnitScope_Output,
				Self.inputBus,
				&audioStreamDescription,
				UInt32(memoryLayout(of: audioStreamDescription).size)
			)
		}

		self.inputAudioUnit = audioUnit

		var callback = AURenderCallbackStruct(
			inputProc: { inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, _ in
				let this = Unmanaged<AudioCapturerEchoCancellation>.fromOpaque(inRefCon).takeUnretainedValue()
				do {
					var buffer = try this.renderAudio(
						ioActionFlags: ioActionFlags,
						inTimeStamp: inTimeStamp,
						inBusNumber: inBusNumber,
						inNumberFrames: inNumberFrames
					)
					let sampleBuffer = try this.sampleBuffer(
						from: &buffer,
						samplesCount: Int(inNumberFrames),
						timestamp: inTimeStamp.pointee
					)

					if let queue = this.queue {
						queue.async {
							this.output?(sampleBuffer)
						}
					} else {
						this.output?(sampleBuffer)
					}

					return noErr
				} catch Error.code(let status) {
					return status
				} catch {
					return -1
				}
			},
			inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
		)

		//    var inputCallbackStruct = AURenderCallbackStruct(inputProc: recordingCallback, inputProcRefCon: UnsafeMutablePointer(unsafeAddressOf(self)))
		//		AudioUnitSetProperty(audioUnit, AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback), AudioUnitScope(kAudioUnitScope_Global), 1, &inputCallbackStruct, UInt32(sizeof(AURenderCallbackStruct)))

		//		var inputCallbackStruct: AURenderCallbackStruct! = AURenderCallbackStruct(inputProc: recordingCallback, inputProcRefCon: UnsafeMutablePointer(unsafeAddressOf(self)))
		//		inputCallbackStruct.inputProc = recordingCallback
		//		inputCallbackStruct.inputProcRefCon = UnsafeMutablePointer(unsafeAddressOf(self))
		try doCall {
			AudioUnitSetProperty(
				audioUnit,
				kAudioOutputUnitProperty_SetInputCallback,
				kAudioUnitScope_Global,
				Self.inputBus,
				&callback,
				UInt32(memoryLayout(of: callback).size)
			)
		}

		flag = 0
		try doCall {
			AudioUnitSetProperty(
				audioUnit,
				kAudioUnitProperty_ShouldAllocateBuffer,
				kAudioUnitScope_Output,
				Self.inputBus,
				&flag,
				UInt32(memoryLayout(of: flag).size)
			)
		}

		try doCall {
			AudioUnitInitialize(audioUnit)
		}
	}

	deinit {
		AudioComponentInstanceDispose(self.inputAudioUnit)
	}

	func start() throws {
		try doCall {
			AudioOutputUnitStart(self.inputAudioUnit)
		}
	}

	func stop() throws {
		try doCall {
			AudioOutputUnitStop(self.inputAudioUnit)
		}
	}

	private enum StatusResult<Result> {
		case result(Result)
		case status(OSStatus)
	}

	private func renderAudio(
		ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
		inTimeStamp: UnsafePointer<AudioTimeStamp>,
		inBusNumber: UInt32,
		inNumberFrames: UInt32
	) throws -> AudioBufferList {
		if self.inputNumberOfFrames < inNumberFrames {
			self.inputBuffer?.mBuffers.mData?.deallocate()
			self.inputBuffer = nil
		}
		var inputBuffer = self.inputBuffer ?? {
			var inputBuffer = AudioBufferList()
			inputBuffer.mNumberBuffers = 1
			inputBuffer.mBuffers.mNumberChannels = 1
			inputBuffer.mBuffers.mDataByteSize = inNumberFrames * Self.bytesPerSample
			inputBuffer.mBuffers.mData = .allocate(byteCount: Int(inputBuffer.mBuffers.mDataByteSize), alignment: Int(Self.bytesPerSample))
			self.inputBuffer = inputBuffer
			return inputBuffer
		}()

		try doCall {
			AudioUnitRender(
				self.inputAudioUnit,
				ioActionFlags,
				inTimeStamp,
				inBusNumber,
				inNumberFrames,
				&inputBuffer
			)
		}

		self.inputBuffer = inputBuffer

		return inputBuffer
	}

	private func sampleBuffer(from samples: UnsafePointer<AudioBufferList>, samplesCount: Int, timestamp: AudioTimeStamp) throws -> CMSampleBuffer {
		var format: CMFormatDescription!
		var audioStreamDescription = Self.audioStreamDescription
		try doCall {
			CMAudioFormatDescriptionCreate(
				allocator: kCFAllocatorDefault,
				asbd: &audioStreamDescription,
				layoutSize: 0,
				layout: nil,
				magicCookieSize: 0,
				magicCookie: nil,
				extensions: nil,
				formatDescriptionOut: &format
			)
		}

		var timeInfo = mach_timebase_info_data_t()
		let result = mach_timebase_info(&timeInfo)
		if result != KERN_SUCCESS {
			throw Error.code(result)
		}
		var hostTime = timestamp.mHostTime
		if timeInfo.numer != timeInfo.denom {
			hostTime *= UInt64(timeInfo.numer)
			hostTime /= UInt64(timeInfo.denom)
		}
		let presentationTime = CMTime(value: CMTimeValue(hostTime), timescale: 1_000_000_000)
		var timing = CMSampleTimingInfo(
			duration: CMTime(value: 1, timescale: CMTimeScale(Self.audioStreamDescription.mSampleRate)),
			presentationTimeStamp: presentationTime,
			decodeTimeStamp: .invalid
		)

		var sampleBuffer: CMSampleBuffer!
		try doCall {
			CMSampleBufferCreate(
				allocator: kCFAllocatorDefault,
				dataBuffer: nil,
				dataReady: false,
				makeDataReadyCallback: nil,
				refcon: nil,
				formatDescription: format,
				sampleCount: CMItemCount(samplesCount),
				sampleTimingEntryCount: 1,
				sampleTimingArray: &timing,
				sampleSizeEntryCount: 0,
				sampleSizeArray: nil,
				sampleBufferOut: &sampleBuffer
			)
		}

		try doCall {
			CMSampleBufferSetDataBufferFromAudioBufferList(
				sampleBuffer,
				blockBufferAllocator: kCFAllocatorDefault,
				blockBufferMemoryAllocator: kCFAllocatorDefault,
				flags: 0,
				bufferList: samples
			)
		}
		return sampleBuffer
	}
}

private func memoryLayout<Type>(of _: Type) -> MemoryLayout<Type>.Type {
	MemoryLayout<Type>.self
}

private func doCall(_ function: () -> OSStatus) throws {
	let status = function()
	if status != noErr {
		throw AudioCapturer.Error.code(status)
	}
}
