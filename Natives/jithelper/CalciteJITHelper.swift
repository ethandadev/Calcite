// Calcite JIT helper: a tiny app extension that runs StikJIT in its own process.
//
// iOS only grants JIT while a debugger is attached, and a process cannot debug itself without
// freezing (the debugger would freeze the very threads that drive it). So Calcite starts this
// extension, sends it the game's PID, the pairing file and the JIT script, and the extension
// attaches to Calcite from the outside. See docs/JIT.md.
//
// Wire format: one JSON request in the input item's userInfo["calcite-jit-request"], one JSON
// response in the returned item's userInfo["calcite-jit-response"].

import Foundation
import StikJIT

private struct JITRequest: Decodable {
    let op: String          // "prepare" | "enable" | "reset"
    let pid: Int32?
    let pairing: Data?      // pairing file bytes (never logged)
    let script: String?     // base64 UTF-8 JIT script
    let force: Bool?        // run the script even when TXM isn't detected
}

private struct JITResponse: Encodable {
    let success: Bool
    let message: String
    let txm: Bool?
}

private enum Work {
    /// StikJIT's calls block and must run in order, so everything goes through one queue.
    static let queue = DispatchQueue(label: "dev.ethandadev.calcite.jit-helper")

    static func handle(_ request: JITRequest) -> JITResponse {
        let fm = FileManager.default
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StikJIT", isDirectory: true)
        let paths = DDIPaths.default(in: library)
        do {
            try fm.createDirectory(at: library, withIntermediateDirectories: true)

            if request.op == "reset" {
                try StikJIT.resetCachedDDI(at: paths)
                return JITResponse(success: true, message: "Developer Disk Image cache cleared.", txm: StikJIT.isTXMPresent)
            }

            guard let pairing = request.pairing, !pairing.isEmpty else {
                throw NSError(domain: "CalciteJITHelper", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No pairing file was provided."])
            }
            let pairingURL = library.appendingPathComponent("pairing-\(UUID().uuidString).plist")
            try pairing.write(to: pairingURL, options: .atomic)
            defer { try? fm.removeItem(at: pairingURL) }

            switch request.op {
            case "prepare":
                let readiness = StikJIT.prepareDevice(pairingFile: pairingURL, paths: paths) { stage in
                    NSLog("[CalciteJIT] prepare: %@", String(describing: stage))
                }
                switch readiness {
                case .ready(let state):
                    return JITResponse(success: true, message: "Ready: the device is reachable and the Developer Disk Image is mounted.", txm: state.isTXMPresent)
                case .unreachable(let reason), .preparationFailed(let reason):
                    return JITResponse(success: false, message: reason, txm: StikJIT.isTXMPresent)
                @unknown default:
                    return JITResponse(success: false, message: "StikJIT returned an unknown state.", txm: StikJIT.isTXMPresent)
                }
            case "enable":
                guard let pid = request.pid, let script = request.script, !script.isEmpty else {
                    throw NSError(domain: "CalciteJITHelper", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "The target process or JIT script was missing."])
                }
                try StikJIT.enableJIT(
                    targetPID: pid,
                    pairingFile: pairingURL,
                    ddiPaths: paths,
                    script: .customBase64(script),
                    forceScript: request.force ?? true,
                    preparationProgress: { NSLog("[CalciteJIT] prepare: %@", String(describing: $0)) },
                    progress: { NSLog("[CalciteJIT] %@", $0) })
                return JITResponse(success: true, message: "JIT is on and the debugger detached.", txm: StikJIT.isTXMPresent)
            default:
                throw NSError(domain: "CalciteJITHelper", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "Unknown operation \(request.op)."])
            }
        } catch {
            return JITResponse(success: false, message: error.localizedDescription, txm: StikJIT.isTXMPresent)
        }
    }
}

/// NSExtensionPrincipalClass (see Info.plist).
@objc(CalciteJITHelperHandler)
final class CalciteJITHelperHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let info = (context.inputItems.first as? NSExtensionItem)?.userInfo
        let data = info?["calcite-jit-request"] as? Data
        Work.queue.async {
            let response: JITResponse
            if let data, let request = try? JSONDecoder().decode(JITRequest.self, from: data) {
                response = Work.handle(request)
            } else {
                response = JITResponse(success: false, message: "The JIT helper received no request.", txm: nil)
            }
            let item = NSExtensionItem()
            item.userInfo = ["calcite-jit-response": (try? JSONEncoder().encode(response)) ?? Data()]
            context.completeRequest(returningItems: [item], completionHandler: nil)
        }
    }
}
