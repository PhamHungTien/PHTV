import SwiftUI

struct TestView: View {
    @State var sel = 1
    var body: some View {
        VStack {
            Picker("", selection: $sel) {
                Text("Short").tag(1)
                Text("Very Long Text Indeed").tag(2)
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 148)
            .background(Color.red)
        }
    }
}
