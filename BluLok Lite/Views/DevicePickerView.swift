//
//  DevicePickerView.swift
//  BluLok Demo
//
//  Matches Android: header "Select your BluLok", search, Scan/Stop, empty state card, device list, connecting overlay.
//

import SwiftUI

struct DevicePickerView: View {
    @ObservedObject var ble: BLEManager
    @State private var query: String = ""

    private var filtered: [BLEDevice] {
        if query.isEmpty { return ble.devices }
        return ble.devices.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.addressLike.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            if let name = ble.lastConnectedName, !ble.isConnected {
                reconnectButton(to: name)
            }
            if !ble.devices.isEmpty || !query.isEmpty {
                searchField
            }
            scanButton
            if filtered.isEmpty {
                emptyStateCard
                Spacer(minLength: 0)
            } else {
                listHeader
                deviceList
            }
            if let err = ble.errorText {
                errorBanner(err)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .navigationBarHidden(true)
        .overlay { connectingOverlay }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Select your BluLok")
                .font(.title2.weight(.semibold))
            Text("Turn on your lock, then tap Scan or Reconnect. Tap a device to connect.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reconnectButton(to name: String) -> some View {
        Button {
            ble.reconnect()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                Text("Reconnect to \(name)")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(ble.isConnecting)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search by name or address", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private let scanButtonHeight: CGFloat = 30

    @ViewBuilder
    private var scanButton: some View {
        if ble.isScanning {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanning…")
                        .font(.subheadline.weight(.semibold))
                    Text(ble.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical)
                Spacer()
                Button("Stop") { ble.stopScan() }
                    .buttonStyle(.bordered)
            }
            .frame(minHeight: scanButtonHeight)
            .padding(.horizontal, 14)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            Button {
                ble.startScan()
            } label: {
                Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
                    .frame(height: scanButtonHeight)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 56, height: 56)
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Text(ble.isScanning ? "Searching for devices…" : "No devices yet")
                .font(.headline)
            Text("1. Turn on your BluLok lock\n2. Move your phone closer\n3. Tap Scan to search")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !ble.isScanning {
                Button {
                    ble.startScan()
                } label: {
                    Label("Scan for devices", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                        .frame(height: scanButtonHeight)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }

    private var listHeader: some View {
        HStack {
            Text("Nearby Locks")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(filtered.count) found • Tap to connect")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filtered) { d in
                    deviceCard(d)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deviceCard(_ d: BLEDevice) -> some View {
        let (label, color) = signalLabelAndColor(d.rssi)
        return Button {
            ble.connect(d)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.open")
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(d.addressLike)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                        Text("\(label) • \(d.rssi) dBm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(Color.accentColor)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground).opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var connectingOverlay: some View {
        if ble.isConnecting {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(spacing: 4) {
                        Text("Connecting")
                            .font(.headline)
                        Text(ble.statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    ProgressView()
                        .progressViewStyle(.circular)
                    Button("Cancel") {
                        ble.stopScan()
                        ble.disconnect()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(28)
                .frame(maxWidth: 280)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(radius: 25)
            }
            .animation(.easeInOut(duration: 0.25), value: ble.isConnecting)
        }
    }
}

private func signalLabelAndColor(_ rssi: Int) -> (String, Color) {
    let v = abs(rssi)
    if v <= 55 { return ("Excellent", Color(red: 0.18, green: 0.49, blue: 0.2)) }
    if v <= 70 { return ("Good", Color(red: 0.33, green: 0.55, blue: 0.18)) }
    if v <= 85 { return ("Fair", Color(red: 0.98, green: 0.66, blue: 0.15)) }
    return ("Weak", Color(red: 0.9, green: 0.32, blue: 0))
}
