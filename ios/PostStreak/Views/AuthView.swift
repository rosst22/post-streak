import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var weeklyTarget = 3
    @State private var isCreatingAccount = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Post Streak")
                        .font(.largeTitle.bold())
                    Text("Track what you publish—not the numbers around it.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)

                Section(isCreatingAccount ? "Create account" : "Sign in") {
                    if isCreatingAccount {
                        Stepper("Weekly target: \(weeklyTarget)", value: $weeklyTarget, in: 1...14)
                    }
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)

                    Button(isCreatingAccount ? "Create account" : "Sign in") {
                        Task {
                            if isCreatingAccount {
                                await store.signUp(
                                    email: email,
                                    password: password,
                                    weeklyTarget: weeklyTarget
                                )
                            } else {
                                await store.signIn(email: email, password: password)
                            }
                        }
                    }
                    .disabled(email.isEmpty || password.count < 6 || store.isLoading)
                }

                Button(isCreatingAccount ? "I already have an account" : "Create an account") {
                    isCreatingAccount.toggle()
                }
            }
            .disabled(store.isLoading)
            .overlay { if store.isLoading { ProgressView() } }
        }
    }
}
