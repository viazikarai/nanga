import Foundation

struct ExecutionPackage: Equatable {
    var repositoryName: String
    var projectRootPath: String
    var task: TaskDraft
    var signal: [ExecutionSignal]
    var scopedFiles: [ScopedFileContext]
    var carryForwardItems: [String]
    var constraints: [String]

    var fileCount: Int {
        scopedFiles.count
    }
}

struct ExecutionSignal: Equatable {
    var kind: SignalItem.Kind
    var title: String
}

struct ScopedFileContext: Equatable {
    var path: String
    var content: String
    var lineCount: Int
    var wasTrimmed: Bool
}
