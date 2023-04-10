import SwiftUI

struct DallEView: View {
    @State var nav: Bool = false
    @State var photos: [Photo] = []
    @State var waiting: Bool = false
    
    var body: some View {
        ZStack {
            VStack {
                Header(nav: $nav, text: "Dall-E")
                Spacer()
                Photos(photos: $photos, waiting: $waiting)
                Spacer()
                Sender2(photos: $photos, waiting: $waiting)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea())
            .zIndex(0)
            if nav {
                Nav(nav: $nav, current: "dalle")
                    .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
                    .zIndex(1)
            }
        }
    }
}

let api_key_free = "API_KEY"

func generateImage(from prompt: String, waiting: inout Bool) async throws -> [Photo] {
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
    request.setValue("Bearer \(api_key_free)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let parameters: [String: Any] = [
        "prompt": prompt,
        "n": 2,
        "size": "256x256"
    ]
    
    let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
    
    request.httpBody = jsonData
    
    let (data, response) = try await URLSession.shared.data(for: request)
    let dalleResponse = try? JSONDecoder().decode(DALLEResponse.self, from: data)
    
    waiting = false
    return dalleResponse?.data ?? []
}

struct Sender2: View {
    @State var input: String = ""
    
    @Binding var photos: [Photo]
    @Binding var waiting: Bool
    
    @FocusState private var keyboard: Bool
    @State var startPos: CGPoint = .zero
    @State var isSwiping = true
    
    var body: some View {
        HStack {
            TextField("Enter Prompt", text: $input)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.18, green: 0.18, blue: 0.18)))
                .padding([.top, .leading, .bottom])
                .foregroundColor(.white)
                .focused($keyboard)
            Button {
                if input.count > 0 {
                    let tempInput = input
                    input = ""
                    keyboard = false
                    waiting = true
                    Task {
                       do {
                           self.photos = try await generateImage(from: tempInput, waiting: &waiting)
//                           print(photos)
                       } catch (let error){
                           print(error)
                       }
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

struct Photos: View {
    @Binding var photos: [Photo]
    @Binding var waiting: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if waiting {
//                    Image("loading")
//                        .resizable()
//                        .frame(width: 50, height: 50)
                    Text("Loading...")
                        .foregroundColor(.gray)
                        .font(.system(size: 22))
                }
                ForEach(photos, id: \.url) { photo in
                    var pic = Image(systemName: "")
                    AsyncImage(url: URL(string: photo.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        let _ = DispatchQueue.main.async {
                            pic = image
                        }
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: 500)
                    .cornerRadius(20)
                    .contextMenu {
                        Button {
                            let image = pic.asUiImage()
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        } label: {
                            Text("Save Image")
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.all, 20)
        }
    }
}

struct DALLEResponse: Decodable {
    let created: Int
    let data: [Photo]
}

struct Photo: Decodable {
    let url: String
}

extension View {
    func asUiImage() -> UIImage {
        var uiImage = UIImage(systemName: "exclamationmark.triangle.fill")!
        let controller = UIHostingController(rootView: self)

        if let view = controller.view {
            let contentSize = view.intrinsicContentSize
            view.bounds = CGRect(origin: .zero, size: contentSize)
            view.backgroundColor = .clear
            
            let renderer = UIGraphicsImageRenderer(size: contentSize)
            uiImage = renderer.image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
        }
        return uiImage
    }
}



struct DallEView_Previews: PreviewProvider {
    static var previews: some View {
        DallEView()
    }
}
