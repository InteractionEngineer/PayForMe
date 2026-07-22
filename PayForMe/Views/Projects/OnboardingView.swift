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
                Text("To get started sharing expenses with friends, you must add a project from Cospend or iHateMoney. To do this, scan the QR code or click the link for the project that was shared with you.")
                NavigationLink(destination: AddProjectManualView()) {
                    Label("Add project", systemImage: "plus")
                        .font(.headline)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 20)
                }
                .prominentActionStyle()
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
