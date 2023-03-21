// Copyright © 2023 hOS Inc. All rights reserved.

import ComposableArchitecture
import Foundation

struct EncodeStateReducer<Base: ReducerProtocol, ScopedState>: ReducerProtocol where Base.State: Encodable, ScopedState: Encodable {
    private let uniqueIdentifier = UUID()
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    let keyPath: KeyPath<Base.State, ScopedState>
    let base: Base
    let url: URL

    func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<Base.Action> {
        let baseEffects = base.reduce(into: &state, action: action)
        let sideEffects = encode(scopedStateOf: state)
        return baseEffects.merge(with: sideEffects)
    }

    private func encode(scopedStateOf state: Base.State) -> EffectTask<Base.Action> {
        .fireAndForget { [scopedState = state[keyPath: keyPath], jsonEncoder] in
            do {
                let jsonData = try jsonEncoder.encode(scopedState)
                try jsonData.write(to: url, options: [])
            } catch {
                print("Reflection Error: \(error)")
            }
        }.cancellable(id: uniqueIdentifier, cancelInFlight: true)
    }
}

extension ReducerProtocol where State: Encodable {
    func encode<ScopedState: Encodable>(_ keyPath: KeyPath<State, ScopedState>, toFileAt url: URL) -> EncodeStateReducer<Self, ScopedState> {
        EncodeStateReducer(keyPath: keyPath, base: self, url: url)
    }
}
