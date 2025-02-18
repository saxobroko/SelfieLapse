import SwiftUI
import UIKit

class ShareViewController: UIViewController {
    let url: URL
    
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityVC.popoverPresentationController?.sourceView = view
            activityVC.popoverPresentationController?.sourceRect = view.bounds.insetBy(dx: 20, dy: 20)
        }
        
        present(activityVC, animated: true)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> ShareViewController {
        return ShareViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: ShareViewController, context: Context) {}
}