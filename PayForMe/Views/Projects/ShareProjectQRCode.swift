//
//  ShareProjectQRCode.swift
//  PayForMe
//
//  Created by Max Tharr on 03.10.20.
//

import SwiftUI

struct ShareProjectQRCode: View {

    @StateObject private var viewModel: ShareProjectQRCodeViewModel

    init(project: Project) {
        _viewModel = StateObject(wrappedValue: ShareProjectQRCodeViewModel(project: project))
    }

    var body: some View {
        VStack {
            Text(viewModel.dataString).font(.caption)

            if let image = viewModel.qrCodeImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            }
        }
        .padding()
    }
}

struct ShareProjectQRCode_Previews: PreviewProvider {
    static var previews: some View {
        ShareProjectQRCode(project: previewProject)
    }
}
