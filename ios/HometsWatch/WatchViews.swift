import SwiftUI

private func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
private func number(_ value: Double) -> String { value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value) }

struct WatchRootView: View {
    let store: WatchStore

    var body: some View {
        NavigationStack {
            List {
                if let remaining = store.restRemaining {
                    Label(store.text("휴식 \(clock(remaining))", "Rest \(clock(remaining))"), systemImage: "timer")
                        .font(.headline).foregroundStyle(.orange)
                        .accessibilityIdentifier("restBanner")
                }
                ForEach(store.exercises) { exercise in
                    NavigationLink(value: exercise) {
                        let done = store.sets(for: exercise).count
                        HStack {
                            Text(exercise.name).lineLimit(2)
                            Spacer(minLength: 4)
                            Text("\(done)/\(store.plannedSets(exercise))")
                                .font(.footnote).monospacedDigit()
                                .foregroundStyle(done >= store.plannedSets(exercise) ? .green : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("HOMETS")
            .navigationDestination(for: Exercise.self) { ExerciseView(store: store, exercise: $0) }
        }
    }
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
            VStack(spacing: 8) {
                stepper(title: store.text("세트", "Sets"), value: "\(done)/\(planned)", selected: false,
                        minus: { store.changePlannedSets(-1, for: exercise) }, plus: { store.changePlannedSets(1, for: exercise) }, id: "sets")
                if usesWeight {
                    stepper(title: "kg", value: number(weight), selected: field == .weight,
                            minus: { weight = max(0, weight - 2.5); crown = weight }, plus: { weight = min(500, weight + 2.5); crown = weight },
                            select: { field = .weight }, id: "weight")
                }
                stepper(title: isSeconds ? store.text("초", "sec") : store.text("횟수", "Reps"), value: "\(reps)", selected: activeField == .reps,
                        minus: { reps = max(1, reps - repStep); crown = Double(reps) }, plus: { reps = min(isSeconds ? 600 : 200, reps + repStep); crown = Double(reps) },
                        select: { field = .reps }, id: "reps")
                if let remaining = store.restRemaining {
                    restView(remaining)
                } else {
                    Button { store.log(reps, weight: usesWeight ? weight : nil, for: exercise) } label: {
                        Text(done >= planned ? store.text("세트 추가", "Add set") : store.text("세트 완료", "Done"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.blue)
                    .accessibilityIdentifier("logSet")
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private func stepper(title: String, value: String, selected: Bool, minus: @escaping () -> Void, plus: @escaping () -> Void,
                         select: (() -> Void)? = nil, id: String) -> some View {
        HStack(spacing: 6) {
            Button(action: minus) { Image(systemName: "minus") }.frame(width: 38).accessibilityIdentifier("\(id)-minus")
            VStack(spacing: 0) {
                Text(value).font(.title3.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.7)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(selected ? Color.blue.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture { select?() }
            Button(action: plus) { Image(systemName: "plus") }.frame(width: 38).accessibilityIdentifier("\(id)-plus")
        }
        .buttonStyle(.bordered)
    }

    private func restView(_ remaining: Int) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.orange.opacity(0.25), lineWidth: 6)
                Circle().trim(from: 0, to: min(1, Double(remaining) / Double(max(store.payload.restSeconds, remaining))))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(clock(remaining)).font(.title2.weight(.bold)).monospacedDigit().accessibilityIdentifier("restTime")
                    Text(store.text("휴식", "Rest")).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            HStack {
                Button("-10") { store.adjustRest(-10) }
                Button("+10") { store.adjustRest(10) }
            }
            .buttonStyle(.bordered)
            Button(store.text("건너뛰기", "Skip")) { store.stopRest() }
                .buttonStyle(.bordered).tint(.orange)
                .accessibilityIdentifier("skipRest")
        }
    }
}
