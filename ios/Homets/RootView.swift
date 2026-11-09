import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UTType { static let hometsExerciseOrder = UTType(exportedAs: "com.addvalue.homets.exercise-order") }
private struct ExerciseOrderItem: Codable, Transferable {
    let id: String
    static var transferRepresentation: some TransferRepresentation { CodableRepresentation(contentType: .hometsExerciseOrder) }
}

private struct ExerciseMoveDropDelegate: DropDelegate {
    let store: WorkoutStore
    let targetID: String

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.hometsExerciseOrder]) }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.hometsExerciseOrder]).first else { return false }
        provider.loadTransferable(type: ExerciseOrderItem.self) { result in
            guard case .success(let item) = result else { return }
            Task { @MainActor in _ = store.moveExercise(item.id, before: targetID) }
        }
        return true
    }
}

enum HometsStyle {
    static let ink = Color.adaptive(light: 0x132D40, dark: 0xEAF3F5)
    static let text2 = Color.adaptive(light: 0x43586B, dark: 0xA8BCC6)
    static let text3 = Color.adaptive(light: 0x546779, dark: 0x8298A5)
    static let blue = Color.adaptive(light: 0x2A4CB3, dark: 0x89A3F0)
    static let mint = Color.adaptive(light: 0xE3F2EB, dark: 0x1B3936)
    static let lavender = Color.adaptive(light: 0xE9E7F8, dark: 0x2C2E49)
    static let background = Color.adaptive(light: 0xF4F7F6, dark: 0x101820)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x182430)
    static let surfaceRaised = Color.adaptive(light: 0xFFFFFF, dark: 0x1E2B38)
    static let border = Color.adaptive(light: 0xD6E0E4, dark: 0x304653)
    static let strongBorder = Color.adaptive(light: 0xB9C9D0, dark: 0x46606D)
    static let input = Color.adaptive(light: 0xE8ECF7, dark: 0x243248)
    static let selected = Color.adaptive(light: 0xEEF0FA, dark: 0x2C3454)
    static let chartBar = Color.adaptive(light: 0xDDE3F2, dark: 0x394761)
    static let gradient = LinearGradient(colors: [mint, lavender], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let buttonGradient = LinearGradient(colors: [Color.adaptive(light: 0x3554B8, dark: 0x617CCB), Color.adaptive(light: 0x2A439E, dark: 0x4E67B0)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .black, .heavy, .bold: .custom("Barlow-ExtraBold", size: size)
        case .semibold, .medium: .custom("Barlow-SemiBold", size: size)
        default: .custom("Barlow-Regular", size: size)
        }
    }
}

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light)) })
    }
}

struct RootView: View {
    let store: WorkoutStore
    let purchases: PurchaseService
    @State private var tab = 0
    @State private var settings = false
    @AppStorage("homets.dark") private var dark = false
    @AppStorage("homets.language") private var language = "ko"
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                AppHeader(settings: $settings, dark: $dark)
                    .background(HometsStyle.background)
                    .zIndex(4)
                ZStack(alignment: .bottom) {
                    Group {
                        switch tab {
                        case 1: HistoryView(store: store, settings: $settings, dark: $dark)
                        case 2: StatsView(store: store, settings: $settings, dark: $dark)
                        default: WorkoutView(store: store, settings: $settings, dark: $dark)
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 58) }
                    if tab == 0, let remaining = store.restRemaining {
                        RestTimerView(store: store, remaining: remaining)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 66 - max(0, geometry.safeAreaInsets.bottom - 10))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(2)
                    }
                    FloatingTabBar(selection: $tab)
                        .offset(y: max(0, geometry.safeAreaInsets.bottom - 10))
                        .zIndex(3)
                }
            }
        }
        .id(language)
        .simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        })
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(dark ? .dark : .light)
        .environment(\.hometsLanguage, language)
        .environment(\.locale, Locale(identifier: language == "en" ? "en_US" : "ko_KR"))
        .sheet(isPresented: $settings) {
            NavigationStack { SettingsView(store: store, purchases: purchases, resetToken: UUID()) { _ in } }
                .presentationDetents([.large]).presentationCornerRadius(22)
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var selection: Int
    let items = [("dumbbell", "운동"), ("calendar", "기록"), ("chart.bar", "통계")]
    var body: some View {
        HStack(spacing: 5) {
            ForEach(items.indices, id: \.self) { i in
                Button { selection = i } label: {
                    Label(tr(items[i].1), systemImage: items[i].0).font(HometsStyle.font(14, .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(selection == i ? HometsStyle.blue : HometsStyle.text2)
                        .background(selection == i ? HometsStyle.input : .clear, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain)
            }
        }
        .padding(5).frame(height: 58)
        .background(HometsStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(HometsStyle.border))
        .padding(.horizontal, 12)
    }
}

private struct AppHeader: View {
    @Binding var settings: Bool
    @Binding var dark: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image("BrandMark").resizable().scaledToFit().frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text("HOMETS").font(HometsStyle.font(24, .black)).tracking(0.5).foregroundStyle(HometsStyle.ink)
                Text(hometsDate(.now, dateStyle: .full))
                    .font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 3)
            Button { dark.toggle() } label: { Image(systemName: dark ? "sun.max" : "moon") }.buttonStyle(HeaderButton())
            Button { settings = true } label: { Image(systemName: "gearshape") }.buttonStyle(HeaderButton())
        }.padding(.leading, 24).padding(.trailing, 20).padding(.top, 16).padding(.bottom, 12)
    }
}

