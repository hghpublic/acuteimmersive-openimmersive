//
//  SourcesList.swift
//  OpenImmersiveApp
//
//  Created by Anthony Maës (Acute Immersive) on 9/20/24.
//

import SwiftUI
import OpenImmersive

/// A list of available video item sources.
struct SourcesList: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(OpenImmersiveAppState.self) private var appState
    
    /// The visibility of a panel with advanced format options
    @State private var areOptionsShowing: Bool = false
    
    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 10) {
            let selectedItem = {
                let item = appState.selectedItem ?? VideoItem.sampleHLSStream
                return appState.applyFormatOptions(to: item)
            }()
            
            PlayButton() {
                playVideo(selectedItem)
            }
            
            let videoTitle = selectedItem.metadata[.commonIdentifierTitle] ?? "<NONE>"
            let fieldOfView = appState.projection == .equirectangular ? " \(appState.fieldOfView)°" : ""
            let framePacking = appState.projection == .appleImmersive || appState.framePacking == .none ? "" : "(\(appState.framePacking.rawValue))"
            
            Text("Selected video: **\(videoTitle)**")
            Text("Format: **\(appState.projection.rawValue)\(fieldOfView)** \(framePacking)")
            
            Divider()
                .padding(.vertical)
            
            HStack {
                GalleryVideoPicker(spatialVideosOnly: false) { item in
                    appState.applyFormatOptions(from: item)
                    appState.selectedItem = item
                }
                
                FilePicker() { item in
                    appState.applyFormatOptions(from: item)
                    appState.selectedItem = item
                }
                
                StreamUrlInput() { item in
                    appState.applyFormatOptions(from: item)
                    appState.selectedItem = item
                }
                
                Toggle(isOn: $areOptionsShowing.animation(.interactiveSpring)) {
                    Image(systemName: "gearshape.fill")
                }
                .toggleStyle(.button)
                .buttonBorderShape(.circle)
            }
            .popover(isPresented: $areOptionsShowing) {
                VStack {
                    Text("Projection")
                        .font(.headline.lowercaseSmallCaps())
                    ProjectionPicker(projection: $appState.projection, options: [.equirectangular, .rectilinear, .appleImmersive])
                    
                    let projectionDescription = switch appState.projection {
                    case .equirectangular: "The video will be projected onto a spherical screen.\nUse this setting for VR180 and VR360."
                    case .rectilinear: "The video will be played on a rectangular plane.\nUse this setting for Spatial Video and other rectilinear videos."
                    case .appleImmersive: "Use this setting for Apple Immersive Video only."
                    }
                    Text(projectionDescription)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                    
                    if appState.projection == .equirectangular {
                        Divider()
                            .padding(.vertical, 10)
                        
                        Text("Horizontal Field of View")
                            .font(.headline.lowercaseSmallCaps())
                        FormatPicker(fieldOfView: $appState.fieldOfView, options: [65, 144, 180, 360])
                                .padding(.top, 5)
                        
                        Toggle(isOn: $appState.forceFov.animation(.easeInOut)) {
                            Text("Override encoded values")
                        }
                        .fixedSize()
                    }
                    
                    if appState.projection != .appleImmersive {
                        Divider()
                            .padding(.vertical, 10)
                        
                        Text("Frame Packing")
                            .font(.headline.lowercaseSmallCaps())
                        FramePackingPicker(framePacking: $appState.framePacking, options: [.none, .sideBySide, .overUnder])
                        let packingDescription = switch appState.framePacking {
                        case .none: "Use this setting for Spatial, MV-HEVC, APMP and Mono videos."
                        case .sideBySide: "Use this setting for side-by-side videos (e.g. legacy 3D VR180)."
                        case .overUnder: "Use this setting for over-under videos (e.g. legacy 3D VR360)."
                        }
                        Text(packingDescription)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                        
                        if appState.framePacking != .none {
                            let stepperWidth: CGFloat = 350
                            Stepper(value: $appState.baseline, in: 0...10000, step: 5) {
                                let baseline = Text("Baseline:")
                                    .font(.headline.lowercaseSmallCaps())
                                Text("\(baseline) \(appState.baseline, specifier: "%.0f")mm")
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: stepperWidth)
                            
                            Stepper(value: $appState.disparity, in: -1...1, step: 0.05) {
                                let disparity = Text("Horizontal Disparity:")
                                    .font(.headline.lowercaseSmallCaps())
                                Text("\(disparity) \(appState.disparity, specifier: "%.2f")")
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: stepperWidth)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    Text("Widgets")
                        .font(.headline.lowercaseSmallCaps())
                    Toggle(isOn: $appState.showTimecodeReadout.animation(.easeInOut)) {
                        Text("Show timecode readout")
                    }
                    .fixedSize()
                }
                .padding(.vertical, 20)
                .padding()
            }
            
            Text("\(Image(systemName: "info.circle")) This player supports Spatial Video, AIV Immersive Videos, MV-HEVC, side-by-side and over-under.\nUse the gear button to select the correct format and projection.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    /// Open the immersive player and play the video for the provided item.
    /// - Parameters:
    ///   - item: the object describing the video.
    ///
    /// Opening the immersive player will close the current window containing the SourcesList view.
    func playVideo(_ item: VideoItem) {
        Task {
            let result = await openImmersiveSpace(value: item)
            if result == .opened {
                dismissWindow()
            }
        }
    }
    
}

/// A projection type picker
struct ProjectionPicker: View {
    @Binding public var projection: ProjectionOption
    public let options: [ProjectionOption]
    
    var body: some View {
        Picker(selection: $projection.animation()) {
            ForEach(options, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        } label: {
            Text("Projection:")
        }
        .pickerStyle(.palette)
        .controlSize(.large)
        .frame(maxWidth: CGFloat(300 * options.count))
        .fixedSize()
    }
}

/// A field of view picker
struct FormatPicker: View {
    @Binding public var fieldOfView: Int
    public let options: [Int]
    
    var body: some View {
        Picker(selection: $fieldOfView) {
            ForEach(options, id: \.self) { option in
                Text("\(option)°").tag(option)
            }
        } label: {
            Text("Open as...")
        }
        .pickerStyle(.palette)
        .controlSize(.large)
        .frame(maxWidth: CGFloat(64 * options.count))
    }
}

/// A frame packing type picker
struct FramePackingPicker: View {
    @Binding public var framePacking: FramePackingOption
    public let options: [FramePackingOption]
    
    var body: some View {
        Picker(selection: $framePacking.animation()) {
            ForEach(options, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        } label: {
            Text("Frame Packing:")
        }
        .pickerStyle(.palette)
        .controlSize(.large)
        .frame(maxWidth: CGFloat(300 * options.count))
        .fixedSize()
    }
}

extension VideoItem {
    /// An example VideoItem to illustrate how to load HLS stream videos from the web.
    public static let sampleHLSStream = VideoItem(
        metadata: [
            .commonIdentifierTitle: "Example Stream",
            .commonIdentifierDescription: "Local basketball player takes a shot at sunset",
        ],
        url: URL(string: "https://stream.spatialgen.com/stream/JNVc-sA-_QxdOQNnzlZTc/index.m3u8")!,
        projection: .equirectangular(fieldOfView: 180.0),
        framePacking: .none
    )
}

#Preview(windowStyle: .automatic) {
    SourcesList()
        .environment(OpenImmersiveAppState())
}
