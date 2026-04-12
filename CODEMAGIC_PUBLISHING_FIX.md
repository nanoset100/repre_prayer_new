# Codemagic Publishing 실패 트러블슈팅 가이드

## 현상

- Codemagic 빌드(LeaderPrayer iOS Release)는 **성공(finished)**으로 표시됨
- Flutter build IPA 단계도 2분 7초 소요되어 정상 완료
- 그러나 **Publishing 단계가 1초 미만**으로 끝남 → IPA가 App Store Connect에 업로드되지 않음
- TestFlight에 새 버전이 나타나지 않음
- 마지막 정상 업로드: **1.1.18 (131)** — 2026년 3월 13일
- 현재 pubspec.yaml 빌드 번호: **132** (중복 아님)
- 어제까지는 정상 동작했음

## 확인된 사실 (파일 기반)

### 1. pubspec.yaml (19번째 줄)
```yaml
version: 1.1.18+132
```
- 빌드 번호 132는 TestFlight의 131보다 높으므로 **빌드 번호 중복은 원인이 아님**

### 2. codemagic.yaml — publishing 설정
```yaml
publishing:
  app_store_connect:
    auth: integration
    submit_to_testflight: true
    submit_to_app_store: false
```
- 설정 자체는 정상

### 3. codemagic.yaml — integration 이름
```yaml
integrations:
  app_store_connect: LuckyTenAPI
```
- `LuckyTenAPI`라는 App Store Connect API 키를 사용 중

### 4. ExportOptions.plist — 잠재적 충돌 발견
```xml
<key>signingStyle</key>
<string>automatic</string>
```
- Codemagic 스크립트에서는 `xcode-project use-profiles`로 **수동 프로비저닝 프로파일**을 적용하는데,
  ExportOptions.plist에서는 `signingStyle`이 `automatic`으로 설정되어 있음
- 이 불일치가 IPA 생성에 영향을 줄 수 있음

### 5. Xcode 버전
```yaml
xcode: latest
```
- `latest`를 사용하므로 Codemagic 서버에서 Xcode가 업데이트되면 동작이 변할 수 있음

---

## 수정 작업 (우선순위 순)

### 수정 1: ExportOptions.plist — signingStyle 변경

**파일:** `ios/ExportOptions.plist`

`signingStyle`을 `automatic`에서 `manual`로 변경:

```xml
<!-- 변경 전 -->
<key>signingStyle</key>
<string>automatic</string>

<!-- 변경 후 -->
<key>signingStyle</key>
<string>manual</string>
```

**이유:** Codemagic에서 `xcode-project use-profiles` 명령으로 수동 서명 프로파일을 적용하는데,
ExportOptions.plist가 automatic이면 충돌이 발생할 수 있음.
어제까지 동작했더라도, Codemagic의 Xcode 버전 업데이트로 이 충돌이 표면화될 수 있음.

### 수정 2: Xcode 버전 고정 (선택)

**파일:** `codemagic.yaml` (17번째 줄)

```yaml
# 변경 전
xcode: latest

# 변경 후 (안정적인 특정 버전으로 고정)
xcode: 16.2
```

**이유:** `latest`를 사용하면 Codemagic 서버에서 Xcode가 자동 업데이트될 때 빌드/서명 동작이 변할 수 있음.
어제까지 되다가 갑자기 안 되는 원인이 이것일 수 있음.

### 수정 3: 빌드 번호 증가 (안전 조치)

**파일:** `pubspec.yaml` (19번째 줄)

```yaml
# 변경 전
version: 1.1.18+132

# 변경 후
version: 1.1.18+133
```

**이유:** 이전 빌드에서 132가 부분적으로 업로드되었다가 실패한 경우,
Apple 서버에서 132를 이미 점유한 것으로 처리할 수 있음.
133으로 올려서 확실히 새 번호로 시도.

---

## 코드 수정 외에 사용자가 확인해야 할 사항

아래는 Codemagic 웹 UI에서 사용자가 직접 확인해야 하는 항목임 (코드로 수정 불가):

1. **Codemagic Publishing 상세 로그**: 빌드 페이지에서 "Publishing" 단계를 클릭하면 상세 에러 메시지를 볼 수 있음
2. **App Store Connect API 키 상태**: Codemagic → Settings → Integrations → App Store Connect에서 `LuckyTenAPI` 키가 만료되었는지 확인
3. **Apple Developer 계정**: 인증서나 프로비저닝 프로파일이 만료되었는지 확인

---

## 요약

| 항목 | 파일 | 수정 내용 |
|------|------|-----------|
| signingStyle 충돌 수정 | `ios/ExportOptions.plist` | `automatic` → `manual` |
| Xcode 버전 고정 (선택) | `codemagic.yaml` 17줄 | `latest` → `16.2` |
| 빌드 번호 증가 (안전) | `pubspec.yaml` 19줄 | `+132` → `+133` |
