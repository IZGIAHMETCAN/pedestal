//
//  ContentView.swift
//  mobileApp
//
//  Created by mobie app on 28.01.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView()
            } else {
                SignInView()
            }
            
            
        }
        .animation(.easeInOut, value: authViewModel.isAuthenticated)
    }
}


#Preview {
    AddCardView()
        .environmentObject(AuthViewModel())
}
