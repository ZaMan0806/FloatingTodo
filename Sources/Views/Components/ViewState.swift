// 뷰 상태 (@State 대신 사용)

import SwiftUI

/// `@State` 와 똑같이 쓰는 뷰 상태.
/// 최신 SDK 에서는 `@State` 가 매크로로 처리되는데, 그 매크로 플러그인(SwiftUIMacros)은 Xcode 에만 있어서
/// Command Line Tools 만 있는 맥에서는 빌드가 실패함 (https://github.com/ZaMan0806/FloatingTodo/issues/1).
/// State 를 속성 문법 없이 그냥 저장해 두면 매크로를 거치지 않음. SwiftUI 는 DynamicProperty 안쪽의 State 도 찾아서 관리함.
@propertyWrapper
struct ViewState<Value>: DynamicProperty {
    private var storage: State<Value>

    init(wrappedValue: Value) {
        storage = State(initialValue: wrappedValue)
    }

    var wrappedValue: Value {
        get { storage.wrappedValue }
        nonmutating set { storage.wrappedValue = newValue }
    }

    var projectedValue: Binding<Value> { storage.projectedValue }
}
