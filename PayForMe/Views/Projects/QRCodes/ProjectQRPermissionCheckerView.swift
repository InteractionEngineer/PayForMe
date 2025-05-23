//
//  ProjectQRPermissionCheckerView.swift
//  PayForMe
//
//  Created by Max Tharr on 03.10.20.
//

import AVFoundation
import SwiftUI

struct ProjectQRPermissionCheckerView: View {
    @State
    var cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        switch cameraAuthStatus {
        case .authorized:
            return AddProjectQRView().eraseToAnyView()
        case .denied:
            return permissionDeniedView.eraseToAnyView()
        default:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
            return Text("Please allow us to use the camera in order to scan the Cospend QR code").padding(20).eraseToAnyView()
        }
    }

    var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Text("If you want to scan your project as a QR code, you need to allow this app to use your camera. Otherwise please navigate back and fill out the information manually.")
            Button("Go to settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: { _ in
                            cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
                        })
                    }
                }
            }
        }.padding(20)
    }
}

struct ProjectQRPermissionCheckerView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectQRPermissionCheckerView()
    }
}
