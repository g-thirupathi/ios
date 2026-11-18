# CLAUDE.md - AI Coding Guidelines for Philips Service Live (iOS)

## Project Overview

Philips Service Live (R2: Release 2) is the production, native Swift iOS implementation replacing the React Native app (R1: Release 1).
A separate SwiftUI+KMP proof of concept (POC) exists to demonstrate feasibility; it is not production architecture by default.
Android R2 is developed separately and is outside this repository's scope.

R1 defines existing product behavior unless an approved R2 requirement intentionally changes it. Do not translate R1 code file by file: identify the behavior first, then implement it natively.

The user-facing title is "Philips Service Live". Bundle identifier: `com.philips.serviceliveapp.dev`.

## Architecture

Based on Google's Guide to app architecture (UI layer, optional domain layer, data layer) and the Clean Architecture
dependency rule. Stricter than Google's guide in one point, as in Clean Architecture: application logic lives in
UseCases, and the data layer holds no application logic.

### Layers and dependencies

- **UI**: Screens and their Views, ViewModels
- **Domain** (optional): UseCases
- **Data**: Repositories, DataSources, Providers, Mappers
- **Models** are plain value types used by every layer

Dependencies point one way: View -> ViewModel -> UseCase (optional) -> Repository -> DataSource / Provider.

- ViewModels depend on UseCases and Repositories only; UseCases on Repositories and other UseCases, never in a cycle
- Repositories are the only entry point to data: only they use DataSources. Repositories and DataSources use Providers
- A Repository uses another Repository only for data it needs inside its own work (e.g. while applying incoming
  events), never in a cycle; otherwise a UseCase combines them
- SDK and platform types (Genesys, Keychain, FileManager, URLSession, NWPathMonitor, AVFoundation) appear only in
  DataSources, Providers and Mappers
- Every cross-boundary dependency is a protocol injected through the initializer. Only `AppDependencies` creates
  implementations

### Roles

| Role | Use it for | Rules |
|---|---|---|
| Model | The app's data and its pure rules | `Codable` value type shared by all layers by default; pure transitions and rules only, no dependencies |
| Mapper | Converting an external type (SDK type, DTO) into a Model | Caseless `enum` with static functions; no state, dependencies or side effects; lives next to its DataSource. Add a separate external model and Mapper only when the shapes genuinely differ |
| DataSource | Working with one source of one kind of data: an SDK, the Keychain, files, a backend | Speaks the source's language inside and returns Models; makes no decisions about which data is correct |
| Provider | A platform capability or generic engine that is not one feature's data: connectivity, permissions, build configuration, HTTP | No feature logic |
| Repository | The single entry point and source of truth for one kind of data | Data only: holds and publishes its in-memory state (`AsyncStream`), reads and writes its sources, combines them and resolves conflicts between them. No application logic. Named after the data, never a screen |
| UseCase | Application logic: one action, decision or flow | Any logic beyond reading and writing data, even with a single dependency; one `execute`; no stored state; never a pass-through that only forwards |
| ViewModel | The UI state of one screen | `ObservableObject`; prepares state for display and forwards user actions; no business logic |

- Data mechanics stay in the data layer: the order of writes (e.g. sends queued in order), how long data lives
  (expiry, retention) and merging sources. Decisions about what the app does (limits, retries, fallbacks, timeouts
  that fail an action) are application logic
- If something does not fit a role, add a role to this table before using it
- Do not create components ahead of need; add them only when a feature requires them

### State ownership

- Every piece of state has exactly one owner; others receive it or ask the owner, they do not keep copies
- The owner of a piece of state also owns its expiry; deadlines that fail an action belong to the UseCase running it
- Others change shared state only through named transitions on the Model (e.g. `markFailed(localId:)`), never by
  setting its fields directly

### Networking

- HTTP goes through one generic `NetworkProvider.request<T: Decodable>(_ endpoint: Endpoint) async throws -> T`.
  Remote DataSources call it; the provider has no per-endpoint methods

### Anti-patterns

- Facades: a type that only groups other components' actions. ViewModels call Repositories and UseCases directly
- Pass-through UseCases, or Repositories that only forward to another Repository
- Application logic in Repositories, DataSources or Providers
- Blanket DTO -> Domain -> UI triple mapping
- ViewModels or UseCases depending on DataSources, Providers, SDKs or platform APIs
- Adding a component "just in case"
- God types: one type that owns unrelated state, or is split across `extension` files only to look smaller
- Role words outside the naming table: Manager, Service, Store, Client, Helper, Utils, Support

## Composition

- Every type has one purpose that can be stated in one sentence without "and". Methods that touch disjoint sets of
  properties belong in different types
