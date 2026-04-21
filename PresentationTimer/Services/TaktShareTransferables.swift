import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Wraps a temp **file URL** so the share sheet gets a real UTI (PNG / JSON / Markdown), not a generic “data” blob.
struct TaktSharedPNGFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { file in
            SentTransferredFile(file.url)
        }
    }
}

struct TaktSharedJSONFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            SentTransferredFile(file.url)
        }
    }
}

struct TaktSharedMarkdownFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: mdUTI) { file in
            SentTransferredFile(file.url)
        }
    }

    /// Prefer the `.md` type so Files shows a text/markdown document, not “data”.
    private static var mdUTI: UTType {
        UTType(filenameExtension: "md") ?? .utf8PlainText
    }
}