private struct HeaderButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17)).foregroundStyle(HometsStyle.text2).frame(width: 26, height: 32)
            .background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(HometsStyle.border))
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

private struct WorkoutView: View {
    let store: WorkoutStore
    @Binding var settings: Bool
    @Binding var dark: Bool
    @State private var targets: [String: Int] = [:]
    var saved: Int { store.activeExercises.reduce(0) { $0 + store.loggedSets(for: $1).count } }
    var reps: Int { store.activeExercises.reduce(0) { $0 + store.loggedSets(for: $1).reduce(0) { $0 + $1.value } } }
    var completed: Int { store.activeExercises.filter { store.loggedSets(for: $0).count >= store.plannedSets($0.id) }.count }
    var displayedExercises: [Exercise] {
        let exercises = store.activeExercises
        let unfinished = exercises.filter { store.loggedSets(for: $0).count < store.plannedSets($0.id) }
        let completed = exercises.filter { store.loggedSets(for: $0).count >= store.plannedSets($0.id) }
        return unfinished + completed
    }
    var progress: Double { store.activeExercises.isEmpty ? 0 : Double(completed) / Double(store.activeExercises.count) }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SessionHero(count: store.activeExercises.count, saved: saved, progress: progress).padding(.horizontal, 16)
                SummaryRow(done: completed, count: store.activeExercises.count, sets: saved, reps: reps).padding(.horizontal, 16)
                Text(tr("반복 횟수를 조절하고 저장하세요. 각 운동은 마지막 입력값 또는 저장된 횟수를 기억합니다."))
                    .font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32).padding(.top, 12).padding(.bottom, 2)
                SetsStepper(store: store).padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)
                HStack {
                    Text(tr("운동 목록")).font(HometsStyle.font(10, .semibold)).tracking(1)
                    Spacer(); Text(UserDefaults.standard.string(forKey: "homets.language") == "en" ? "\(store.activeExercises.count) exercises" : "운동 \(store.activeExercises.count)개").font(HometsStyle.font(10)).foregroundStyle(HometsStyle.text2)
                }.padding(.horizontal, 16).padding(.bottom, 9)
                LazyVStack(spacing: 12) {
                    ForEach(displayedExercises) { exercise in
                        ExerciseCard(store: store, exercise: exercise, value: target(exercise))
                            .opacity(store.loggedSets(for: exercise).count >= store.plannedSets(exercise.id) ? 0.55 : 1)
                            .overlay(alignment: .top) {
                                Color.clear
                                    .frame(height: 78)
                                    .contentShape(Rectangle())
                                    .draggable(ExerciseOrderItem(id: exercise.id)) {
                                        ZStack(alignment: .topTrailing) {
                                            ExerciseCard(store: store, exercise: exercise, value: target(exercise))
                                                .frame(width: UIScreen.main.bounds.width - 32)
                                                .contentShape(RoundedRectangle(cornerRadius: 18))
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                                .frame(width: 34, height: 34).background(HometsStyle.blue, in: Circle())
                                                .padding(8)
                                        }
                                    }
                            }
                            .onDrop(of: [.hometsExerciseOrder], delegate: ExerciseMoveDropDelegate(store: store, targetID: exercise.id))
                    }
                }.padding(.horizontal, 16)
            }.padding(.bottom, 24)
        }.background(HometsStyle.background.ignoresSafeArea())
    }
    func target(_ ex: Exercise) -> Binding<Int> { Binding(get: { targets[ex.id] ?? store.suggestedTarget(for: ex) }, set: { targets[ex.id] = $0 }) }
}

