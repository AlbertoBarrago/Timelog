# User Flows

## 1. Time Tracking — Start and Stop

```mermaid
sequenceDiagram
    actor U as User
    participant V as HomeView
    participant SS as StartTrackingSheet
    participant CTX as ModelContext
    participant NM as NotificationManager
    participant LA as LiveActivity (iOS)

    U->>V: Tap "Start session"
    V->>SS: Opens sheet
    U->>SS: Select Client and/or Project
    U->>SS: Tap "Start"
    SS->>CTX: insert(ActiveSession)
    CTX-->>V: Updates active session list
    SS->>NM: scheduleSessionOverdue(id, endHour, endMinute)
    SS->>LA: startLiveActivity() [iOS only]
    LA-->>U: Lock screen + Dynamic Island active

    Note over V: Timer tick every 60s (TimelineView)

    U->>V: Tap "Stop" on the session
    V->>StopSheet: Opens sheet with estimated duration
    U->>StopSheet: Confirm duration (minutes)
    StopSheet->>CTX: insert(TimeEntry)
    StopSheet->>CTX: delete(ActiveSession)
    CTX-->>V: Updated list
    StopSheet->>NM: cancelSession(id)
    StopSheet->>LA: endLiveActivity() [iOS only]
```

## 2. Quick Log (manual entry)

```mermaid
flowchart TD
    A([Tap Quick Log]) --> B[QuickLogSheet]
    B --> C{Client selected?}
    C -->|No| D[Log without client]
    C -->|Yes| E{Project selected?}
    E -->|No| F[Log with client only]
    E -->|Yes| G[Log with client and project]
    D & F & G --> H[insert TimeEntry\ndate=today, durationMinutes, notes]
    H --> I[Dismiss sheet]
    I --> J[HomeView updated\nSync debounced 2s\niOS: RestSyncService · macOS: MongoSyncService]
```

## 3. iOS Sync — RestSyncService

```mermaid
sequenceDiagram
    participant App as TimelogApp (onAppear)
    participant RSS as RestSyncService
    participant KCH as Keychain
    participant File as SyncConfig.local (bundle)
    participant SD as SwiftData
    participant VCL as Vercel Functions

    App->>RSS: loadConfigFromFile()
    RSS->>File: reads SyncConfig.local (URL + API_KEY)
    RSS->>KCH: saveConfig(serverURL, apiKey)

    App->>RSS: setDataProvider { container.mainContext }
    Note over App: isPulling = true

    App->>RSS: pullAll(into: modelContext) [async]
    RSS->>VCL: GET /api/pull?userId=…  X-API-Key: ...
    VCL-->>RSS: { clients, projects, entries, sessions }

    RSS->>SD: upsert clients by mongoId → save
    RSS->>SD: upsert projects (link client) by mongoId
    RSS->>SD: upsert entries (link client+project) by mongoId
    RSS->>SD: replace sessions scoped to userId → save
    RSS->>RSS: lastSyncDate = .now
    Note over App: isPulling = false\nSyncFlashOverlay: green flash + haptic

    Note over App: onChange(clients/projects/entries/sessions)
    App->>RSS: triggerSync() [if !isPulling]
    RSS->>RSS: debounce 2s
    RSS->>SD: fetch all data via dataProvider
    RSS->>VCL: POST /api/sync { userId, clients, projects, entries, sessions }
    Note over VCL: upsert all + delete this user's\nsessions absent from payload
    RSS->>RSS: lastSyncDate = .now
```

## 4. macOS Sync — MongoSyncService

```mermaid
sequenceDiagram
    participant App as TimelogMacApp (onAppear)
    participant MSS as MongoSyncService
    participant KCH as Keychain
    participant File as mongo.local
    participant SD as SwiftData
    participant MDB as MongoDB Atlas

    App->>MSS: loadConnectionStringFromFile()
    MSS->>KCH: readConnectionString()
    alt Keychain empty
        KCH-->>MSS: nil
        MSS->>File: reads ~/.config/timelog/mongo.local
        MSS->>KCH: saveConnectionString(trimmed)
    end

    App->>MSS: setDataProvider { container.mainContext }
    App->>MSS: connect() [async]
    MSS->>MDB: MongoDatabase.connect(uri)

    alt SwiftData empty (first launch)
        App->>MSS: pullAll(into: modelContext)
        MSS->>MDB: find all clients/projects/time_entries
        MDB-->>MSS: documents
        MSS->>SD: upsert by mongoId → context.save()
    end

    App->>MSS: triggerSync()
    MSS->>SD: dataProvider() — fetch all data
    MSS->>MDB: upsertEncoded on clients/projects/time_entries
    MSS->>MSS: lastSyncDate = .now

    Note over App: onChange(clients/projects/entries)
    App->>MSS: triggerSync()
    MSS->>MSS: debounce 2s → push
```

