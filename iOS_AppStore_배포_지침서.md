# iOS App Store 배포 지침서
## Flutter 앱 → Codemagic 빌드 → App Store 제출
### (Mac 없음, iPhone 없음 환경 기준)

---

## 📋 작업 개요

**목표**: 구글 플레이에 이미 배포된 Flutter 앱을 iOS App Store에 배포
**도구**: Codemagic (클라우드 빌드), App Store Connect
**참고 성공 사례**: 대표기도문 앱 v1.1.18 (2026-03-13 심사 제출 완료)

---

## ✅ 사전 준비 체크리스트

### 계정
- [ ] Apple Developer Program 계정 (연 $99, 유료 앱 계약 포함)
- [ ] Codemagic 계정 (codemagic.io)
- [ ] App Store Connect에 앱 등록 완료

### App Store Connect에서 앱 등록 시 필요한 것
- Bundle ID (예: `com.nanoset.leaderprayer` 형식)
- 앱 이름 (한국어 가능)
- 개인정보 처리방침 URL (Google Sites 무료 페이지로 가능)

---

## 🔧 STEP 1: 코드 준비 (Flutter 프로젝트)

### 1-1. Bundle ID 확인 및 수정

**파일**: `ios/Runner.xcodeproj/project.pbxproj`

파일 내에서 `com.example.` 으로 시작하는 Bundle ID를 App Store Connect에 등록한 Bundle ID로 전체 교체:
```
com.example.앱이름 → com.여러분의.bundleid
```
(VS Code에서 Ctrl+H로 전체 교체)

### 1-2. iOS 최소 배포 타겟 설정

**파일**: `ios/Podfile` (없으면 새로 생성)

```ruby
platform :ios, '15.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig and running flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

> ⚠️ firebase_core 등 최신 패키지는 iOS 15.0 이상 요구. 12.0이면 빌드 실패함.

### 1-3. pubspec.yaml 버전 확인

```yaml
version: 1.0.0+1   # 버전명+빌드번호
```
빌드번호는 App Store Connect에 올릴 때마다 증가해야 함.

### 1-4. .env 파일 처리 (API Key가 있는 경우)

`.env` 파일은 git에 올리면 안 되므로 Codemagic Pre-build script로 생성.
`pubspec.yaml`의 assets에는 등록해둬야 함:
```yaml
assets:
  - .env
```

### 1-5. AdMob 사용 시 (google_mobile_ads)

**파일**: `android/app/src/debug/AndroidManifest.xml` 및 `profile/AndroidManifest.xml`
```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
```

---

## 🚀 STEP 2: Codemagic 설정

### 2-1. 앱 연결

1. codemagic.io 로그인
2. "Add application" → GitHub 연결 → 리포지토리 선택
3. Flutter App 선택

### 2-2. Workflow Editor 설정

#### Build 섹션
- **Mode**: Release (⚠️ Debug로 되어 있으면 서명 실패)
- **Build for platforms**: iOS (Android는 별도 workflow)

#### Distribution 섹션 (iOS Code Signing)
- **Signing**: Automatic
- **Apple Developer Portal**: 연결 필요

#### Apple Developer Portal 연결
1. App Store Connect API Key 생성:
   - App Store Connect → 사용자 및 액세스 → 통합 → App Store Connect API
   - 키 생성 (관리자 권한) → `.p8` 파일 다운로드
   - Key ID, Issuer ID 메모
2. Codemagic → Team Settings → Integrations → Developer Portal
3. API Key 추가 (Key ID + Issuer ID + .p8 파일)
4. ⚠️ 이미 등록된 Key ID가 있으면 기존 것 재사용 (중복 등록 불가)

#### Bundle Identifier 설정
- Automatic에서 앱 Bundle ID 선택
- App Store Connect에 등록된 Bundle ID와 정확히 일치해야 함

### 2-3. 환경변수 설정 (API Key가 있는 경우)

Codemagic → Workflow → Environment variables:
```
OPENAI_API_KEY = sk-xxxxxxxx  (Secure 체크)
```

### 2-4. Pre-build Script (.env 파일 생성)

Codemagic → Workflow → Scripts → Pre-build:
```bash
echo "OPENAI_API_KEY=$OPENAI_API_KEY" > $CM_BUILD_DIR/.env
```

### 2-5. App Store Connect 배포 설정

- Distribution → App Store Connect
- App Store Connect API Key 선택
- Bundle ID 선택
- **"Submit to App Store"**: 체크하면 자동 업로드

---

## 📱 STEP 3: App Store Connect 앱 준비

### 3-1. 계약 확인

배포 전 반드시 확인:
- developer.apple.com → Account → 계약 모두 동의
- App Store Connect → 비즈니스 → 계약 활성화 확인

### 3-2. 스크린샷 준비

**필수 크기**:
| 기기 | 크기 |
|------|------|
| iPhone 6.9" | 1320×2868 또는 1290×2796 |
| iPhone 6.5" | 1284×2778 또는 1242×2688 |
| iPad 12.9" | 2048×2732 |

**스크린샷 변환 (Python)**:
```python
from PIL import Image