private struct SessionHero: View {
    let count: Int, saved: Int
    let progress: Double
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) { Circle().fill(HometsStyle.blue).frame(width: 5, height: 5); Text(tr(saved > 0 ? "운동 진행 중" : "운동 준비 완료")) }
                    .font(HometsStyle.font(9, .semibold)).tracking(1.5).foregroundStyle(HometsStyle.blue).padding(.bottom, 8)
                Text(tr("오늘의 운동")).font(HometsStyle.font(27, .semibold)).foregroundStyle(HometsStyle.ink)
                Text(UserDefaults.standard.string(forKey: "homets.language") == "en" ? "\(count) exercises · \(count * 3) planned sets" : "운동 \(count)개 · 예정 \(count * 3)세트").font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2).padding(.top, 9)
            }
            Spacer(minLength: 4)
            ZStack {
                Circle().stroke(HometsStyle.surfaceRaised.opacity(0.72), lineWidth: 8)
                Circle().trim(from: 0, to: progress).stroke(Color.adaptive(light: 0x8EA8D6, dark: 0x91A8DD), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 3) { Text("\(Int(progress * 100))%").font(HometsStyle.font(22, .semibold)); Text(tr("완료")).font(HometsStyle.font(11)).foregroundStyle(HometsStyle.text2) }
            }.frame(width: 74, height: 74).shadow(color: HometsStyle.blue.opacity(0.08), radius: 8, y: 4)
        }.padding(.vertical, 22).padding(.horizontal, 18).background(HometsStyle.gradient, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct SummaryRow: View {
    let done, count, sets, reps: Int
    var body: some View {
        HStack(spacing: 0) {
            Metric(value: "\(done)/\(count)", label: tr("완료 운동")); Divider().frame(height: 48).overlay(HometsStyle.strongBorder)
            Metric(value: "\(sets)", label: tr("저장 세트")); Divider().frame(height: 48).overlay(HometsStyle.strongBorder)
            Metric(value: "\(reps)", label: tr("총 반복 횟수"))
        }.padding(.top, 18).padding(.bottom, 15).overlay(alignment: .bottom) { Rectangle().fill(HometsStyle.border).frame(height: 1) }
    }
}

private struct Metric: View {
    let value, label: String
    var body: some View { VStack(spacing: 5) { Text(value).font(HometsStyle.font(23, .semibold)); Text(label).font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2) }.frame(maxWidth: .infinity) }
}

private struct SetsStepper: View {
    let store: WorkoutStore
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) { Text(tr("운동별 세트 수")).font(HometsStyle.font(14, .semibold)); Text(tr("저장한 세트는 유지됩니다.")).font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2) }
            Spacer(); SquareButton(icon: "minus") { store.changeSets(-1) }; Text("\(store.defaultSets)").font(HometsStyle.font(19, .semibold)).frame(width: 25); SquareButton(icon: "plus") { store.changeSets(1) }
        }.padding(.horizontal, 14).padding(.vertical, 16).background(HometsStyle.gradient, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SquareButton: View {
    let icon: String, action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: icon).font(.system(size: 15, weight: .medium)).frame(width: 40, height: 40) }.foregroundStyle(HometsStyle.ink).background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(HometsStyle.border)).buttonStyle(.plain) }
}