## 5. Pomodoro Timer

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Work : toggle() - pomodoroEnabled=true
    Idle --> FreeRun : toggle() - pomodoroEnabled=false

    FreeRun --> Idle : toggle() (pause/reset)

    Work --> WorkPaused : toggle()
    WorkPaused --> Work : toggle()
    Work --> ShortBreak : phaseComplete()\ncompletedPomodoros % pomodorosBeforeLong ≠ 0
    Work --> LongBreak : phaseComplete()\ncompletedPomodoros % pomodorosBeforeLong == 0

    ShortBreak --> ShortBreakPaused : toggle()
    ShortBreakPaused --> ShortBreak : toggle()
    ShortBreak --> Work : phaseComplete()

    LongBreak --> LongBreakPaused : toggle()
    LongBreakPaused --> LongBreak : toggle()
    LongBreak --> Work : phaseComplete()
```

### Phase transition — detail

```mermaid
sequenceDiagram
    participant T as TimerViewModel
    participant NM as NotificationManager
    participant H as Haptics (iOS)
    participant LA as LiveActivity (iOS)

    T->>T: tick() every 1 second
    T->>T: elapsed >= phaseTotal?

    alt Phase complete
        T->>NM: schedulePomodoroEnd(phase, in: 0)
        T->>H: UIImpactFeedbackGenerator.heavy [iOS only]
        T->>T: completedPomodoros++ (if Work)
        T->>T: phase = nextPhase()
        T->>T: elapsed = 0
        T->>LA: updateLiveActivity(phase, isRunning) [iOS only]
    end
```

## 6. Notifications

```mermaid
flowchart LR
    subgraph Types
        R["Daily reminder\n'Time to log your hours!'"]
        S["Open session\n'You have an open session'"]
        P["Pomodoro complete\n'Work phase done!'"]
    end

    subgraph Trigger
        RS["SettingsStore.applyReminders()\n→ reschedule(hour, minute, days)"]
        SS2["StartTrackingSheet\n→ scheduleSessionOverdue(...)"]
        PP["TimerViewModel.phaseComplete()\n→ schedulePomodoroEnd(...)"]
    end

    subgraph Cancel
        CR["cancelAllReminders()\nif reminderEnabled=false"]
        CS["StopSessionSheet\n→ cancelSession(id)"]
        CP["New phase tick\n→ cancelPomodoroNotification()"]
    end

    RS --> R
    SS2 --> S
    PP --> P
    CR -.-> R
    CS -.-> S
    CP -.-> P
```

## 7. Live Activity (iOS)

```mermaid
sequenceDiagram
    participant VM as TimerViewModel
    participant AK as ActivityKit
    participant LS as Lock Screen / Dynamic Island

    VM->>AK: Activity.request(attributes, contentState)
    AK-->>LS: Shows "session running"

    loop every 1 second
        VM->>VM: tick() — elapsed++
        VM->>AK: activity.update(contentState)
        AK-->>LS: Updates displayTime
    end

    VM->>AK: activity.end(dismissalPolicy: .immediate)
    AK-->>LS: Removes Live Activity
```

## 8. Navigation — macOS

```mermaid
flowchart TD
    MenuBar["MenuBarExtra\n(always visible)"] -->|click| MBV["MenuBarView\n(window style)"]
    MBV --> QA["Quick actions:\nStart · Stop · Quick Log"]

    Dock["WindowGroup 'main'"] --> MMV["MainMacView\nNavigationSplitView"]
    MMV -->|"Today"| TV["TodayMacView"]
    MMV -->|"Clients"| CV["ClientsMacView → ProjectsMacView"]
    MMV -->|"Tracking"| TRV["TimerMacView"]
    MMV -->|"Settings"| SV["MacSettingsView"]

    Cmd,["⌘,"] --> Prefs["Settings scene\nMacSettingsView"]
```

## 9. Navigation — iOS

```mermaid
flowchart TD
    App["TimelogApp"] --> Tab["TabView"]
    Tab -->|"Today"| H["HomeView"]
    Tab -->|"Clients"| C["ClientsView"]
    Tab -->|"Timer"| T["TimerView"]
    Tab -->|"Settings"| S["SettingsView"]

    H -->|"sheet"| ST["StartTrackingSheet"]
    H -->|"sheet"| SP["StopSessionSheet"]
    H -->|"sheet"| QL["QuickLogSheet"]
    H -->|"NavigationLink"| HV["HistoryView"]

    C -->|"NavigationLink"| PL["ProjectListView"]
    PL -->|"sheet"| PF["ProjectFormView"]
    C -->|"sheet"| CF["ClientFormView"]
```
