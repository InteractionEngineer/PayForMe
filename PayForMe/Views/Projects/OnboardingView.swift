//
//  AddProjectView.swift
//  PayForMe
//
//  Created by Camille Mainz on 14.02.20.
//

import SwiftUI

struct OnboardingView: View {
    @State private var moreInfo = false

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Text("Welcome to PayForMe!").font(.largeTitle)
                Text("To get started sharing expenses with friends, you must add a project from Cospend or iHateMoney. \n\n Cospend projects can be added by QR Code or by manually filling out the information, for iHateMoney you need to fill out the information manually.")
                HStack(spacing: 50) {
                    NavigationLink(destination: ProjectQRPermissionCheckerView()) {
                        Image(systemName: "qrcode")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    NavigationLink(
                        destination: AddProjectManualView(),
                        label: {
                            Image(systemName: "square.and.pencil")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    )
                }.padding(.horizontal, 30)
                if moreInfo {
                    Button(action: {
                        withAnimation {
                            self.moreInfo.toggle()
                        }
                    }, label: {
                        Image(systemName: "chevron.compact.up")
                            .resizable().aspectRatio(contentMode: .fit).frame(width: 30)
                    })
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Cospend is a NextCloud app")
                            Button("nextcloud.com") {
                                if let url = URL(string: "https://nextcloud.com/") {
                                    if UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("To use iHateMoney, host an own instance or register at").multilineTextAlignment(.trailing)
                            Button("iHateMoney.org") {
                                if let url = URL(string: "https://ihatemoney.org/") {
                                    if UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Button(action: {
                        withAnimation {
                            self.moreInfo.toggle()
                        }
                    }, label: {
                        Image(systemName: "questionmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 40)
                    })
                }
                Spacer()
            }.padding(20)
        }
    }
}

struct OnboardingViewView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView().environment(\.locale, .init(identifier: "de"))
    }
}
