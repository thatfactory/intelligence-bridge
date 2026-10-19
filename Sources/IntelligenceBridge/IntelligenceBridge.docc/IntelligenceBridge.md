# ``IntelligenceBridge``

Integrate focused Apple intelligence capabilities while keeping product policy and persistence in the host application.

## Overview

Image Playground is the package's first capability. Use ``ImagePlaygroundBridgeAvailability/current`` to decide whether to offer generation, build an ``ImagePlaygroundBridgeRequest`` from portable ``ImagePlaygroundBridgeConcept`` values, and apply `SwiftUI/View/imagePlaygroundBridgeSheet(isPresented:request:onCompletion:onCancellation:)` to a host view.

Image Playground supplies ``ImagePlaygroundBridgeResult/temporaryURL`` only as temporary output. The completion callback is the host application's ownership boundary: copy the file into durable, application-owned storage before returning. IntelligenceBridge never persists images, reads a photo library, synchronizes media, or owns product-specific prompts.

For iOS hosts that need launch recovery, `imagePlaygroundBridgePresentation` adds confirmed opening, launch failure, and completed-dismissal callbacks through an owned UIKit presentation anchor. Its default 12-second opening deadline includes waiting for a window, rechecks actual presentation before reporting timeout, and stops permanently for that attempt once the controller opens. It does not measure the readiness of Apple's internal generation interface or limit editing. The existing cross-platform sheet API remains unchanged.

Consume completion results synchronously. Completion or cancellation is delivered before native dismissal; launch failure is delivered after cleanup. `onDismissed` follows each terminal outcome and sets the presentation binding to false. Keep the modifier mounted until dismissal completes so the host can then remove its loading screen or present a recovery alert. Removing the anchor invalidates pending callbacks and dismisses the owned native editor. The host owns localized recovery UI and must preserve its draft independently of native presentation.

For Foundation Models, use ``FoundationModelBridgeAvailability/current`` to decide whether to offer model-backed behavior. On supported platforms, importing IntelligenceBridge also exposes Apple's [`FoundationModels`](https://developer.apple.com/documentation/foundationmodels) APIs, including `SystemLanguageModel`, `LanguageModelSession`, `@Generable`, and `@Guide`. The host application owns prompts, sessions, generated values, and product policy; IntelligenceBridge does not wrap Apple's session API or define a generic language-model abstraction.

## Topics

### Availability and requests

- ``ImagePlaygroundBridgeAvailability``
- ``ImagePlaygroundBridgeConcept``
- ``ImagePlaygroundBridgeRequest``

### Presentation results

- ``ImagePlaygroundBridgeResult``
- ``ImagePlaygroundBridgeLaunchFailure``

### Foundation Models

- ``FoundationModelBridgeAvailability``
- ``FoundationModelBridgeAvailability/Reason``

Cleanup reconciles public UIKit state for up to two seconds after closing begins, retaining its owner independently of the SwiftUI host. A late association is dismissed, and observed detachment can finish cleanup even if UIKit omits a completion callback. UIKit has no definitive rejection callback: a never-associated editor is considered closed after this reconciliation window, but an editor that remains attached is never falsely reported dismissed. Permanently stuck system presentation machinery cannot guarantee bounded recovery; the bridge does not dismiss an unrelated containing sheet.