- Larger behavior is assembled by composing small types through constructor-injected protocols
- SwiftLint length limits are ceilings, not targets: review a type for a split when it nears about 200 lines or 7
  stored properties. Split by data (e.g. messages vs attachments), not by mechanism
- A helper used by only one type gets no role and is created by that type, never injected

## Naming

### Protocols and implementations

- The protocol has the role name that callers depend on (`ChatRepository`, `ChatRemoteDataSource`), never a
  `Protocol` suffix
- The implementation names what makes it specific:
  - DataSource and Provider: `<Technology><Protocol>`, e.g. `GenesysChatRemoteDataSource`,
    `KeychainPreferencesLocalDataSource`, `NWPathConnectivityProvider`
  - Repository and UseCase: `Default<Protocol>`, e.g. `DefaultChatRepository`, `DefaultSendMessageUseCase`
  - Test doubles: `Fake<Protocol>`, or a name for their behavior (e.g. `AlwaysOnlineConnectivityProvider`)
- Models, Mappers and UI types have no protocol

### Components

| Layer | Type | Convention | Examples |
|---|---|---|---|
| App | App entry | `<App>App`, one only | `PhilipsLiveApp` |
| App | Composition root | `AppDependencies`, one only; the only place that names implementations | `AppDependencies` |
| UI | Screen | `<Name>Screen`: a full destination (pushed, presented or a tab) | `ChatScreen`, `SettingsScreen` |
| UI | Container | `<Name>Container`: hosts screens or `@ViewBuilder` content and adds structure or chrome | `MainTabContainer`, `TopBarContainer` |
| UI | Component | `<Thing><Noun>`, noun from: Row, Bar, Banner, Button, Chip, Divider, Header, Menu, Notice, Section, Indicator, Thumbnail, Label, Card, Picker, Sheet, Avatar. Add a noun here before using it | `ChatMessageRow`, `ChatConnectionBanner` |
| UI | Component fallback | `<Thing>View`, only when no noun fits or the bare name would read as a Model | `MessageAttachmentView` |
| UI | UIKit bridge | The wrapped UIKit class name without `Controller` / `ViewController` | `SafariView`, `CameraPicker` |
| UI | UIKit subclass | Keeps UIKit's suffix | `SwipeBackController` |
| UI | ViewModifier | `private <Name>Modifier`, used only through a `View` extension method of the same name | `DarkThemeModifier` -> `.darkTheme()`, `ChatAttachmentPresentationModifier` -> `.chatAttachmentPresentation()` |
| UI | Layout | `<Name>Layout` | `CallCardLayout`, `CappedWidthLayout` |
| UI | Preference or environment key | `<Name>Key` | `ChatScrollMetricsKey` |
| UI | View-owned helper class | Named for what it does, never a role word | `ChatScroller`, `AttachmentThumbnailCache` |
| UI | ViewModel | `<Screen>ViewModel` | `ChatViewModel`, `HomeViewModel` |
| Domain | UseCase | `<Verb><Noun>UseCase` | `SendMessageUseCase`, `ConnectChatUseCase` |
| Data | Repository | `<Data>Repository` | `ChatRepository`, `SupportCountryRepository` |
| Data | Remote DataSource | `<Data>RemoteDataSource` | `ChatRemoteDataSource`, `ChatAttachmentRemoteDataSource` |
| Data | Local DataSource | `<Data>LocalDataSource` | `ChatLocalDataSource`, `PreferencesLocalDataSource` |
| Data | Provider | `<Capability>Provider` | `ConnectivityProvider`, `CameraPermissionProvider` |
| Data | Mapper | `<Source>Mapper` | `ChatSdkMapper` |
| Model | Model | Plain noun, no suffix | `ChatMessage`, `SupportCountry` |
| Model | Namespace | Caseless `enum` named for the concept | `ChatScroll` |

- Role suffixes are reserved for components wired in `AppDependencies`

### Files and extensions

- One type per file, named after the type, helpers included. Exceptions: nested types, a private ViewModifier in
  its `View+<Concern>.swift` file, and private extensions of the file's own type
- No grab-bag files (`Support`, `Helpers`, `Utils`)
- Extensions live in `<Type>+<Concern>.swift`:
  - Models: `Transitions` (state changes), `Events` (applying incoming events), `Rules` (limits and validation),
    `Merging` (comparing and merging copies), `Persistence` (restoring and saving), `Display` (values for the UI;
    lives in the UI folder), or the protocol name for a conformance (`ChatMessage+Codable.swift`)
  - Views: `View+<Concern>.swift`, holding the private modifier and its public method (`View+DarkTheme.swift`)
  - Types we do not own: `<Type>+<Feature or concern>.swift` (`DlsAsset+Chat.swift`, `Date+Epoch.swift`)
