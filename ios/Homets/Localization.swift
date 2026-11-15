import SwiftUI

private struct HometsLanguageKey: EnvironmentKey {
    static let defaultValue = "ko"
}

extension EnvironmentValues {
    var hometsLanguage: String {
        get { self[HometsLanguageKey.self] }
        set { self[HometsLanguageKey.self] = newValue }
    }
}

func tr(_ korean: String) -> String {
    guard UserDefaults.standard.string(forKey: "homets.language") == "en" else { return korean }
    return HometsEnglish.text[korean] ?? korean
}

var hometsIsEnglish: Bool { UserDefaults.standard.string(forKey: "homets.language") == "en" }

func hometsDate(_ date: Date, dateStyle: DateFormatter.Style = .medium) -> String {
    let formatter = DateFormatter(); formatter.locale = Locale(identifier: hometsIsEnglish ? "en_US" : "ko_KR"); formatter.dateStyle = dateStyle
    return formatter.string(from: date)
}

enum HometsEnglish {
    static let text: [String: String] = [
        "Premium · 개인 기록 및 4주 추세": "Premium · Personal bests & 4-week trends",
        "운동별 개인 기록과 최근 4주 추세": "Personal bests and 4-week trends by exercise",
        "운동 세트를 저장하면 개인 기록과 추세가 표시됩니다.": "Log a set to see personal bests and trends.",
        "전체 기간 개인 기록": "All-time personal best",
        "최근 28일 · 7일 단위": "Last 28 days · 7-day intervals",
        "운동": "Workout", "기록": "History", "통계": "Stats",
        "운동 LOG": "WORKOUT LOG", "환경설정 · 운동 루틴": "Your routine",
        "기록할 운동을 모두 확인하고 선택하세요.": "Choose the exercises you want to log.",
        "Language / 언어": "Language", "한국어": "Korean",
        "화면 자동 꺼짐 방지": "Keep screen awake", "휴식 종료 소리 알림": "Rest timer sound",
        "목표 횟수는 최근 3세트의 평균입니다.": "Targets use your latest 3 saved sets.",
        "순서 편집": "Edit order", "오른쪽 핸들을 끌어 순서를 바꾸세요. 완료한 운동은 목록 아래로 내려갑니다.": "Drag the handles to reorder. Completed exercises move to the bottom.", "다크 모드": "Dark mode", "설정": "Settings", "정렬": "Sort", "기본 (미완료 우선)": "Default (unfinished first)", "이름순": "By name", "분류순": "By category",
        "늘리기": "Increase", "줄이기": "Decrease", "세트 취소": "Undo set", "기록 펼치기": "Expand day",
        "분석 지표": "Insights", "총 볼륨 (무게×횟수)": "Total volume (weight × reps)", "이전 기간 대비": "vs. previous period",
        "비교할 이전 기간 기록이 부족합니다": "Not enough previous-period data to compare",
        "추정 1RM (Epley, 1~10회 세트)": "Estimated 1RM (Epley, sets of 1–10 reps)",
        "무게와 횟수(1~10회)를 입력하면 표시됩니다": "Log weight and reps (1–10) to see estimates",
        "분류별 세트 수": "Sets by category", "최근 7일 일평균 반복": "7-day average reps per day",
        "참고용 추정치이며 의학적 조언이 아닙니다. 같은 운동끼리 비교하세요.": "Estimates are for reference only, not medical advice. Compare the same exercise.",
        "최근": "Recent", "최근 기록 없음": "No recent record",
        "운동 또는 근육 검색": "Search exercises or muscle groups", "전체": "All",
        "운동기구": "Machines", "맨몸 운동": "Bodyweight", "프리웨이트": "Free weights", "유산소": "Cardio",
        "횟수 버튼 진동 / Rep haptics": "Rep button haptics",
        "화면이 꺼져 있어도 휴식 알림을 받으려면 iPhone 설정에서 HOMETS 알림과 사운드를 허용하세요.": "Allow HOMETS notifications and sounds in iPhone Settings to receive rest alerts while the screen is off.",
        "알림 설정 / Notification settings": "Notification settings", "운동 직접 추가 / Add exercise": "Add exercise",
        "운동 이름 / 운동 name": "Exercise name", "취소": "Cancel", "루틴 적용": "Apply routine",
        "Premium · 운동 종류 제한 없음": "Premium · Unlimited exercises", "무료는 10가지 운동까지 선택할 수 있습니다.": "Free users can select up to 10 exercises.",
        "저장하지 않은 변경사항을 취소할까요?": "Discard unsaved changes?", "변경사항 취소": "Discard changes", "계속 편집": "Keep editing", "확인": "OK",
        "10가지를 초과해 원하는 운동을 제한 없이 선택하세요.": "Select more than 10 exercises with no limit.", "구매 복원": "Restore purchases", "닫기": "Close",
        "운동 종목 무제한 선택": "Select unlimited exercises", "전체 운동 기록 및 통계 이용": "Access all workout history and statistics", "새 운동 종목과 통계 기능 지속 업데이트": "Ongoing exercise and statistics updates", "Premium은 자동 갱신되지 않는 1회 구매이며, 운동 종목 무제한 선택과 전체 통계를 계속 이용할 수 있습니다.": "Premium is a non-renewing one-time purchase that provides ongoing access to unlimited exercise selection and full statistics.",
        "구독은 1년마다 자동 갱신됩니다. 현재 기간 종료 최소 24시간 전에 취소하지 않으면 App Store 계정으로 결제됩니다. 구독은 App Store 계정 설정에서 관리하거나 취소할 수 있습니다.": "The subscription renews annually unless canceled at least 24 hours before the current period ends. Payment is charged to your App Store account. Manage or cancel it in your App Store account settings.", "이용약관": "Terms of Use",
        "운동 이름": "Exercise name", "기록 방식": "Tracking", "횟수": "Reps", "시간(초)": "Seconds", "거리·시간": "Distance & time", "운동 추가": "Add exercise", "추가": "Add",
        "반복 횟수를 조절하고 저장하세요. 각 운동은 마지막 입력값 또는 저장된 횟수를 기억합니다.": "Adjust reps, then save. Each exercise remembers your latest input or saved reps.",
        "운동 목록": "EXERCISE LOG", "운동 진행 중": "SESSION IN PROGRESS", "운동 준비 완료": "READY TO TRAIN", "오늘의 운동": "Today’s workout", "완료": "COMPLETE",
        "완료 운동": "Exercises done", "저장 세트": "Sets logged", "총 반복 횟수": "Total reps",
        "운동별 세트 수": "Sets per exercise", "저장한 세트는 유지됩니다.": "Logged sets stay saved.",
        "목표 횟수": "REP TARGET", "목표 시간": "TIME TARGET", "목표 무게": "WEIGHT TARGET", "저장": "Save", "시작": "Start", "다음 세트 시작": "Start next set", "최근 기록: 저장된 기록 없음": "Recent: No saved records",
        "+ 세트 추가": "+ Add set", "− 세트 삭제": "− Remove set", "횟수 초기화": "Reset reps",
        "휴식 타이머": "Rest timer", "휴식 종료": "Skip rest", "아직 저장된 운동 기록이 없습니다.": "No workouts yet. Start logging today!",
        "일간": "Day", "주간": "Week", "월간": "Month", "통계 기간": "Statistics period",
        "운동 일수": "Days trained", "운동 종류": "Exercises", "선택한 기간의 운동 기록": "Workout records for this period",
        "일별 반복 횟수": "Daily reps", "운동별 통계": "Exercise breakdown", "세트": "Sets", "합계": "Total", "최고": "Best",
        "백업 및 복원": "Backup & restore", "JSON 백업 내보내기": "Export JSON backup", "JSON 백업 가져오기": "Import JSON backup",
        "개인정보 처리방침": "Privacy Policy", "기록 초기화": "Reset records", "수정 취소": "Cancel edit",
        "사용자 운동": "Custom exercise", "분": "min", "초": "s", "회": " reps"
        ,"구독 정보를 불러오지 못했습니다.": "Could not load subscription information.", "구독 상품을 불러오지 못했습니다.": "Could not load the subscription product.",
        "구매 승인을 기다리고 있습니다.": "Waiting for purchase approval.", "구매를 완료하지 못했습니다.": "Could not complete the purchase.",
        "복원할 구독이 없습니다.": "No purchase is available to restore.", "구매 복원에 실패했습니다.": "Could not restore purchases.", "Premium 구매": "Get Premium"
    ]

    static let exerciseNames: [String: String] = [
        "treadmill": "Treadmill", "shoulderpress": "Shoulder Press", "latpulldown": "Lat Pulldown", "reardelt": "Rear Delt Machine",
        "legextension": "Seated Leg Extension", "legcurl": "Leg Curl", "legpress": "Leg Press", "armcurl": "Arm Curl Machine",
        "pushup": "Push-ups", "squat": "Squats", "lunge": "Lunges", "plank": "Plank", "bodyinversion": "Body Inversion", "burpee": "Burpees",
        "mountain": "Mountain Climbers", "dip": "Triceps Dips", "legraise": "Leg Raises", "crunch": "Crunches",
        "bridge": "Glute Bridge", "jumpjack": "Jumping Jacks", "inchworm": "Inchworms", "benchpress": "Bench Press",
        "dumbbellrow": "Dumbbell Row", "deadlift": "Deadlift", "lateralraise": "Lateral Raises", "calfraise": "Calf Raises"
    ]
}

extension Exercise {
    var localizedName: String {
        UserDefaults.standard.string(forKey: "homets.language") == "en" ? (HometsEnglish.exerciseNames[id] ?? name) : name
    }
    var localizedGroup: String { tr(group) }
}
