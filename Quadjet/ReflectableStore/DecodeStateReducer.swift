// Copyright © 2023 hOS Inc. All rights reserved.

import ComposableArchitecture
import Foundation

public struct DecodeStateReducer<Base: ReducerProtocol, ScopedState>: ReducerProtocol {
    public typealias State = Base.State

    public enum Action {
        case decode(ScopedState)
        case passthrough(Base.Action)
    }

    let keyPath: WritableKeyPath<Base.State, ScopedState>
    let base: Base

    public func reduce(into state: inout Base.State, action: Action) -> EffectTask<Action> {
        switch action {
        case let .decode(newState):
            state[keyPath: keyPath] = newState
            return .none
        case let .passthrough(baseAction):
            return base
                .reduce(into: &state, action: baseAction)
                .map(Action.passthrough)
        }
    }
}

extension ReducerProtocol where State: Decodable {
    func decode<ScopedState: Decodable>(_ keyPath: WritableKeyPath<State, ScopedState>) -> DecodeStateReducer<Self, ScopedState> {
        DecodeStateReducer(keyPath: keyPath, base: self)
    }
}
