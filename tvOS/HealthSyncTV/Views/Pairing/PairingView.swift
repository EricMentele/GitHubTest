import SwiftUI
import DeviceDiscoveryUI
import Network
import HealthSyncShared

struct PairingView: View {
    @Bindable var connection: PhoneConnection
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 120, weight: .light))
                .foregroundStyle(.tint)
            Text("Pair your iPhone").font(.system(size: 60, weight: .bold))
            Text("Open Health Sync on your iPhone and keep it on the same Wi-Fi network. Health data never leaves your home.")
                .multilineTextAlignment(.center)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 900)
            Button("Find iPhone") { showingPicker = true }
                .font(.title2.bold())
            if let error = connection.lastError {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
        }
        .padding(120)
        .sheet(isPresented: $showingPicker) {
            DevicePickerHost { endpoint in
                showingPicker = false
                connection.pair(with: endpoint)
            } onCancel: {
                showingPicker = false
            }
        }
    }
}

private struct DevicePickerHost: UIViewControllerRepresentable {
    let onPick: (NWEndpoint) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> DDDevicePickerViewController {
        let descriptor = DDDeviceBrowserDescriptor.applicationService(name: HealthSyncService.identifier)
        let picker = DDDevicePickerViewController(browseDescriptor: descriptor, parameters: .applicationService)
        picker.deviceSelectionHandler = { endpoint in
            onPick(endpoint)
        }
        picker.cancellationHandler = {
            onCancel()
        }
        return picker
    }

    func updateUIViewController(_ controller: DDDevicePickerViewController, context: Context) {}
}
