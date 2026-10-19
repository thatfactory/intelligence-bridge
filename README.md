<p align="center">
  <a href="https://developer.apple.com/swift/"><img alt="Swift Version" src="https://img.shields.io/badge/Swift-6.4-ea7a50.svg?logo=swift&logoColor=white"></a>
  <a href="https://developer.apple.com/xcode/"><img alt="Xcode Version" src="https://img.shields.io/badge/Xcode-27-50ace8.svg?logo=xcode&logoColor=white"></a>
  <a href="https://developer.apple.com/documentation/imageplayground"><img alt="Platforms" src="https://img.shields.io/badge/iOS%20%7C%20macOS%20%7C%20visionOS-26%2B-lightgrey.svg?logo=apple&logoColor=white"></a>
  <a href="https://developer.apple.com/documentation/xcode/swift-packages"><img alt="SPM" src="https://img.shields.io/badge/SPM-ready-b68f6a.svg?logo=gitlfs&logoColor=white"></a>
  <a href="https://thatfactory.github.io/intelligence-bridge/documentation/intelligencebridge/"><img alt="DocC" src="https://img.shields.io/badge/DocC-documentation-0288D1.svg?logo=bookstack&logoColor=white"></a>
  <a href="https://en.wikipedia.org/wiki/MIT_License"><img alt="License" src="https://img.shields.io/badge/License-MIT-67ac5b.svg?logo=googledocs&logoColor=white"></a>
  <a href="https://github.com/thatfactory/intelligence-bridge/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/thatfactory/intelligence-bridge/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/thatfactory/intelligence-bridge/actions/workflows/release.yml"><img alt="Release" src="https://github.com/thatfactory/intelligence-bridge/actions/workflows/release.yml/badge.svg"></a>
</p>

# IntelligenceBridge

IntelligenceBridge is a focused Apple-platform integration layer for Apple intelligence capabilities such as Image Playground and Foundation Models. It makes platform availability, framework integration, and presentation seams consistent without hiding Apple's frameworks or taking ownership of product prompts and persistence. 🧠

Image Playground is the package's first capability. Its existing API centralizes availability checks, concept setup, SwiftUI presentation wiring, cancellation, and temporary result handling while leaving generated-media persistence to the host application.

```swift
import IntelligenceBridge

let request = ImagePlaygroundBridgeRequest(concepts: [.text("a small red house")])

content
    .imagePlaygroundBridgeSheet(
        isPresented: $isPresented,
        request: request,
        onCompletion: { result in
            // Copy result.temporaryURL into host-owned storage here.
        }
    )
```

The presentation API is available on Apple platforms that support Image Playground. The package also compiles on tvOS so shared multiplatform application targets can resolve it, while ``ImagePlaygroundBridgeAvailability/current`` reports unavailable there.

On iOS, use `imagePlaygroundBridgePresentation` when the host needs to recover from a silent failure to open. It presents Apple's `ImagePlaygroundViewController` through an owned UIKit anchor, confirms opening, and bounds only the opening transition with a configurable 12-second deadline. It does not time out editing or generation, or detect readiness of Apple's internal generation interface.

```swift
content.imagePlaygroundBridgePresentation(
    isPresented: $isPresented,
    request: request,
    onOpened: { /* Stop the host's opening indicator. */ },
    onCompletion: { result in /* Consume result.temporaryURL synchronously. */ },
    onCancellation: { /* Record silent cancellation. */ },
    onLaunchFailure: { failure in /* Record unavailable or timedOut. */ },
    onDismissed: { /* Remove loading or show the host's recovery alert. */ }
)
```

Keep the modifier mounted until `onDismissed`. Completion and cancellation precede native dismissal; launch failures arrive after native cleanup, immediately before `onDismissed`. The presentation binding becomes false when dismissal finishes. Removing the host invalidates the attempt, dismisses its editor, and suppresses further host callbacks. Prompts, draft state, image decoding and storage, and error text remain the application's responsibility. The existing `imagePlaygroundBridgeSheet` API remains available unchanged on its supported platforms.

Foundation Models support preserves Apple's native API surface. Importing IntelligenceBridge on a supported platform also makes `SystemLanguageModel`, `LanguageModelSession`, `@Generable`, and `@Guide` available. Use the bridge availability value to decide whether to offer model-backed behavior while keeping prompts, sessions, generated values, and product policy in the host application.

```swift
import IntelligenceBridge

guard FoundationModelBridgeAvailability.current == .available else {
    return
}

let session = LanguageModelSession()
```

The availability mapping follows Apple's [`SystemLanguageModel.Availability`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum). It distinguishes disabled Apple Intelligence, an ineligible device, a model that is not ready, and an unsupported platform. The package does not wrap `LanguageModelSession` or introduce a generic language-model abstraction.

## Documentation

API documentation is published with DocC after a GitHub release. See the [IntelligenceBridge documentation](https://thatfactory.github.io/intelligence-bridge/documentation/intelligencebridge/).

## Requirements

- Swift 6.4
- Xcode 27
- Apple platform versions shown in the badge above
- Swift Package Manager

Cleanup reconciles public UIKit state for up to two seconds after closing begins, retaining its owner independently of the SwiftUI host. A late association is dismissed, and observed detachment can finish cleanup even if UIKit omits a completion callback. UIKit has no definitive rejection callback: a never-associated editor is considered closed after this reconciliation window, but an editor that remains attached is never falsely reported dismissed. Permanently stuck system presentation machinery cannot guarantee bounded recovery; the bridge does not dismiss an unrelated containing sheet.