- Model extensions hold pure functions over the type's own state: no dependencies, no I/O, no SDK types
- `extension` files are for conformances and small helpers over a type's own state, not for adding responsibilities

## Code Style

- Swift: SwiftLint + SwiftFormat enforced, max width 120
- Write concise code with no unnecessary comments
- Comments explain why, in as few lines as possible. No provenance ("ported from R1", "as in R1"); mention R1
  only for a compatibility constraint, such as data R1 stored that R2 must read
- No magic literals. A value used by one type is a private constant there; shared values, or ones that must match R1
  or Android, live in a caseless-enum namespace for their domain, never in one global constants file. Layout metrics
  come from the design system; if none fits, keep a private constant in the view and flag it to the user

## Design assets

- Claude never creates, draws, traces or generates icons, images, illustrations or any other design asset, in any
  format (SVG, PDF, PNG, SF Symbol, a SwiftUI shape standing in for an icon), not even as a placeholder
- Use only Filament's assets or ones the design team supplies (exported from Figma). If a needed asset is missing,
  stop and tell the user: what is missing, where it appears in Figma, and the options (an asset from the design
  team, or an existing Filament asset as a stand-in the user approves). Add nothing until they choose
- When planning a feature, list every asset it needs and which are not yet available

## Platform

- Deployment target is iOS 16.0 (Filament's minimum). Swift 6 language mode with MainActor default isolation
- Use only iOS 16 APIs; anything newer needs `if #available` with an iOS 16 fallback. Not available: Observation
  (`@Observable`, `@Bindable`), two-parameter `onChange`, `ContentUnavailableView`, `scrollPosition`
- Prefer modern iOS 16 APIs: `NavigationStack` with `navigationDestination(for:)`, `async`/`await`, `.task`,
  `AsyncStream`, actors. No Combine or completion handlers in new code unless an SDK requires them

## Localization

- Every user-facing string is localized; no hard-coded UI text. Strings live in
  `PhilipsLiveApp/Resources/Localizable.xcstrings` (source language `en`) under R1's keys (`<Screen>.<key>`,
  e.g. `ChatScreen.end_chat`)