private struct ExerciseCard: View {
    let store: WorkoutStore, exercise: Exercise
    @Binding var value: Int
    @State private var weight = ""
    @State private var distance = ""
    @State private var minutes = ""
    @State private var editingIndex: Int?
    @State private var confirmReset = false
    @State private var timedRemaining: Int?
    @State private var timedTask: Task<Void, Never>?
    var sets: [LoggedSet] { store.loggedSets(for: exercise) }
    var validInput: Bool {
        if exercise.tracking == .cardio {
            guard let km = Double(distance), let mins = Double(minutes) else { return false }
            return km > 0 && km <= 999 && mins >= 0.1 && mins <= 1440
        }
        guard weight.isEmpty || Double(weight) != nil else { return false }
        return weight.isEmpty || (Double(weight)! >= 0 && Double(weight)! <= 2000)
    }
    var recentRecordText: String {
        let weights = store.recentWeights(for: exercise)
        if let best = store.previousBest(for: exercise), exercise.tracking != .cardio {
            if let w = weights.first {
                return "\(tr("최근")): \(String(format: "%gkg", w)) · \(best)\(tr(exercise.tracking == .seconds ? "초" : "회"))"
            }
            return "\(tr("최근")): \(best)\(tr(exercise.tracking == .seconds ? "초" : "회"))"
        } else if let w = weights.first {
            return "\(tr("최근")): \(String(format: "%gkg", w))"
        }
        return tr("최근 기록 없음")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "dumbbell.fill").font(.system(size: 17)).foregroundStyle(HometsStyle.blue).frame(width: 38, height: 38).background(HometsStyle.selected, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.localizedName).font(HometsStyle.font(16, .semibold))
                    Text("\(exercise.localizedGroup) · \(recentRecordText)").font(HometsStyle.font(12)).foregroundStyle(HometsStyle.text2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(value)").font(HometsStyle.font(26, .bold))
                    Text(tr(exercise.tracking == .seconds ? "목표 시간" : "목표 횟수")).font(HometsStyle.font(11)).foregroundStyle(HometsStyle.text2)
                }
            }.padding(.horizontal, 15).padding(.top, 16).padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 8) {
                if !sets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                                HStack(spacing: 3) {
                                    Button("\(index + 1) · \(set.value)\(exercise.tracking == .seconds ? "s" : "")") { beginEditing(index, set) }
                                    Button { store.removeSet(at: index, for: exercise); editingIndex = nil } label: { Image(systemName: "arrow.uturn.backward") }
                                }
                                .font(HometsStyle.font(11, .semibold)).foregroundStyle(HometsStyle.blue)
                                .padding(.horizontal, 8).frame(height: 30).background(HometsStyle.surface, in: Capsule())
                            }
                        }
                    }
                }
                Text(editingIndex == nil ? "\(tr("세트")) \(sets.count + 1) / \(store.plannedSets(exercise.id))" : (UserDefaults.standard.string(forKey: "homets.language") == "en" ? "Edit set \((editingIndex ?? 0) + 1)" : "\((editingIndex ?? 0) + 1)세트 수정")).font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2)
                HStack(spacing: 5) {
                    if exercise.tracking == .cardio {
                        TextField("km", text: $distance).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                        TextField(tr("분"), text: $minutes).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    } else if exercise.tracking == .seconds {
                        TextField("60", value: $value, format: .number)
                            .font(HometsStyle.font(15, .semibold)).keyboardType(.numberPad).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 8))
                            .disabled(timedRemaining != nil)
                        Button(timedRemaining.map { "\($0)\(tr("초"))" } ?? tr(editingIndex == nil ? (sets.isEmpty ? "시작" : "다음 세트 시작") : "저장")) {
                            if let editingIndex {
                                store.updateSet(at: editingIndex, value: value, for: exercise)
                                self.editingIndex = nil
                            } else {
                                startTimedSet()
                            }
                        }
                        .font(HometsStyle.font(12, .semibold)).foregroundStyle(.white)
                        .frame(width: 100, height: 36)
                        .background(HometsStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 9)).buttonStyle(.plain)
                        .disabled(timedRemaining != nil || store.restRemaining != nil || store.activeTimedExerciseID != nil || value < 1 || value > 999)
                        .opacity(timedRemaining == nil && store.restRemaining == nil && store.activeTimedExerciseID == nil && value >= 1 && value <= 999 ? 1 : 0.5)
                    } else {
                    CompactButton(icon: "minus") { value = max(1, value - 1) }
                    Text("\(value)\(tr("회"))").font(HometsStyle.font(15, .semibold)).frame(maxWidth: .infinity, minHeight: 36).background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 8))
                    CompactButton(icon: "plus") { value = min(999, value + 1) }
                        TextField("kg", text: $weight).font(HometsStyle.font(15, .semibold)).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(maxWidth: 65)
                    }
                    if exercise.tracking != .seconds { Button(tr("저장")) {
                        if UserDefaults.standard.object(forKey: "homets.haptics") as? Bool ?? true { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        if let editingIndex {
                            store.updateSet(at: editingIndex, value: value, for: exercise, weight: Double(weight), distance: Double(distance), duration: Double(minutes).map { $0 * 60 })
                            self.editingIndex = nil
                        } else {
                            store.log(value, for: exercise, weight: Double(weight), distance: Double(distance), duration: Double(minutes).map { $0 * 60 })
                        }
                    }.font(HometsStyle.font(12, .semibold)).foregroundStyle(.white).frame(width: 48, height: 36)
                        .background(HometsStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 9)).buttonStyle(.plain).disabled(store.restRemaining != nil || store.activeTimedExerciseID != nil || !validInput).opacity(store.restRemaining == nil && store.activeTimedExerciseID == nil && validInput ? 1 : 0.5)
                    }
                }.font(HometsStyle.font(14))
                if let remaining = timedRemaining {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(HometsStyle.surface)
                            Capsule().fill(HometsStyle.blue)
                                .frame(width: proxy.size.width * CGFloat(remaining) / CGFloat(max(1, value)))
                                .animation(.linear(duration: 1), value: remaining)
                        }
                    }.frame(maxWidth: .infinity).frame(height: 5)
                }
            }.padding(10).background(HometsStyle.input, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 15)
            HStack {
                Text(UserDefaults.standard.string(forKey: "homets.language") == "en" ? "\(sets.count) / \(store.plannedSets(exercise.id)) sets saved" : "\(sets.count) / \(store.plannedSets(exercise.id))세트 저장됨").foregroundStyle(HometsStyle.text2)
                Spacer(); if editingIndex != nil { Button(tr("수정 취소")) { editingIndex = nil } }
            }.font(HometsStyle.font(12)).padding(.horizontal, 15).padding(.top, 12)
            HStack(spacing: 10) { Button(tr("+ 세트 추가")) { store.changeSets(1, id: exercise.id) }; Button(tr("− 세트 삭제")) { store.changeSets(-1, id: exercise.id) }; Text("\(sets.count) / \(store.plannedSets(exercise.id)) \(tr("저장"))"); Button(tr("횟수 초기화")) { value = store.suggestedTarget(for: exercise) }; if !sets.isEmpty {
                Button(tr("기록 초기화"), role: .destructive) { confirmReset = true }
                    .popover(isPresented: $confirmReset, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                        VStack(spacing: 8) {
                            Text(hometsIsEnglish ? "Reset today’s records?" : "오늘 기록 초기화?")
                                .font(HometsStyle.font(14, .semibold))
                            HStack(spacing: 16) {
                                Button(tr("취소")) { confirmReset = false }
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                Button(hometsIsEnglish ? "Reset" : "초기화", role: .destructive) {
                                    store.resetToday(for: exercise); editingIndex = nil; confirmReset = false
                                }.frame(maxWidth: .infinity, minHeight: 36)
                            }.font(HometsStyle.font(14, .semibold)).buttonStyle(.plain)
                        }.padding(12).frame(width: 210).fixedSize(horizontal: false, vertical: true)
                            .presentationCompactAdaptation(.popover)
                    }
            } }
                .font(HometsStyle.font(12)).foregroundStyle(HometsStyle.text2).lineLimit(1).minimumScaleFactor(0.72)
                .padding(.horizontal, 15).padding(.top, 10).padding(.bottom, 14)
        }.background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(HometsStyle.border)).shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .textSelection(.disabled)
    }
    private func startTimedSet() {
        timedTask?.cancel()
        guard store.beginTimedExercise(exercise) else { return }
        let duration = min(999, max(1, value))
        timedRemaining = duration
        store.scheduleExerciseTimerNotification(after: duration, exerciseName: exercise.localizedName)
        timedTask = Task { @MainActor in
            let deadline = Date.now.addingTimeInterval(Double(duration))
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                timedRemaining = remaining == 0 ? nil : remaining
                if remaining == 0 {
                    if UserDefaults.standard.object(forKey: "homets.haptics") as? Bool ?? true { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    store.finishTimedExercise(duration, for: exercise)
                    timedTask = nil
                    return
                }
            }
        }
    }
    private func beginEditing(_ index: Int, _ set: LoggedSet) {
        editingIndex = index; value = set.value
        weight = set.weight.map { String(format: "%g", $0) } ?? ""
        distance = set.distanceKm.map { String(format: "%g", $0) } ?? ""
        minutes = set.durationSeconds.map { String(format: "%g", $0 / 60) } ?? ""
    }
}

