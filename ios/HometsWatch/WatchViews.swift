import SwiftUI

private func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
private func number(_ value: Double) -> String { value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value) }

struct WatchRootView: View {
    let store: WatchStore

    var body: some View {
        NavigationStack {
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
                ForEach(store.exercises) { exercise in
                    NavigationLink(value: exercise) { row(exercise) }
                        .listRowBackground(RoundedRectangle(cornerRadius: 16).fill(WatchStyle.surfaceRaised))
                }
            }
            .navigationTitle("HOMETS")
            .navigationDestination(for: Exercise.self) { ExerciseView(store: store, exercise: $0) }
            .containerBackground(WatchStyle.screenBackground, for: .navigation)
        }
        .tint(WatchStyle.blue)
    }

    private func row(_ exercise: Exercise) -> some View {
        let done = store.sets(for: exercise).count
        let planned = store.plannedSets(exercise)
        let complete = done >= planned
        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
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

private enum InputField { case weight, reps }

struct ExerciseView: View {
    let store: WatchStore
    let exercise: Exercise
    @State private var weight: Double
    @State private var reps: Int
    @State private var field: InputField = .reps
    @State private var crown: Double

    init(store: WatchStore, exercise: Exercise) {
        self.store = store
        self.exercise = exercise
        let target = store.defaultReps(for: exercise)
        _weight = State(initialValue: store.defaultWeight(for: exercise) ?? 0)
        _reps = State(initialValue: target)
        _crown = State(initialValue: Double(target))
    }

    private var usesWeight: Bool { store.supportsWeight(exercise) }
    private var isSeconds: Bool { exercise.tracking == .seconds }
    private var done: Int { store.sets(for: exercise).count }
    private var planned: Int { store.plannedSets(exercise) }
    private var repStep: Int { isSeconds ? 5 : 1 }
    private var activeField: InputField { usesWeight ? field : .reps }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let remaining = store.restRemaining { restView(remaining) }
                stepper(title: store.text("세트", "SETS"), value: "\(done)/\(planned)", selected: false, tint: done >= planned ? WatchStyle.mint : WatchStyle.ink,
                        minus: { store.changePlannedSets(-1, for: exercise) }, plus: { store.changePlannedSets(1, for: exercise) }, id: "sets")
                if usesWeight {
                    stepper(title: "KG", value: number(weight), selected: field == .weight,
                            minus: { weight = max(0, weight - 2.5); crown = weight }, plus: { weight = min(500, weight + 2.5); crown = weight },
                            select: { field = .weight }, id: "weight")
                }
                stepper(title: isSeconds ? store.text("초", "SEC") : store.text("횟수", "REPS"), value: "\(reps)", selected: activeField == .reps,
                        minus: { reps = max(1, reps - repStep); crown = Double(reps) }, plus: { reps = min(isSeconds ? 600 : 200, reps + repStep); crown = Double(reps) },
                        select: { field = .reps }, id: "reps")
                if store.restRemaining == nil {
                    Button { store.log(reps, weight: usesWeight ? weight : nil, for: exercise) } label: {
                        Text(done >= planned ? store.text("세트 추가", "Add set") : store.text("세트 완료", "Done"))
                    }
                    .buttonStyle(WatchPrimaryButtonStyle())
                    .padding(.top, 2)
                    .accessibilityIdentifier("logSet")
                }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(WatchStyle.screenBackground, for: .navigation)
        .focusable()
        .digitalCrownRotation($crown,
                              from: activeField == .weight ? 0 : 1,
                              through: activeField == .weight ? 500 : (isSeconds ? 600 : 200),
                              by: activeField == .weight ? 2.5 : Double(repStep),
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in
            if activeField == .weight { weight = value } else { reps = Int(value) }
        }
        .onChange(of: field) { _, _ in crown = activeField == .weight ? weight : Double(reps) }
    }

    private func stepper(title: String, value: String, selected: Bool, tint: Color = WatchStyle.ink,
                         minus: @escaping () -> Void, plus: @escaping () -> Void,
                         select: (() -> Void)? = nil, id: String) -> some View {
        HStack(spacing: 4) {
            Button(action: minus) { Image(systemName: "minus") }
                .buttonStyle(WatchRoundButtonStyle()).accessibilityIdentifier("\(id)-minus")
            VStack(spacing: -1) {
                Text(value).font(WatchStyle.font(26, .bold)).monospacedDigit().minimumScaleFactor(0.6).foregroundStyle(tint)
                Text(title).font(WatchStyle.font(10, .semibold)).tracking(0.8).foregroundStyle(selected ? WatchStyle.blue : WatchStyle.text3)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(selected ? WatchStyle.selected : Color.clear, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? WatchStyle.blue.opacity(0.7) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { select?() }
            Button(action: plus) { Image(systemName: "plus") }
                .buttonStyle(WatchRoundButtonStyle()).accessibilityIdentifier("\(id)-plus")
        }
    }

    private func restView(_ remaining: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(WatchStyle.border.opacity(0.7), lineWidth: 7)
                Circle().trim(from: 0, to: min(1, Double(remaining) / Double(max(store.payload.restSeconds, remaining))))
                    .stroke(WatchStyle.ringGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: remaining)
                VStack(spacing: -2) {
                    Text(clock(remaining)).font(WatchStyle.font(30, .bold)).monospacedDigit().foregroundStyle(WatchStyle.ink)
                        .accessibilityIdentifier("restTime")
                    Text(store.text("휴식", "REST")).font(WatchStyle.font(10, .semibold)).tracking(0.8).foregroundStyle(WatchStyle.text3)
                }
            }
            .frame(width: 104, height: 104)
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
