//
//  ReflectableStore.swift
//  Quadjet
//
//  Created by Andrew Chersky on 21.03.2023.
//

import Combine
import ComposableArchitecture
import Foundation

#if DEBUG
public final class ReflectableStore<Base: ReducerProtocol, ScopedState: Codable & Equatable> where Base.State: Codable & Equatable {
    typealias DecodeReducer = DecodeStateReducer<EncodeStateReducer<Base, ScopedState>, ScopedState>

    public let store: Store<Base.State, Base.Action>
    public let keyPath: WritableKeyPath<Base.State, ScopedState>
    public let url: URL

    private var wrapperStore: StoreOf<DecodeReducer>
    private var wrapperViewStore: ViewStoreOf<DecodeReducer>
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fileHandle: FileHandle?

    private let jsonDecoder = JSONDecoder()

    public init(
        initialState: Base.State,
        keyPath: WritableKeyPath<Base.State, ScopedState>,
        url: URL? = nil,
        reducer: Base
    ) {
        self.keyPath = keyPath
        self.url = url ?? Self.defaultHotReloadUrl
        wrapperStore = Store(
            initialState: initialState,
            reducer: DecodeReducer(
                keyPath: keyPath,
                base: reducer
                    .encode(keyPath, toFileAt: self.url)
            )
        )
        wrapperViewStore = ViewStore(wrapperStore)
        store = wrapperStore.scope(state: { $0 }, action: DecodeReducer.Action.passthrough)
    }

    func observe() throws {
        let fileManager = FileManager.default
        let filePath = url.path(percentEncoded: true)
        if !fileManager.fileExists(atPath: filePath) {
            fileManager.createFile(atPath: filePath, contents: Data())
        }

        let fileHandle = try FileHandle(forReadingFrom: url)
        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileHandle.fileDescriptor,
            eventMask: .extend,
            queue: .main
        )
        dispatchSource?.setEventHandler(qos: .userInitiated, flags: [.enforceQoS]) { [weak self] in
            guard let self else { return }
            do {
                try self.decodeKeyPath(contentsOf: self.url)
            } catch {
                print("Deflection Error: \(error)")
            }
        }
        dispatchSource?.activate()
        self.fileHandle = fileHandle
    }

    private func decodeKeyPath(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        let pathValue = try jsonDecoder.decode(ScopedState.self, from: data)
        if wrapperViewStore.state[keyPath: keyPath] != pathValue {
            wrapperViewStore.send(.decode(pathValue), animation: .default)
        }
    }

    deinit {
        try? fileHandle?.close()
        dispatchSource?.cancel()
        fileHandle = nil
        dispatchSource = nil
    }
}

public extension ReflectableStore {
    private static var defaultHotReloadUrl: URL {
        URL(
            filePath: NSHomeDirectory()
                .components(separatedBy: "/")
                .prefix(3)
                .joined(separator: "/")
                .appending("/Desktop/hot_reload.json")
        )
    }
}
#endif