private struct CompactButton: View {
    let icon: String, action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 36)
                .background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(HometsStyle.border))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(HometsStyle.ink).buttonStyle(.plain)
    }
}

private struct RestTimerView: View {
    let store: WorkoutStore, remaining: Int
    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("휴식 타이머")).font(HometsStyle.font(12, .semibold)).foregroundStyle(HometsStyle.text2)
                Spacer()
                Text("\(remaining)").font(HometsStyle.font(32, .bold)).monospacedDigit().foregroundStyle(HometsStyle.ink)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(HometsStyle.input)
                    Capsule().fill(HometsStyle.blue).frame(width: proxy.size.width * min(1, CGFloat(remaining) / CGFloat(max(1, store.data.settings.defaultRestSeconds))))
                }
            }.frame(height: 4)
            HStack(spacing: 8) {
                Button("−10") { store.adjustRest(-10) }
                    .font(HometsStyle.font(12, .semibold)).foregroundStyle(HometsStyle.text2)
                    .padding(.horizontal, 10).frame(height: 34)
                    .background(HometsStyle.input, in: RoundedRectangle(cornerRadius: 8))
                Button("+10") { store.adjustRest(10) }
                    .font(HometsStyle.font(12, .semibold)).foregroundStyle(HometsStyle.text2)
                    .padding(.horizontal, 10).frame(height: 34)
                    .background(HometsStyle.input, in: RoundedRectangle(cornerRadius: 8))
                Button { store.stopRest() } label: {
                    Text(tr("휴식 종료"))
                        .font(HometsStyle.font(14, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(HometsStyle.blue, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(HometsStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(HometsStyle.border))
        .shadow(color: HometsStyle.ink.opacity(0.14), radius: 12, y: 4)
    }
}

private struct HistoryView: View {
    let store: WorkoutStore
    @Binding var settings: Bool
    @Binding var dark: Bool
    @State private var expandedDay: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("운동 LOG")).font(HometsStyle.font(15, .semibold)).tracking(0.8).foregroundStyle(HometsStyle.text2).padding(.bottom, 2)
                ForEach(store.sortedDays) { day in
                    VStack(spacing: 0) {
                        Button { withAnimation(.easeInOut(duration: 0.2)) { expandedDay = expandedDay == day.id ? nil : day.id } } label: {
                            HStack(spacing: 14) {
                                VStack(spacing: 1) {
                                    Text(month(day.id)).font(HometsStyle.font(11)).foregroundStyle(HometsStyle.text2)
                                    Text(day.id.suffix(2)).font(HometsStyle.font(27, .semibold)).foregroundStyle(HometsStyle.blue)
                                }.frame(width: 58, height: 64).background(HometsStyle.gradient, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(names(day)).font(HometsStyle.font(16, .semibold)).foregroundStyle(HometsStyle.ink).lineLimit(1)
                                    HStack(spacing: 13) {
                                        if UserDefaults.standard.string(forKey: "homets.language") == "en" {
                                            Text("\(setCount(day)) sets"); Text("\(total(day)) total"); Text("\(day.sets.count) exercises")
                                        } else {
                                            Text("세트 \(setCount(day))"); Text("합계 \(total(day))회"); Text("운동 \(day.sets.count)개")
                                        }
                                    }.font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2)
                                }
                                Spacer(minLength: 2)
                                Image(systemName: expandedDay == day.id ? "chevron.up" : "chevron.down").font(.system(size: 13, weight: .bold)).foregroundStyle(HometsStyle.text2)
                            }.padding(.horizontal, 16).padding(.vertical, 14)
                                .background(HometsStyle.input)
                        }.buttonStyle(.plain)
                        if expandedDay == day.id {
                            VStack(spacing: 0) {
                                ForEach(store.exercises.filter { day.sets[$0.id] != nil }) { exercise in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(exercise.localizedName).font(HometsStyle.font(14, .semibold)).foregroundStyle(HometsStyle.ink)
                                        Spacer()
                                        Text(day.sets[exercise.id, default: []].map { set in
                                            "\(set.value)\(tr(exercise.tracking == .seconds ? "초" : "회"))" + (set.weight.map { String(format: " / %g kg", $0) } ?? "")
                                        }.joined(separator: " · "))
                                            .font(HometsStyle.font(14, .semibold)).foregroundStyle(HometsStyle.blue).multilineTextAlignment(.trailing)
                                    }.padding(.vertical, 8).overlay(alignment: .bottom) { Rectangle().fill(HometsStyle.border).frame(height: 1) }
                                }
                            }.padding(.horizontal, 16).padding(.vertical, 7).background(HometsStyle.surface)
                                .overlay(alignment: .top) { Rectangle().fill(HometsStyle.border).frame(height: 1) }
                        }
                    }
                    .background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 17))
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(HometsStyle.border))
                }
                if store.sortedDays.isEmpty {
                    Text(tr("아직 저장된 운동 기록이 없습니다.")).font(HometsStyle.font(15)).foregroundStyle(HometsStyle.text2)
                        .frame(maxWidth: .infinity).padding(.vertical, 60)
                }
            }.padding(.horizontal, 16).padding(.bottom, 24)
        }.background(HometsStyle.background.ignoresSafeArea()).onAppear { expandedDay = store.sortedDays.first?.id }
    }
    func month(_ id: String) -> String { let n = Int(id.dropFirst(5).prefix(2)) ?? 1; return hometsIsEnglish ? ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"][n - 1] : "\(n)월" }
    func setCount(_ day: WorkoutDay) -> Int { day.sets.values.reduce(0) { $0 + $1.count } }
    func total(_ day: WorkoutDay) -> Int { day.sets.values.flatMap { $0 }.reduce(0) { $0 + $1.value } }
    func names(_ day: WorkoutDay) -> String { store.exercises.filter { day.sets[$0.id] != nil }.map(\.localizedName).joined(separator: ", ") }
}

