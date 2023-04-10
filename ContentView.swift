import SwiftUI
import OpenAISwift

let openAI = OpenAISwift(authToken: "API_KEY")

class MessageVars: ObservableObject {
    @Published var senders: [String] = ["chatgpticon"]
    @Published var texts: [String] = ["How can I help you today?"]
    @Published var roles: [ChatRole] = [.assistant]
    @Published var dummy: Int = -1
}

func chat(senders: inout [String], texts: inout [String], roles: inout [ChatRole], dummy: inout Int) async {
    do {
        var chat: [ChatMessage] = [
            ChatMessage(role: .system, content: "You are a helpful assistant.")
        ]

        if senders.count > 0 {
            for i in 1...senders.count {
                chat.append(ChatMessage(role: roles[i - 1], content: texts[i - 1]))
            }
            
            let result = try await openAI.sendChat(with: chat)
            
            senders.remove(at: dummy)
            roles.remove(at: dummy)
            texts.remove(at: dummy)
            dummy = -1

            senders.append("chatgpticon")
            roles.append(.assistant)
            texts.append(result.choices.first?.message.content ?? "Nothing")
        }
    } catch {
        print("Something went wrong")
    }
}

struct ContentView: View {
    @State private var input: String = ""
    @ObservedObject var vars: MessageVars = MessageVars()
    
    @State var nav: Bool = false
    
    var body: some View {
        ZStack {
            VStack {
                Header(nav: $nav, text: "ChatGPT")
                Spacer()
                Messages(senders: $vars.senders, texts: $vars.texts)
                Spacer()
                Sender(input: $input, senders: $vars.senders, texts: $vars.texts, roles: $vars.roles, dummy: $vars.dummy)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea())
            .zIndex(0)
            if nav {
                Nav(nav: $nav, current: "chatgpt")
                    .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
                    .zIndex(1)
            }
        }
    }
}

struct Header: View {
    @Binding var nav: Bool
    public var text: String
    
    var body: some View {
        HStack {
            Button {
                withAnimation {
                    nav = true
                }
            } label: {
                Image("menuicon")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            Spacer()
            Text(text)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .font(.system(size: 28))
            Spacer()
            Image("menuicon")
                .resizable()
                .frame(width: 30, height: 30)
                .opacity(0)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: 50, alignment: .center)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1).ignoresSafeArea())
    }
}

struct Messages: View {
    @Binding var senders: [String]
    @Binding var texts: [String]
    
    var body: some View {
        ScrollView {
            ScrollViewReader { value in
                VStack(spacing: 12) {
                    if senders.count > 0 {
                        ForEach(1...senders.count, id: \.self) { i in
                            Message(sender: senders[i - 1], text: texts[i - 1])
                        }
                        Spacer()
                            .id("anID")
                    }
                }.onChange(of: senders, perform: { count in
                    value.scrollTo("anID")
                })
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.all, 10)
            }
        }
    }
}

struct Message: View {
    public var sender: String
    public var text: String
    
    var body: some View {
        
        HStack(spacing: 8) {
            Image(sender)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(20)
                .frame(maxWidth: 30, maxHeight: 30, alignment: .top)
                .padding([.top, .leading, .bottom, .trailing], 3.0)
            Text(text)
                .font(.system(size: 16))
                .lineSpacing(3)
                .foregroundColor(text == "Loading..." ? .gray : .white)
                .padding([.top, .bottom, .trailing])
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
        .background(sender == "chatgpticon" ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.455, green: 0.667, blue: 0.612))
        .cornerRadius(20)
        .padding(sender == "chatgpticon" ? .trailing : .leading)
    }
}

struct Sender: View {
    @Binding var input: String
    @Binding var senders: [String]
    @Binding var texts: [String]
    @Binding var roles: [ChatRole]
    @Binding var dummy: Int
    
    @FocusState private var keyboard: Bool
    @State var startPos : CGPoint = .zero
    @State var isSwiping = true
    
