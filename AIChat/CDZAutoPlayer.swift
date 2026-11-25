import SwiftUI
import WebKit

struct CDZAutoPlayer: View {
    let homework: MeshHomework
    let token: String
    let minutes: Double
    @Environment(\.dismiss) var dismiss
    @State private var tasks: [CDZTask] = []
    @State private var status = "Загружаю ответы с сервера МЭШ..."
    @State private var webView: WKWebView?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack { ProgressView(); Text(status).font(.caption); Spacer() }.padding(10).background(Color.orange.opacity(0.12))
                CDZWebView(urlString: homework.link, token: token, webView: $webView)
            }
            .navigationTitle("Авто ЦДЗ")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
            .task { await run() }
        }
    }
    func run() async {
        guard let found = await CDZResolver.fetch(link: homework.link, token: token), !found.isEmpty else { status = "Сервер не отдал ответы. Открой ЦДЗ и решай по ответам из чата."; return }
        tasks = found
        status = "Ответов получено: \(found.count). Проставляю по таймеру \(Int(minutes)) мин..."
        let delay = found.count > 0 ? max(2.0, minutes * 60.0 / Double(found.count)) : 2.0
        for task in found {
            try? await Task.sleep(nanoseconds: UInt64(min(delay, 120) * 1_000_000_000))
            await apply(task)
        }
        status = "Готово: проставлено \(found.count) ответов. Проверь и нажми сдачу в МЭШ сам."
    }
    func apply(_ task: CDZTask) async {
        let escaped = task.answer.replacingOccurrences(of: "'", with: "\\'")
        let js = "(function(){var a='\(escaped)';var ins=document.querySelectorAll('input[type=text],input:not([type])');for(var i=0;i<ins.length;i++){if(!ins[i].value){ins[i].focus();ins[i].value=a;ins[i].dispatchEvent(new Event('input',{bubbles:true}));ins[i].dispatchEvent(new Event('change',{bubbles:true}));return 'filled';}}var els=document.querySelectorAll('label,button,[role=radio],[role=option]');for(var j=0;j<els.length;j++){if(els[j].innerText&&els[j].innerText.trim()===a){els[j].click();return 'clicked';}}return 'notfound';})()"
        _ = try? await webView?.evaluateJavaScript(js)
    }
}

struct CDZWebView: UIViewRepresentable {
    let urlString: String
    let token: String
    @Binding var webView: WKWebView?
    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView()
        DispatchQueue.main.async { webView = w }
        if let url = URL(string: urlString) { var req = URLRequest(url: url); req.httpMethod = "GET"
            req.setValue("aupd_token=\(token)", forHTTPHeaderField: "Cookie")
            w.load(req)
        } else if let url = URL(string: urlString) { w.load(URLRequest(url: url)) }
        return w
    }
    func updateUIView(_ v: WKWebView, context: Context) {}
}