private struct StatsView: View {
    let store: WorkoutStore
    @Binding var settings: Bool
    @Binding var dark: Bool
    @State private var period = 1
    @State private var anchor = Date.now
    var interval: DateInterval { Calendar.current.dateInterval(of: period == 0 ? .day : period == 1 ? .weekOfYear : .month, for: anchor)! }
    func key(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    var days: [WorkoutDay] { store.sortedDays.filter { $0.id >= key(interval.start) && $0.id < key(interval.end) } }
    var sets: Int { days.reduce(0) { $0 + $1.sets.values.reduce(0) { $0 + $1.count } } }
    var reps: Int { days.flatMap { day in day.sets.filter { id, _ in store.exercises.first { $0.id == id }?.tracking == .repetitions }.values.flatMap { $0 } }.reduce(0) { $0 + $1.value } }
    var exerciseIDs: [String] { Array(Set(days.flatMap { $0.sets.filter { !$0.value.isEmpty }.keys })).sorted() }
    var previousInterval: DateInterval {
        let duration = interval.duration
        return DateInterval(start: interval.start.addingTimeInterval(-duration), end: interval.start)
    }
    var previousReps: Int {
        store.sortedDays.filter { $0.id >= key(previousInterval.start) && $0.id < key(previousInterval.end) }
            .flatMap { day in day.sets.filter { id, _ in store.exercises.first { $0.id == id }?.tracking == .repetitions }.values.flatMap { $0 } }
            .reduce(0) { $0 + $1.value }
    }
    var allSets: [LoggedSet] { store.sortedDays.flatMap { $0.sets.values.flatMap { $0 } } }
    var streak: Int {
        var result = 0; let date = Date.now; let calendar = Calendar.current
        for offset in 0..<366 {
            let candidate = calendar.date(byAdding: .day, value: -offset, to: date) ?? date
            let hasRecord = store.data.days[key(candidate)]?.sets.values.contains { !$0.isEmpty } == true
            if !hasRecord && offset == 0 { continue }
            if !hasRecord { break }
            result += 1
        }
        return result
    }
    func shift(_ delta: Int) { anchor = Calendar.current.date(byAdding: period == 0 ? .day : period == 1 ? .weekOfYear : .month, value: delta, to: anchor)! }
    var daily: [(String, Int)] {
        let calendar = Calendar.current
        let count = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
        return (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: interval.start) ?? anchor
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
            let key = formatter.string(from: date)
            let label = hometsDate(date, dateStyle: .short)
            let value = store.data.days[key]?.sets.values.flatMap { $0 }.reduce(0) { $0 + $1.value } ?? 0
            return (label, value)
        }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Button { period = index } label: {
                            Text(tr(["일간", "주간", "월간"][index]))
                                .font(HometsStyle.font(17, .semibold))
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .foregroundStyle(HometsStyle.ink)
                                .background(period == index ? HometsStyle.surface : .clear, in: Capsule())
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }.padding(3).background(HometsStyle.input, in: Capsule())
                HStack {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(PeriodButton())
                    Spacer(); Text(periodTitle).font(HometsStyle.font(14, .semibold)); Spacer()
                    Button { shift(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(PeriodButton()).disabled(interval.end > .now)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(reps)").font(HometsStyle.font(46, .semibold)); Text(tr("총 반복 횟수")).font(HometsStyle.font(16)).foregroundStyle(HometsStyle.text2)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(HometsStyle.gradient, in: RoundedRectangle(cornerRadius: 17))
                HStack(spacing: 8) {
                    StatBox(value: sets, label: tr("저장 세트")); StatBox(value: days.count, label: tr("운동 일수")); StatBox(value: exerciseIDs.count, label: tr("운동 종류"))
                }
                Text(tr("선택한 기간의 운동 기록"))
                    .font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).frame(maxWidth: .infinity, alignment: .leading)
                Text(UserDefaults.standard.string(forKey: "homets.language") == "en" ? "\(reps - previousReps >= 0 ? "+" : "")\(reps - previousReps) reps vs. previous period" : "이전 기간 대비 \(reps - previousReps >= 0 ? "+" : "")\(reps - previousReps)회")
                    .font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).frame(maxWidth: .infinity, alignment: .leading)
                DailyChart(values: daily)
                ExerciseStatsTable(store: store, ids: exerciseIDs, days: days)
                Text(UserDefaults.standard.string(forKey: "homets.language") == "en" ? "All time: \(store.sortedDays.count) days · \(allSets.count) sets\nCurrent streak: \(streak) days" : "전체 누적: \(store.sortedDays.count)일 · \(allSets.count)세트\n연속 운동: \(streak)일")
                    .font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, 16).padding(.bottom, 24)
        }.background(HometsStyle.background.ignoresSafeArea())
    }
    var periodTitle: String {
        hometsDate(interval.start) + " – " + hometsDate(interval.end.addingTimeInterval(-1))
    }
}

