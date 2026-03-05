import SwiftUI

struct MixerView: View {
    var audioEngine: AudioEngineService

    var body: some View {
        ContentUnavailableView(
            "Mixer Coming Soon",
            systemImage: "slider.vertical.3",
            description: Text("Granular audio processing will appear here.")
        )
    }
}