    var body: some View {
        HStack {
            TextField("Chat", text: $input)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.18, green: 0.18, blue: 0.18)))
                .padding([.top, .leading, .bottom])
                .foregroundColor(.white)
                .focused($keyboard)
            Button {
                if input.count > 0 {
                    senders.append("usericon")
                    roles.append(.user)
                    texts.append(input)
                    senders.append("chatgpticon")
                    roles.append(.assistant)
                    texts.append("Loading...")
                    dummy = senders.count - 1
                    input = ""
                    Task {
                        await chat(senders: &senders, texts: &texts, roles: &roles, dummy: &dummy)
                    }
                }
            } label: {
                Image("sendicon2")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            .frame(width: 40, height: 40, alignment: .center)
            .cornerRadius(20)
            .padding([.top, .trailing, .bottom])
        }
        .frame(maxWidth: .infinity, maxHeight: 75)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1).ignoresSafeArea())
        .gesture(DragGesture()
            .onChanged { gesture in
                if self.isSwiping {
                    self.startPos = gesture.location
                    self.isSwiping.toggle()
                }
            }
            .onEnded { gesture in
                let xDist = abs(gesture.location.x - self.startPos.x)
                let yDist = abs(gesture.location.y - self.startPos.y)
                if self.startPos.y < gesture.location.y && yDist > xDist {
                    keyboard = false
                }
            }
        )
    }
}

struct Nav: View {
    @Binding var nav: Bool
    @State var isAnimating = false
    public var current: String
    
    var body: some View {
        VStack(spacing: 20) {
            Button {
                if current == "chatgpt" {
                    nav = false
                } else {
                    if let window = UIApplication.shared.connectedScenes.map({ $0 as? UIWindowScene }).compactMap({ $0 }).first?.windows.first {
                        window.rootViewController = UIHostingController(rootView: ContentView())
                        window.makeKeyAndVisible()
                    }
                }
            } label: {
                Text("ChatGPT")
                    .fontWeight(.light)
                    .foregroundColor(current == "chatgpt" ? Color(red: 0.455, green: 0.667, blue: 0.612) : .white)
                    .font(.system(size: 36))
            }
            .offset(y: isAnimating ? 0 : UIScreen.main.bounds.size.height / 2)
            .animation(.easeInOut(duration: 0.3).delay(0), value: isAnimating)
            Button {
                if current == "dalle" {
                    nav = false
                } else {
                    if let window = UIApplication.shared.connectedScenes.map({ $0 as? UIWindowScene }).compactMap({ $0 }).first?.windows.first {
                        window.rootViewController = UIHostingController(rootView: DallEView())
                        window.makeKeyAndVisible()
                    }
                }
            } label: {
                Text("Dall-E")
                    .fontWeight(.light)
                    .foregroundColor(current == "dalle" ? Color(red: 0.455, green: 0.667, blue: 0.612) : .white)
                    .font(.system(size: 36))
            }
            .offset(y: isAnimating ? 0 : UIScreen.main.bounds.size.height / 2)
            .animation(.easeInOut(duration: 0.3).delay(0.1), value: isAnimating)
            
            Button {
                if current == "whisper" {
                    nav = false
                } else {
//                    if let window = UIApplication.shared.connectedScenes.map({ $0 as? UIWindowScene }).compactMap({ $0 }).first?.windows.first {
//                        window.rootViewController = UIHostingController(rootView: WhisperView())
//                        window.makeKeyAndVisible()
//                    }
                }
            } label: {
                Text("Whisper")
                    .fontWeight(.light)
                    .foregroundColor(current == "whisper" ? Color(red: 0.455, green: 0.667, blue: 0.612) : .white)
                    .font(.system(size: 36))
            }
            .offset(y: isAnimating ? 0 : UIScreen.main.bounds.size.height / 2)
            .animation(.easeInOut(duration: 0.3).delay(0.2), value: isAnimating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea().opacity(0.95))
        .onTapGesture {
             nav = false
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
