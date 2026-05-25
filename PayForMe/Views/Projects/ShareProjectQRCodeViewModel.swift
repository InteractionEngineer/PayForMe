//
//  ShareProjectQRCodeViewModel.swift
//  PayForMe
//
//  Created by Maximilian Fischer on 30.04.26.
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

final class ShareProjectQRCodeViewModel: ObservableObject {

    @Published var qrCodeImage: UIImage?
    @Published var dataString: String = ""

    private let context = CIContext()
    private let project: Project

    init(project: Project) {
        self.project = project
        generate()
    }

    private func generate() {
        let server = project.url.relativeString
            .replacingOccurrences(of: "https://", with: "")
        self.dataString = "cospend://\(server)/\(project.projectId)/\(project.password)"
        self.qrCodeImage = generateQRCode(from: dataString)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        guard let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return UIImage(systemName: "xmark.circle")
        }

        return UIImage(cgImage: cgImage)
    }
}
