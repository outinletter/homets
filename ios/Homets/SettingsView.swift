import SwiftUI
import UIKit

struct SettingsView: View {
    let store: WorkoutStore
    let purchases: PurchaseService
    let resetToken: UUID
    let onDirtyChange: (Bool) -> Void
    @State private var draft: AppSettings
    @State private var search = ""
    @AppStorage("homets.haptics") private var haptics = true
    @AppStorage("homets.language") private var language = "ko"
    @State private var category = "전체"
    @State private var showPremium = false
    @State private var showDiscard = false
    @State private var showAddExercise = false
    @State private var exportingBackup = false
    @State private var importingBackup = false
    @State private var backupMessage: String?
    @State private var pendingRestore: StoredData?
    @State private var confirmRestore = false
    @Environment(\.dismiss) private var dismiss

    init(store: WorkoutStore, purchases: PurchaseService, resetToken: UUID, onDirtyChange: @escaping (Bool) -> Void) {
        self.store = store; self.purchases = purchases; self.resetToken = resetToken; self.onDirtyChange = onDirtyChange
        _draft = State(initialValue: store.data.settings)
    }

    private let categories = ["전체", "운동기구", "맨몸 운동", "프리웨이트", "유산소"]
    private var changed: Bool { draft != store.data.settings }
    private var filtered: [Exercise] {
        store.exercises.filter { exercise in
            (category == "전체" || exercise.group.contains(category)) &&
            (search.isEmpty || exercise.name.localizedCaseInsensitiveContains(search) || exercise.group.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(HometsStyle.strongBorder).frame(width: 38, height: 5).padding(.top, 11).padding(.bottom, 25)
            ScrollView {
                VStack(spacing: 0) {
                    header
                    Divider().overlay(HometsStyle.border)
                    preferences
                    Divider().overlay(HometsStyle.border)
                    libraryTools
                    Divider().overlay(HometsStyle.border)
                    notificationSection
                    Divider().overlay(HometsStyle.border)
                    addExerciseSection
                    exerciseList
                }
            }
            footer
        }
        .background(HometsStyle.surface)
        .foregroundStyle(HometsStyle.ink)
        .interactiveDismissDisabled(changed)
        .confirmationDialog(tr("저장하지 않은 변경사항을 취소할까요?"), isPresented: $showDiscard) {
            Button(tr("변경사항 취소"), role: .destructive) { draft = store.data.settings; dismiss() }
            Button(tr("계속 편집"), role: .cancel) {}
        }
        .confirmationDialog(language == "en" ? "Replace all current records with this backup?" : "현재 모든 기록을 이 백업으로 교체할까요?", isPresented: $confirmRestore) {
            Button(language == "en" ? "Replace records" : "기록 교체", role: .destructive) {
                guard let restored = pendingRestore else { return }
                if let safety = try? JSONEncoder().encode(store.data) { UserDefaults.standard.set(safety, forKey: "homets.preImportBackup") }
                store.replace(with: restored); draft = restored.settings; pendingRestore = nil
                backupMessage = language == "en" ? "Backup restored." : "백업을 복원했습니다."
            }
            Button(tr("취소"), role: .cancel) { pendingRestore = nil }
        }
        .sheet(isPresented: $showPremium) { PremiumView(purchases: purchases) }
        .sheet(isPresented: $showAddExercise) { AddExerciseView(store: store) }
        .alert("HOMETS", isPresented: Binding(get: { purchases.errorMessage != nil }, set: { if !$0 { purchases.errorMessage = nil } })) {
            Button(tr("확인")) { purchases.errorMessage = nil }
        } message: { Text(purchases.errorMessage ?? "") }
        .alert("HOMETS", isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
            Button(tr("확인")) { backupMessage = nil }
        } message: { Text(backupMessage ?? "") }
        .fileExporter(isPresented: $exportingBackup, document: HometsBackupDocument(data: store.data), contentType: .json, defaultFilename: "HOMETS-backup") { result in
            if case .failure(let error) = result { backupMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let raw = try Data(contentsOf: url); guard raw.count <= 10 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                pendingRestore = try JSONDecoder().decode(StoredData.self, from: raw); confirmRestore = true
            } catch { backupMessage = error.localizedDescription }
        }
        .onChange(of: changed) { _, value in onDirtyChange(value) }
        .onChange(of: resetToken) { _, _ in draft = store.data.settings }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(tr("환경설정 · 운동 루틴")).font(HometsStyle.font(24, .semibold))
            Text(tr("기록할 운동을 모두 확인하고 선택하세요.")).font(HometsStyle.font(16)).foregroundStyle(HometsStyle.text2)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 22)
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(tr("Language / 언어")).font(HometsStyle.font(16))
                Spacer()
                Menu(language == "en" ? "English" : "한국어") {
                    Button("English") { language = "en" }
                    Button("한국어") { language = "ko" }
                }
                    .font(HometsStyle.font(16)).foregroundStyle(HometsStyle.ink)
                    .padding(.horizontal, 13).frame(height: 38)
                    .background(HometsStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(HometsStyle.strongBorder))
            }
            Toggle(tr("화면 자동 꺼짐 방지"), isOn: $draft.keepAwake).tint(HometsStyle.blue)
            Toggle(tr("휴식 종료 소리 알림"), isOn: $draft.timerSound).tint(HometsStyle.blue)
            Stepper(language == "en" ? "Default rest  \(draft.defaultRestSeconds)s" : "기본 휴식 시간  \(draft.defaultRestSeconds)초", value: $draft.defaultRestSeconds, in: 10...3600, step: 10)
            Text(tr("목표 횟수는 최근 3세트의 평균입니다."))
                .font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).fixedSize(horizontal: false, vertical: true)
        }.font(HometsStyle.font(16)).padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var libraryTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(HometsStyle.text3)
                TextField(tr("운동 또는 근육 검색"), text: $search).font(HometsStyle.font(16))
            }.padding(.horizontal, 12).frame(height: 44).background(HometsStyle.input, in: RoundedRectangle(cornerRadius: 11))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { item in
                        Button(tr(item)) { category = item }.font(HometsStyle.font(14, item == category ? .semibold : .regular))
                            .foregroundStyle(item == category ? HometsStyle.blue : HometsStyle.text2)
                            .padding(.horizontal, 11).frame(height: 35)
                            .background(item == category ? HometsStyle.selected : HometsStyle.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(item == category ? HometsStyle.blue.opacity(0.55) : HometsStyle.border))
                    }
                }
            }
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 17) {
            Toggle(tr("횟수 버튼 진동 / Rep haptics"), isOn: $haptics).tint(HometsStyle.blue)
            Text(tr("화면이 꺼져 있어도 휴식 알림을 받으려면 iPhone 설정에서 HOMETS 알림과 사운드를 허용하세요."))
                .font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).fixedSize(horizontal: false, vertical: true)
            Button(tr("알림 설정 / Notification settings")) {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
            }.font(HometsStyle.font(16, .semibold)).foregroundStyle(HometsStyle.blue).frame(maxWidth: .infinity, minHeight: 46)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(HometsStyle.border))
        }.font(HometsStyle.font(16)).padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var addExerciseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("운동 직접 추가 / Add exercise")).font(HometsStyle.font(16, .semibold))
            Button { showAddExercise = true } label: {
                HStack { Text(tr("운동 이름 / 운동 name")).foregroundStyle(HometsStyle.text3); Spacer(); Image(systemName: "plus") }
                    .font(HometsStyle.font(16)).padding(.horizontal, 12).frame(height: 46)
                    .background(HometsStyle.background, in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(HometsStyle.border))
            }.buttonStyle(.plain)
        }.padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var exerciseList: some View {
        LazyVStack(spacing: 0) {
            ForEach(filtered) { exercise in
                HStack(spacing: 18) {
                    Toggle(exercise.localizedName, isOn: selectionBinding(exercise.id)).labelsHidden().tint(HometsStyle.blue)
                        .scaleEffect(0.72).frame(width: 38, height: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.localizedName).font(HometsStyle.font(16, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        Text(language == "en" ? "\(exercise.localizedGroup) · \(exercise.defaultTarget)\(exercise.tracking == .seconds ? "s" : " reps") per set" : "\(exercise.localizedGroup) · \(exercise.defaultTarget)\(exercise.tracking == .seconds ? "초" : "회") / 세트").font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer()
                }.padding(.vertical, 12).overlay(alignment: .bottom) { Rectangle().fill(HometsStyle.border).frame(height: 1) }
            }
        }.padding(.horizontal, 20)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language == "en" ? "\(draft.activeExerciseIDs.count) selected · \(store.exercises.count) available" : "\(draft.activeExerciseIDs.count)개 선택 · 전체 \(store.exercises.count)개").font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2)
            Text(tr(purchases.isPremium ? "Premium · 운동 종류 제한 없음" : "무료는 10가지 운동까지 선택할 수 있습니다."))
                .font(HometsStyle.font(13)).foregroundStyle(HometsStyle.text2)
            if !purchases.isPremium {
                Button(tr("Premium 구매")) { showPremium = true }
                    .font(HometsStyle.font(14, .semibold)).foregroundStyle(HometsStyle.blue)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(HometsStyle.border))
            }
            HStack(spacing: 8) {
                Button(tr("JSON 백업 내보내기")) { exportingBackup = true }
                Button(tr("JSON 백업 가져오기")) { importingBackup = true }
            }
            .font(HometsStyle.font(13, .semibold)).foregroundStyle(HometsStyle.blue)
            .frame(maxWidth: .infinity, minHeight: 42)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(HometsStyle.border))
            if let safety = UserDefaults.standard.data(forKey: "homets.preImportBackup") {
                Button(language == "en" ? "Restore pre-import backup" : "가져오기 전 백업 복원") {
                    if let restored = try? JSONDecoder().decode(StoredData.self, from: safety) { pendingRestore = restored; confirmRestore = true }
                }
                .font(HometsStyle.font(13, .semibold)).foregroundStyle(HometsStyle.blue)
            }
            Link(tr("개인정보 처리방침"), destination: URL(string: "https://outinletter.github.io/privacy-policy/homets.html")!)
                .font(HometsStyle.font(14)).foregroundStyle(HometsStyle.blue)
            HStack(spacing: 8) {
                Button(tr("취소")) { changed ? (showDiscard = true) : dismiss() }
                    .foregroundStyle(HometsStyle.ink).frame(maxWidth: .infinity, minHeight: 50).background(HometsStyle.input, in: RoundedRectangle(cornerRadius: 12))
                Button(tr("루틴 적용")) { store.apply(settings: draft); onDirtyChange(false); dismiss() }
                    .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 50).background(HometsStyle.blue, in: RoundedRectangle(cornerRadius: 12))
            }.font(HometsStyle.font(16, .semibold))
        }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8).background(HometsStyle.surfaceRaised).overlay(alignment: .top) { Rectangle().fill(HometsStyle.border).frame(height: 1) }
    }

    private func selectionBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { draft.activeExerciseIDs.contains(id) }, set: { enabled in
            if enabled {
                guard purchases.isPremium || draft.activeExerciseIDs.count < 10 else { showPremium = true; return }
                draft.activeExerciseIDs.append(id)
            } else { draft.activeExerciseIDs.removeAll { $0 == id } }
        })
    }
}

