//
//  AuthView.swift
//  sightline
//
//  Created by Chris Sutton on 2/13/25.
//
import SwiftUI
import FirebaseAuth

struct AuthView: View {
    @EnvironmentObject var profileStore: ProfileStore // Use the ProfileStore
    @State private var isSignIn = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack {
                    // Background Image (Keep this)
                    Image("profile-bg")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()

                    // Content (Modified for ProfileStore)
                    VStack(spacing: 24) {
                        VStack(spacing: 24) {
                            // Header (Modified for ProfileStore)
                            VStack(spacing: 8) {
                                Text(isSignIn ? "Sign In" : "Create an Account")
                                .font(.custom("Baskerville-Bold", size: 24))
                                .foregroundColor(.black)

                                if profileStore.hasPendingSavedPlaces { // Use profileStore
                                    Text("Sign up to save your places!")
                                        .font(.custom("Baskerville", size: 18))
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                } else {
                                    Text(isSignIn ? "Welcome Back" : "Save Places, Post Content, and More")
                                        .font(.custom("Baskerville", size: 18))
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                }
                            }

                            // Form (Keep this, but modify button action)
                            VStack(spacing: 16) {
                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .foregroundColor(.black)
                                    

                                SecureField("Password", text: $password)
                                    .textContentType(isSignIn ? .password : .newPassword)
                                    .foregroundColor(.black)
                                    


                                if !isSignIn {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                        
                                }
                            }

                            if let error = profileStore.errorMessage { // Use profileStore
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.horizontal)
                            }

                            Button(action: {
                                Task {
                                    if isSignIn {
                                        await profileStore.signIn(email: email, password: password) // Use profileStore
                                    } else {
                                        await profileStore.signUp(email: email, password: password, confirmPassword: confirmPassword) // Use profileStore
                                    }
                                }
                            }) {
                                if profileStore.isLoading { // Use profileStore
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(isSignIn ? "Sign In" : "Create Account")
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding()
                            .background(Color.yellow)
                            .cornerRadius(10)
                            .disabled(profileStore.isLoading) // Use profileStore

                            // Toggle between Sign In and Sign Up (Modified for ProfileStore)
                            Button(action: {
                                withAnimation {
                                    isSignIn.toggle()
                                    profileStore.errorMessage = nil // Use profileStore
                                }
                            }) {
                                Text(isSignIn ? "Need an account? Sign Up" : "Already have an account? Sign In")
                                    .foregroundColor(.white)
                                    .underline()
                            }
                        }
                        .padding(24)
                        .background(.thinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 8)

                        Button(action: {
                            Task {
                                await profileStore.resetAccount() // Use profileStore
                            }
                        }) {
                            Text("Reset Account")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(edges: .top)
    }
}