private struct StatBox: View {
    let value: Int, label: String
    var body: some View { VStack(alignment: .leading, spacing: 8) { Text("\(value)").font(HometsStyle.font(24, .semibold)); Text(label).font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 11).padding(.vertical, 14).background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(HometsStyle.border)) }
}

private struct PeriodButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .semibold)).foregroundStyle(HometsStyle.text2).frame(width: 32, height: 32)
            .background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(HometsStyle.border))
    }
}

private struct DailyChart: View {
    let values: [(String, Int)]
    var maximum: CGFloat { CGFloat(max(values.map(\.1).max() ?? 0, 1)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("일별 반복 횟수")).font(HometsStyle.font(15, .semibold)).foregroundStyle(HometsStyle.text2)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(values.indices, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text("\(values[index].1)").font(HometsStyle.font(10)).foregroundStyle(HometsStyle.text2)
                        RoundedRectangle(cornerRadius: 3).fill(index == values.count - 1 ? HometsStyle.blue : HometsStyle.chartBar)
                            .frame(height: max(3, 82 * CGFloat(values[index].1) / maximum))
                        Text(values[index].0).font(HometsStyle.font(10)).foregroundStyle(HometsStyle.text2).lineLimit(1)
                    }.frame(maxWidth: .infinity)
                }
            }.frame(height: 118, alignment: .bottom)
        }.padding(16).background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(HometsStyle.border))
    }
}