struct PremiumView: View {
    let purchases: PurchaseService
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { VStack(spacing: 22) {
            Image(systemName: "crown.fill").font(.system(size: 54)).foregroundStyle(.yellow)
            Text("HOMETS Premium").font(HometsStyle.font(30, .bold))
            Text(tr("10가지를 초과해 원하는 운동을 제한 없이 선택하세요.")).multilineTextAlignment(.center).foregroundStyle(HometsStyle.text2)
            VStack(alignment: .leading, spacing: 8) {
                Label(tr("운동 종목 무제한 선택"), systemImage: "checkmark.circle.fill")
                Label(tr("전체 운동 기록 및 통계 이용"), systemImage: "checkmark.circle.fill")
                Label(tr("운동별 개인 기록과 최근 4주 추세"), systemImage: "checkmark.circle.fill")
            }.font(HometsStyle.font(14)).foregroundStyle(HometsStyle.text2).frame(maxWidth: .infinity, alignment: .leading)
            Button(UserDefaults.standard.string(forKey: "homets.language") == "en" ? "Premium \(purchases.priceText) one-time purchase" : "Premium \(purchases.priceText) 1회 구매") { Task { await purchases.purchase(); if purchases.isPremium { dismiss() } } }.buttonStyle(.borderedProminent).disabled(purchases.isBusy)
            Text(tr("Premium은 자동 갱신되지 않는 1회 구매이며, 운동 종목 무제한 선택과 전체 통계를 계속 이용할 수 있습니다."))
                .font(HometsStyle.font(12)).foregroundStyle(HometsStyle.text2).multilineTextAlignment(.center)
            Button(tr("구매 복원")) { Task { await purchases.restore(); if purchases.isPremium { dismiss() } } }.disabled(purchases.isBusy)
            HStack(spacing: 18) {
                Link(tr("개인정보 처리방침"), destination: URL(string: "https://outinletter.github.io/privacy-policy/homets.html")!)
                Link(tr("이용약관"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }.font(HometsStyle.font(12, .semibold)).foregroundStyle(HometsStyle.blue)
            Spacer()
        }.padding(24).toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("닫기")) { dismiss() } } } }
    }
}

private struct AddExerciseView: View {
    let store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var tracking = Exercise.Tracking.repetitions
    var body: some View {
        NavigationStack { Form {
            TextField(tr("운동 이름"), text: $name)
            Picker(tr("기록 방식"), selection: $tracking) { Text(tr("횟수")).tag(Exercise.Tracking.repetitions); Text(tr("시간(초)")).tag(Exercise.Tracking.seconds); Text(tr("거리·시간")).tag(Exercise.Tracking.cardio) }
        }.navigationTitle(tr("운동 추가")).toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(tr("취소")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button(tr("추가")) { store.addExercise(name: name.trimmingCharacters(in: .whitespacesAndNewlines), tracking: tracking); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        } }
    }
}
