//
//  ShareProjectQRCode.swift
//  PayForMe
//
//  Created by Max Tharr on 03.10.20.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ShareProjectQRCode: View {
    let project: Project

    private static let context = CIContext()

    private var dataString: String {
        let server = project.url.relativeString
            .replacingOccurrences(of: "https://", with: "")
        return "cospend://\(server)/\(project.token)/\(project.password)"
    }

    private var qrCodeImage: UIImage {
        generateQRCode(from: dataString)
    }

    var body: some View {
        VStack {
            Text(dataString).font(.caption)

            Image(uiImage: qrCodeImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
        .padding()
    }

    private func generateQRCode(from string: String) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        guard let outputImage = filter.outputImage else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        guard let cgImage = Self.context.createCGImage(outputImage, from: outputImage.extent) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        return UIImage(cgImage: cgImage)
    }
}

struct ShareProjectQRCode_Previews: PreviewProvider {
    static var previews: some View {
        ShareProjectQRCode(project: previewProject)
    }
}