img = Image.open("원본.png")
# iPad: 2732×2732 → 2048×2732 크롭
width, height = img.size
new_width = int(height * 2048 / 2732)
left = (width - new_width) // 2
img_cropped = img.crop((left, 0, left + new_width, height))
img_resized = img_cropped.resize((2048, 2732), Image.LANCZOS)
img_resized.save("ipad_2048x2732.png")
```

### 3-3. 앱 아이콘

- 1024×1024 PNG (투명 배경 없음, 둥근 모서리 없음)
- 직접 App Store Connect에 업로드

### 3-4. 앱 정보 필수 항목

- [ ] 앱 이름
- [ ] 자막 (30자 이내)
- [ ] 설명
- [ ] 키워드
- [ ] 지원 URL
- [ ] 개인정보 처리방침 URL
- [ ] 연령 등급 (설문 답변 후 자동 계산)
- [ ] 연락처 정보 (심사팀 연락처)
- [ ] 버전 정보 (새 기능 설명)

---

## 🔍 STEP 4: 빌드 실행 및 업로드

1. Codemagic에서 **"Start new build"** 클릭
2. 빌드 성공 후 `.ipa` 파일 자동 생성
3. App Store Connect API 연결 시 자동 업로드 (Processing 15~30분 소요)
4. App Store Connect → TestFlight에서 빌드 확인

---

## 📋 STEP 5: 개인정보 설정

앱 배포 전 필수! App Store Connect → 앱이 수집하는 개인정보

### AdMob 사용 앱의 경우

**데이터 수집**: 예

**선택할 데이터 유형**:

| 유형 | 항목 | 사용 목적 | 신원 연결 | 추적 |
|------|------|----------|----------|------|
| 사용자 콘텐츠 | 기타 사용자 콘텐츠 | 앱 기능 | 아니요 | 아니요 |
| 식별자 | 기기 ID | 타사 광고 | 아니요 | 예 |
| 사용 데이터 | 광고 데이터 | 타사 광고 | 아니요 | 예 |
| 진단 | 충돌 데이터 | 앱 기능 | 아니요 | 아니요 |

> ⚠️ "기기 ID"와 "광고 데이터"의 추적 여부는 **"예"** 선택 (AdMob IDFA 추적)
> → 앱 실행 시 iOS ATT(추적 허용) 팝업 자동 표시됨

**설정 완료 후 반드시 "게시" 버튼 클릭!**

---

## 📤 STEP 6: 심사 제출

1. 버전 페이지에서 **"심사에 추가"** 클릭
2. 제출 초안 팝업에서 **"심사를 위해 제출"** 클릭
3. 왼쪽 상태: "심사 대기 중" 확인
4. 최대 48시간 내 심사 결과 이메일 수신

---

## ⚠️ 자주 발생하는 오류 및 해결법

| 오류 | 원인 | 해결 |
|------|------|------|
| iOS 빌드 실패 (firebase_core) | iOS 최소 타겟 12.0 | Podfile에서 15.0으로 변경 |
| Bundle ID 불일치 | project.pbxproj vs App Store Connect | project.pbxproj 전체 교체 |
| .env 파일 없음 | gitignore로 제외됨 | Pre-build script로 생성 |
| 심사에 추가 안 됨 | 계약 미동의 / 연령등급 미설정 / 개인정보 미설정 | 각 항목 완료 |
| API Key 중복 | 이미 Codemagic에 등록됨 | 기존 키 재사용 |
| 빌드 Debug 모드 | Mode 설정 오류 | Release로 변경 |
| iPad 스크린샷 크기 오류 | 잘못된 크기 | Python Pillow로 2048×2732 변환 |

---

## 📁 성경통독 앱 작업 시 추가 확인사항

- Bundle ID: App Store Connect에서 새로 등록할 경우 `com.nanoset.biblereader` 형식으로 결정
- 앱 이름: "왕초보 성경통독" 또는 영문명 결정 필요
- 스크린샷: 앱 실행 후 에뮬레이터 또는 실기기로 캡처 (없으면 Codemagic 빌드 후 시뮬레이터 스크린샷 사용 가능)
- 오디오 파일: 용량 주의 (App Store 앱 크기 제한 4GB)
- 성경 데이터(JSON/CSV): assets에 포함되면 앱 크기 커짐 → 필요시 서버에서 다운로드하는 방식 고려

---

## 🔗 참고 링크

- Codemagic: https://codemagic.io
- App Store Connect: https://appstoreconnect.apple.com
- Apple Developer: https://developer.apple.com

---

## 🚨 트러블슈팅 실전 사례: Codemagic Publishing 실패 (2026-03-21 해결)

### 증상

- 빌드 #5 (커밋 94caa28): Publishing 로그가 `0` 한 줄만 표시, 1초 미만 종료 → TestFlight 미업로드
- 빌드 #6 (커밋 95a96ad): Publishing 로그 `No artifacts were found` → IPA 자체가 생성되지 않음
- 마지막 정상 업로드: 1.1.18 (131), 2026-03-13

### 원인 분석

| 빌드 | 설정 | 결과 | 원인 |
|------|------|------|------|
| #5 | ExportOptions.plist = automatic, xcode = latest | Publishing 0 (실패) | xcode: latest 버전 업데이트로 호환성 문제 추정 |
| #6 | ExportOptions.plist = manual, xcode = 16.2 | No artifacts were found | `manual` 방식은 `provisioningProfiles` 딕셔너리가 없으면 IPA export 실패 |

**핵심 원인**: `ios/ExportOptions.plist`의 `--export-options-plist` 옵션을 직접 참조하면,
Codemagic이 자동 생성하는 올바른 프로비저닝 설정을 무시하게 됨.

### 해결 방법 (빌드 #7, 커밋 c95dd3a — 성공)

`xcode-project use-profiles` 명령 실행 시 Codemagic이
`/Users/builder/export_options.plist` 파일을 **자동 생성**함.
이 파일에 올바른 프로비저닝 프로파일과 서명 설정이 모두 포함되어 있으므로,
우리가 만든 `ios/ExportOptions.plist` 대신 이것을 사용하면 됨.

**변경한 파일 3개:**

#### 1. `codemagic.yaml` — Flutter build IPA 스크립트 변경

```yaml
# 변경 전 (잘못됨)
flutter build ipa --release --no-pub --export-options-plist=ios/ExportOptions.plist

