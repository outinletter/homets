import SwiftUI

private func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
private func number(_ value: Double) -> String { value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value) }

struct WatchRootView: View {
    let store: WatchStore
    @State private var path: [Exercise] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let remaining = store.restRemaining {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                        Text(store.text("휴식", "Rest")).font(WatchStyle.font(14, .semibold))
                        Spacer(minLength: 0)
                        Text(clock(remaining)).font(WatchStyle.font(16, .bold)).monospacedDigit()
                    }
                    .foregroundStyle(WatchStyle.mint)
                    .padding(.horizontal, 4)
                    .listRowBackground(RoundedRectangle(cornerRadius: 16).fill(WatchStyle.mintFill))
                    .accessibilityIdentifier("restBanner")
                }
                ForEach(store.orderedExercises) { exercise in
                    NavigationLink(value: exercise) { row(exercise) }
                        .listRowBackground(RoundedRectangle(cornerRadius: 16).fill(WatchStyle.surfaceRaised))
                }
            }
            .navigationTitle("HOMETS")
            .navigationDestination(for: Exercise.self) { ExerciseView(store: store, exercise: $0) }
            .containerBackground(WatchStyle.screenBackground, for: .navigation)
        }
        .tint(WatchStyle.blue)
        // 설정한 세트를 모두 마치면 자동으로 전체 목록으로 돌아간다.
        .onChange(of: store.completionTick) { _, _ in path.removeAll() }
    }

    private func row(_ exercise: Exercise) -> some View {
        let done = store.sets(for: exercise).count
        let planned = store.plannedSets(exercise)
        let complete = done >= planned
        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.name(exercise))
                    .font(WatchStyle.font(15, .semibold))
                    .foregroundStyle(WatchStyle.ink)
                    .lineLimit(2).minimumScaleFactor(0.85)
                HStack(spacing: 3) {
                    ForEach(0..<min(planned, 10), id: \.self) { index in
                        Circle()
                            .fill(index < done ? (complete ? WatchStyle.mint : WatchStyle.blue) : Color.clear)
                            .overlay(Circle().stroke(index < done ? Color.clear : WatchStyle.strongDot, lineWidth: 1))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            Spacer(minLength: 0)
            if complete {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(WatchStyle.mint)
            } else {
                Text("\(done)/\(planned)").font(WatchStyle.font(13, .semibold)).monospacedDigit().foregroundStyle(WatchStyle.text2)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension WatchStyle {
    static let strongDot = Color(hex: 0x46606D)
}

private enum InputField { case sets, weight, reps }

struct ExerciseView: View {
    let store: WatchStore
    let exercise: Exercise
    @State private var weight: Double
    @State private var reps: Int
    @State private var field: InputField
    @State private var crown: Double
    @FocusState private var crownFocused: Bool

    init(store: WatchStore, exercise: Exercise) {
        self.store = store
        self.exercise = exercise
        let target = store.defaultReps(for: exercise)
        let startWeight = store.defaultWeight(for: exercise) ?? 0
        let weighted = store.supportsWeight(exercise)
        let step = exercise.tracking == .seconds ? 5 : 1
        _weight = State(initialValue: startWeight)
        _reps = State(initialValue: target)
        _field = State(initialValue: weighted ? .weight : .reps)
        _crown = State(initialValue: weighted ? startWeight : Double(target) / Double(step))
    }

    private var usesWeight: Bool { store.supportsWeight(exercise) }
    private var isSeconds: Bool { exercise.tracking == .seconds }
    private var done: Int { store.sets(for: exercise).count }
    private var planned: Int { store.plannedSets(exercise) }
    private var repStep: Int { isSeconds ? 5 : 1 }
    private var maxReps: Int { isSeconds ? 600 : 200 }

    /// 크라운 눈금 ↔ 값 변환. 세 칸이 같은 눈금 범위(0...600)를 쓰므로 칸을 바꿔도 값이 섞이지 않는다.
    private func ticks(for field: InputField) -> Double {
        switch field {
        case .sets: Double(planned)
        case .weight: weight
        case .reps: Double(reps) / Double(repStep)
        }
    }

    private func apply(_ value: Double) {
        guard abs(value - ticks(for: field)) > 0.001 else { return }
        switch field {
        case .sets:
            let next = min(10, max(max(1, done), Int(value.rounded())))
            store.changePlannedSets(next - planned, for: exercise)
        case .weight:
            weight = min(500, max(0, value.rounded()))
        case .reps:
            reps = min(maxReps, max(1, Int(value.rounded()) * repStep))
        }
        let corrected = ticks(for: field)
        if abs(corrected - value) > 0.001 { crown = corrected }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                if let remaining = store.restRemaining {
                    restView(remaining)
                } else if let left = store.timedRemaining, store.timedExerciseID == exercise.id {
                    timedView(left)
                } else {
                    HStack(spacing: 6) {
                        tile(.sets, title: store.text("세트", "SETS"), value: "\(done)/\(planned)", id: "tile-sets", tint: done >= planned ? WatchStyle.mint : WatchStyle.ink)
                        if usesWeight { tile(.weight, title: "KG", value: number(weight), id: "tile-weight") }
                        tile(.reps, title: isSeconds ? store.text("초", "SEC") : store.text("횟수", "REPS"), value: "\(reps)", id: "tile-reps")
                    }
                    if field == .sets {
                        HStack(spacing: 8) {
                            Button { store.changePlannedSets(-1, for: exercise); crown = ticks(for: .sets) } label: { Image(systemName: "minus") }
                                .buttonStyle(WatchGhostButtonStyle())
                                .disabled(planned <= max(1, done))
                                .accessibilityLabel(store.text("세트 삭제", "Remove set")).accessibilityIdentifier("plannedMinus")
                            Text(store.text("세트 수", "Sets")).font(WatchStyle.font(10, .semibold)).foregroundStyle(WatchStyle.text3)
                            Button { store.changePlannedSets(1, for: exercise); crown = ticks(for: .sets) } label: { Image(systemName: "plus") }
                                .buttonStyle(WatchGhostButtonStyle())
                                .disabled(planned >= 10)
                                .accessibilityLabel(store.text("세트 추가", "Add set")).accessibilityIdentifier("plannedPlus")
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "digitalcrown.horizontal.arrow.clockwise").font(.system(size: 10))
                            Text(store.text("탭해서 선택 · 크라운으로 조절", "Tap to select · Crown to adjust")).font(WatchStyle.font(10, .semibold))
                        }
                        .foregroundStyle(WatchStyle.text3)
                    }
                    HStack(spacing: 6) {
                        // 세트 삭제(−): 늘린 계획 세트를 먼저 줄이고, 기본 세트 수에 닿으면 가장 최근 기록부터 지운다., 세트 완료가 주 버튼이다.
                        Button { store.removeSet(for: exercise) } label: { Image(systemName: "minus") }
                            .buttonStyle(WatchGhostButtonStyle(tint: WatchStyle.lavender))
                            .frame(width: 46)
                            .disabled(done == 0 && planned <= store.defaultSetCount)
                            .opacity(done == 0 && planned <= store.defaultSetCount ? 0.35 : 1)
                            .accessibilityLabel(store.text("세트 삭제", "Remove set"))
                            .accessibilityIdentifier("undoSet")
                        Button {
                            if isSeconds { store.startTimed(exercise, seconds: reps) }
                            else { store.log(reps, weight: usesWeight ? weight : nil, for: exercise) }
                        } label: {
                            Text(isSeconds ? store.text("시작", "Start") : store.text("세트 완료", "Done"))
                        }
                        .buttonStyle(WatchPrimaryButtonStyle())
                        .disabled(isSeconds && store.timedExerciseID != nil)
                        .accessibilityIdentifier("logSet")
                        // 세트 추가(계획 세트 수 +1)는 기호 버튼으로 둔다.
                        Button { store.changePlannedSets(1, for: exercise); if field == .sets { crown = ticks(for: .sets) } } label: { Image(systemName: "plus") }
                            .buttonStyle(WatchGhostButtonStyle())
                            .frame(width: 46)
                            .disabled(planned >= 10)
                            .opacity(planned >= 10 ? 0.35 : 1)
                            .accessibilityLabel(store.text("세트 추가", "Add set"))
                            .accessibilityIdentifier("addSet")
                    }
                }
            }
            .padding(.horizontal, 2)
            Spacer(minLength: 0)
        }
        .navigationTitle(store.name(exercise))
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(WatchStyle.screenBackground, for: .navigation)
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation($crown, from: 0, through: 600, by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in apply(value) }
        .onChange(of: field) { _, _ in crown = ticks(for: field); crownFocused = true }
        .onChange(of: store.restRemaining) { _, _ in crownFocused = true }
        .onChange(of: store.timedRemaining) { _, _ in crownFocused = true }
        .onAppear { crownFocused = true }
    }

    private func tile(_ target: InputField, title: String, value: String, id: String, tint: Color = WatchStyle.ink) -> some View {
        let selected = field == target
        return Button { field = target; crownFocused = true } label: {
            VStack(spacing: 2) {
                Text(title).font(WatchStyle.font(10, .semibold)).tracking(0.8).foregroundStyle(selected ? WatchStyle.blue : WatchStyle.text3)
                Text(value).font(WatchStyle.font(28, .bold)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(selected ? WatchStyle.selected : WatchStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? WatchStyle.blue : WatchStyle.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityIdentifier(id)
    }

    private func timedView(_ remaining: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(WatchStyle.border.opacity(0.7), lineWidth: 7)
                Circle().trim(from: 0, to: min(1, Double(remaining) / Double(max(store.timedTotal, remaining))))
                    .stroke(WatchStyle.ringGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text(clock(remaining)).font(WatchStyle.font(30, .bold)).monospacedDigit().foregroundStyle(WatchStyle.ink)
                        .accessibilityIdentifier("timedTime")
                    Text(store.text("\(done + 1)세트 진행 중", "SET \(done + 1)")).font(WatchStyle.font(10, .semibold)).tracking(0.8).foregroundStyle(WatchStyle.text3)
                }
            }
            .frame(width: 88, height: 88)
            .padding(.top, 26)
            Button(store.text("취소", "Cancel")) { store.cancelTimed() }
                .buttonStyle(WatchGhostButtonStyle(tint: WatchStyle.lavender))
                .accessibilityIdentifier("cancelTimed")
        }
        .padding(.bottom, 4)
    }

    private func restView(_ remaining: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(WatchStyle.border.opacity(0.7), lineWidth: 7)
                Circle().trim(from: 0, to: min(1, Double(remaining) / Double(max(store.payload.restSeconds, remaining))))
                    .stroke(WatchStyle.ringGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text(clock(remaining)).font(WatchStyle.font(30, .bold)).monospacedDigit().foregroundStyle(WatchStyle.ink)
                        .accessibilityIdentifier("restTime")
                    Text(store.text("휴식", "REST")).font(WatchStyle.font(10, .semibold)).tracking(0.8).foregroundStyle(WatchStyle.text3)
                }
            }
            .frame(width: 88, height: 88)
            .padding(.top, 26)
            HStack(spacing: 6) {
                Button("−10") { store.adjustRest(-10) }
                Button("+10") { store.adjustRest(10) }
            }
            .buttonStyle(WatchGhostButtonStyle())
            Button(store.text("건너뛰기", "Skip")) { store.stopRest() }
                .buttonStyle(WatchGhostButtonStyle(tint: WatchStyle.lavender))
                .accessibilityIdentifier("skipRest")
        }
        .padding(.bottom, 4)
    }
}