- The translation team owns the text. `Localizable.xcstrings` is copied 1:1 from R1's locale files
  (`src/utils/localization/en.ts`, `es.ts`, `pt.ts`, `es-PR.ts` on R1's `develop`), literally: a language
  holds only the keys its R1 file sets, with no English copies stored. The fallback to English is code's job, as in R1
  (`...englishStrings`, `fallbackLng`); SwiftUI's `Text("key")` bypasses `LanguageRoutingBundle`'s fallback, so every
  string must be resolved through `L10n` or the key itself is shown. Only `{count}`
  becomes `%lld`. Claude never writes, rewords or translates user-facing text, in any language (English and Figma copy
  included). If an existing key has a similar meaning, suggest it to the user and wait for their choice; do not reuse
  it automatically. If R2 needs a string R1 does not have, do not add one: propose a `<Screen>.<key>` and list it (key
  plus reference copy) to the user in chat as missing; until the text arrives the key shows as-is
- Supported languages follow R1, except en-GB: R1's UK version never went live, so a stored `en-GB` falls back to
  English. Adding a language means adding it to the catalog and to `knownRegions` in `project.yml`
- The language is chosen in-app (Language & Region) during onboarding, persisted, and applied immediately without a
  restart. `LanguageRepository` persists and publishes it, and `BundleLocalizationProvider` redirects `Bundle.main`
  lookups to the selected `.lproj`; the app root sets `.environment(\.locale, ...)`. Strings resolve when a view is
  built, and the language is applied before the main screen exists, so nothing is rebuilt. Never put `.id(language)`
  on the root: it resets the navigation state and replays the splash
- Resolve every string through `L10n` (`Core/Localization/L10n.swift`): `L10n.string("key")`, or `L10n.key("key")` for
  Filament APIs that only take a `LocalizedStringKey`. Never call `NSLocalizedString`, `LocalizedStringKey("key")`,
  `Text("key")`, `String(localized:)` or `LocalizedStringResource`, or use generated String Catalog symbols: they
  bypass the runtime language switch and the English fallback, and a lint rule fails the build on them. Our own
  components take string keys (`titleKey: String`) and resolve them with `L10n`
- Format dates and numbers with the selected language's locale, not `Locale.current`

## Working boundaries

- Modify files in this repository only.
- R1 (`../Philips_Live_App`, RN source in `PhilipsLiveApp/src`) and the POC (`../OneSpace-app/iosApp`) are
  read-only references.
- Do not copy POC architectural choices into R2 without evaluating them.
- Do not read or expose credentials, signing assets, or user data.
- Do not change signing, bundle IDs, deployment targets, dependencies, or build configurations without calling out the change and its impact.

## Acting on requests

- Write or change code only on an explicit instruction to do so ("implement this", "fix this", "add this", "change this", or a direct instruction to code). A question, an idea, an observation ("this looks off", "can we...?", "what if...?") is not one
- Without that instruction, do research or planning, whichever fits the request:
  - Research: investigate the code, R1, the POC, Figma, or online sources, then report findings, options and a recommendation
  - Planning: for a change that is significant or has design choices, propose a short plan and wait for agreement
- Read-only checks (searching, reading, type-checking) are always fine. Edits and generated or installed files are not, until the instruction is clear
- If it is unclear whether the user wants an answer or a change, answer first and offer the change

## Grounding

- Before relying on what you know, evaluate it: is it canonical, and is it up to date for this query? Treat anything version-dependent (Filament, SwiftUI and iOS APIs, Xcode and XcodeGen settings, the Genesys SDK, other dependencies) as possibly stale
- If it is not canonical or current, or the answer should follow Apple or community best practice, check online before answering or coding: Apple documentation first, then the dependency's own docs and source, then established community sources. Do not guess
- Prefer the installed version's source and headers over memory, and say which version you checked
- State what was verified and what could not be verified. If a source is unreachable (private or login-gated), say so instead of falling back to a guess

## Commits

- The commit author is the user only: no `Co-Authored-By` trailer and no other attribution lines, in commits or PR descriptions
- One short, simple subject line of at most 72 characters (GitHub cuts longer ones into the description) in
  sentence-case imperative, no type prefix and no trailing period; no body unless essential

## Change workflow

1. Inspect the relevant R2 code and documentation before making changes.
2. For migrated features, inspect the corresponding R1 behavior and relevant POC findings; identify uncertain or missing requirements.
3. For significant changes, propose a short plan before implementation.
4. Make the smallest coherent change that satisfies the task.
5. Do not create test files for now, even for changed behavior. Existing tests may be updated only when asked.
6. Run the relevant available checks and report exactly what ran and what could not run.

## Project and builds

- XcodeGen's `project.yml` is the source of truth for the generated Xcode project. Do not hand-edit generated `.xcodeproj` files.
- Never run `xcodegen` (or `xcodegen generate`) yourself. When a change needs the project regenerated (new files, `project.yml` edits), say so and let the user run it. This also means `xcodebuild` and tests can't be run until they have regenerated; report that instead of working around it.
- Keep environment-specific build settings in `.xcconfig` files where practical.
- Use Swift Package Manager for dependencies unless the repository documents an exception.
- Use the repository's documented scripts or Make targets for generation, build, lint, and tests. Do not guess command names: check `README.md`, `Makefile`, and `Scripts/` first.
- If project generation or a build fails, report the failure; do not claim verification succeeded.

## Build Commands

```bash
# iOS (requires xcodegen generate first)
xcodebuild build -project PhilipsLiveApp.xcodeproj -scheme PhilipsLiveApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
xcodebuild test -project PhilipsLiveApp.xcodeproj -scheme PhilipsLiveApp -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'

# Linting
swiftlint lint && swiftformat --lint .
```

## Chat Configuration

Chat (Genesys Cloud Web Messaging) uses one deployment ID and domain per support country, as in R1.
`GENESYS_DEPLOYMENT_ID` / `GENESYS_DOMAIN` serve India and any country without its own pair; the others use a
country suffix: `_ES`, `_PT`, `_PR` (Spain and Portugal fall back to the default domain).
The United Arab Emirates, Oman and Qatar share one pair, suffix `_META`, and the chat sends the chosen country to its
flow as the Genesys custom attribute `userCountry`.
iOS bakes them into the generated `.xcodeproj` and from there into `Info.plist` (`GenesysChatConfigurations`).
The build **fails** if the default pair is empty; a missing country pair shows the "chat not configured" error
at runtime, like R1.

The values must be set in the shell that runs `xcodegen generate`, because XcodeGen substitutes
them (`${GENESYS_DEPLOYMENT_ID}` etc. in `project.yml`) into the gitignored project at *generate* time:

```bash
export GENESYS_DEPLOYMENT_ID="..." GENESYS_DOMAIN="mypurecloud.de" GENESYS_DEPLOYMENT_ID_ES="..." # etc.
xcodegen generate
```

Do **not** rely on `launchctl setenv`, launching Xcode from a shell, or per-target build
settings: the Xcode IDE build system does not promote process/`launchd` environment variables
into build settings, so a `$(GENESYS_DEPLOYMENT_ID)` reference resolves to empty for GUI builds.
Baking the values in at generate time is what makes IDE and command-line builds behave
identically. Re-run `xcodegen generate` (from a shell with the variables exported) after every
regeneration; do a clean build if you change the values. Never hard-code them — they are
repository secrets.
