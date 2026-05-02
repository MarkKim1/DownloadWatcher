//
//  DuplicateFinder.swift
//  DownloadWatcher
//
//  Created by 김민석 on 4/28/26.
//

import Foundation

class DuplicateFinder {

    static func find(filename: String, excludingFolder: String) -> [String] {
        var results: [String] = []
        let semaphore = DispatchSemaphore(value: 0)

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemFSName == %@", filename)
        query.searchScopes = [NSMetadataQueryLocalComputerScope]

        let observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: nil
        ) { _ in
            query.stop()

            for i in 0..<query.resultCount {
                if let item = query.result(at: i) as? NSMetadataItem,
                   let path = item.value(forAttribute: kMDItemPath as String) as? String {
                    if !path.hasPrefix(excludingFolder) {
                        results.append(path)
                    }
                }
            }
            semaphore.signal()
        }

        DispatchQueue.main.async {
            query.start()
        }

        semaphore.wait()
        NotificationCenter.default.removeObserver(observer)

        return results
    }
}
