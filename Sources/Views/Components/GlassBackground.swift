// Liquid Glass (macOS 26+), 이전 버전은 반투명 재질로 대체

import SwiftUI

struct GlassBackground<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)   // Xcode 26(macOS 26 SDK) 이상에서만 Liquid Glass 코드를 컴파일
        if #available(macOS 26.0, *) {
            content.glassEffect(tint.map { Glass.regular.tint($0) } ?? Glass.regular, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        if let tint {
            content.background(tint, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}