# 변경 후 (정상)
flutter build ipa --release --no-pub --export-options-plist=/Users/builder/export_options.plist
```

#### 2. `ios/ExportOptions.plist` — signingStyle 복원

```xml
<!-- 변경 전 (잘못됨) -->
<key>signingStyle</key>
<string>manual</string>

<!-- 변경 후 (복원) -->
<key>signingStyle</key>
<string>automatic</string>
```

> ⚠️ 이 파일은 빌드에 더 이상 사용되지 않음. 로컬 참고용으로만 유지.

#### 3. `pubspec.yaml` — 빌드 번호 증가

```yaml
# 변경 전
version: 1.1.18+133

# 변경 후
version: 1.1.18+134
```

> ⚠️ 실패한 빌드 번호(133)가 Apple 서버에 부분 등록되었을 수 있으므로 안전하게 증가.

### 결과

- 빌드 #7: 커밋 c95dd3a, Publishing 1분 13초 정상 실행
- IPA: repre_prayer_new.ipa (38.47 MB) 생성 확인
- App Store Connect TestFlight: 1.1.18 (134) "저리 중(처리 중)" 상태 확인 (2026-03-21 2:18 PM)
- 이전 정상 빌드(131) 이후 8일 만에 배포 정상화

### 핵심 교훈

> **Codemagic에서 `ios_signing` + `xcode-project use-profiles` 조합 사용 시,
> `--export-options-plist`는 반드시 `/Users/builder/export_options.plist` (Codemagic 자동생성)를 사용해야 함.**
> 직접 만든 `ios/ExportOptions.plist`를 참조하면 프로비저닝 프로파일 정보 불일치로 IPA export 실패.

---

*작성일: 2026-03-13*
*트러블슈팅 추가: 2026-03-21 (Codemagic Publishing 실패 → 해결)*
*참고: 대표기도문 앱 iOS 배포 성공 경험 기반*
