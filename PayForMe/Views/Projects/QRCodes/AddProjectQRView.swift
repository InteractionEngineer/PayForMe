//
//  AddProjectQRView.swift
//  PayForMe
//
//  Created by Max Tharr on 02.10.20.
//

import AVFoundation
import CarBode
import SlickLoadingSpinner
import SwiftUI

struct AddProjectQRView: View {
    @StateObject var viewmodel = AddProjectQRViewModel()

    @Environment(\.presentationMode) var presentationMode

    @State var scanningCode: [AVMetadataObject.ObjectType] = [.qr]

    var body: some View {
        VStack {
            if viewmodel.askForPassword {
                passwordView
            } else {
                qrCodeScanner
            }
        }
        .onReceive(viewmodel.$isProject, perform: { status in
            switch status {
            case .success:
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(1))) {
                    withAnimation {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            case .failure:
                scanningCode = [.qr]
            default:
                break
            }
        })
    }

    var passwordView: some View {
        AddPasswordView(password: $viewmodel.passwordText, connectionState: viewmodel.isProject, name: viewmodel.name, urlString: viewmodel.urlString)
    }

    var connectIndicator: some View {
        SlickLoadingSpinner(connectionState: viewmodel.isProject)
            .frame(width: 100, height: 100, alignment: .center)
    }

    var qrCodeScanner: some View {
        CBScanner(
            supportBarcode: $scanningCode, // Set type of barcode you want to scan
            scanInterval: .constant(5.0) // Event will trigger every 5 seconds,
        ) { code in
            // If we find a QR code which is an url with at least 3 components, it can be a Cospend link
            guard let url = URL(string: code.value),
                  url.pathComponents.count >= 3 else { return }

            scanningCode = []
            self.viewmodel.scannedCode = url
        }
        .overlay(footer, alignment: .bottom)
        .edgesIgnoringSafeArea(.all)
    }

    var footer: some View {
        Group {
            if viewmodel.isProject == .notStarted {
                Text("Scan the QR code to proceed")
                    .foregroundColor(.white)
                    .font(.headline)
            } else {
                SlickLoadingSpinner(connectionState: viewmodel.isProject)
                    .frame(width: 80, height: 80)
            }
        }
        .padding(20)
        .frame(width: UIScreen.main.bounds.width)
        .background(Color.gray.opacity(0.5).blur(radius: 3))
    }
}

struct AddProjectQRView_Previews: PreviewProvider {
    static var previews: some View {
        AddProjectQRView()
    }
}