private struct ExerciseStatsTable: View {
    let store: WorkoutStore
    let ids: [String]
    let days: [WorkoutDay]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("운동별 통계")).font(HometsStyle.font(15, .semibold)).foregroundStyle(HometsStyle.text2)
            ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) { Text(tr("운동")).frame(width: 110, alignment: .leading); Text(tr("세트")).frame(width: 30); Text(tr("합계")).frame(width: 36); Text(tr("최고")).frame(width: 32); Text(hometsIsEnglish ? "Avg reps/s" : "평균 회/초").frame(width: 58); Text(hometsIsEnglish ? "Avg kg" : "평균 kg").frame(width: 48); Text(hometsIsEnglish ? "Volume kg" : "총운동량 kg").frame(width: 68) }
                .font(HometsStyle.font(11, .semibold)).foregroundStyle(HometsStyle.text2)
            Divider().overlay(HometsStyle.border)
            ForEach(ids, id: \.self) { id in
                let exercise = store.exercises.first { $0.id == id }
                let allSets = days.flatMap { $0.sets[id] ?? [] }
                HStack(spacing: 8) {
                    Text(exercise?.localizedName ?? id).frame(width: 110, alignment: .leading).lineLimit(1)
                    Text("\(allSets.count)").frame(width: 30)
                    Text("\(allSets.reduce(0) { $0 + $1.value })").frame(width: 36)
                    Text("\(allSets.map(\.value).max() ?? 0)").frame(width: 32)
                    Text(exercise?.tracking == .cardio || allSets.isEmpty ? "—" : String(format: "%.1f", Double(allSets.reduce(0) { $0 + $1.value }) / Double(allSets.count))).frame(width: 58)
                    let recordedWeights = allSets.compactMap(\.weight)
                    Text(recordedWeights.isEmpty ? "—" : String(format: "%.1f", recordedWeights.reduce(0, +) / Double(recordedWeights.count))).frame(width: 48)
                    Text(exercise?.tracking != .repetitions || recordedWeights.isEmpty ? "—" : String(format: "%.0f", allSets.reduce(0.0) { $0 + Double($1.value) * ($1.weight ?? 0) })).frame(width: 68)
                }.font(HometsStyle.font(12)).foregroundStyle(HometsStyle.ink).padding(.vertical, 5)
            }
            }
            }
            Text(hometsIsEnglish ? "Swipe for averages. Average weight uses only sets with recorded weight. Volume = reps × kg; compare the same exercise. Missing weight is not zero. Timed averages are seconds. Cardio is excluded from rep averages." : "가로로 밀어 평균을 확인하세요. 평균 무게는 무게를 입력한 세트만 계산합니다. 총 운동량은 횟수×kg이며 같은 운동끼리 비교하세요. 미입력 무게는 0으로 계산하지 않습니다. 시간 운동의 평균 단위는 초이며 유산소는 평균 횟수에서 제외합니다.")
                .font(HometsStyle.font(12)).foregroundStyle(HometsStyle.text2)
            if ids.isEmpty { Text(tr("아직 저장된 운동 기록이 없습니다.")).font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2).padding(.vertical, 20) }
        }.padding(14).background(HometsStyle.surface, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(HometsStyle.border))
    }
}
