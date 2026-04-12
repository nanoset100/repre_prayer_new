"""
대표기도문 스크린샷 iOS 상태바 교체 스크립트
- Android 상태바(U+ 캐리어, 안드로이드 아이콘) → iOS 상태바(9:41, 배터리/신호) 교체
- Android 네비게이션바(|||, O, <) 제거
- iPhone (1284×2778) / iPad (2048×2732) 사이즈로 저장
"""

from PIL import Image, ImageDraw, ImageFont
import os

# ─── 설정 ───────────────────────────────────────────────────
BASE_DIR = "M:/MyProject - new/repre_prayer_new/image"
ORIG_FILES = [f"{BASE_DIR}/{i}.png" for i in range(1, 5)]

IPHONE_SIZE = (1284, 2778)
IPAD_SIZE   = (2048, 2732)

# Android 상태바/네비바 높이 (원본 1080×1920 기준)
ANDROID_STATUS_BAR_H = 72    # 상단 상태바
ANDROID_NAV_BAR_H    = 158   # 하단 네비게이션바 (y=1762~)
APP_CONTENT_BOTTOM   = 1762  # 네비게이션바 시작 y좌표

# iOS 상태바 높이 (원본 1080 기준으로 설정, 44pt * 3x = 132px이지만 앱 맞게)
IOS_STATUS_BAR_H = 72

# 앱 초록색 (상태바 배경)
GREEN = (76, 175, 80)
WHITE = (255, 255, 255)
BG_COLOR = (240, 255, 241)  # 연한 초록 배경

# ─── iOS 상태바 그리기 ────────────────────────────────────
def draw_ios_statusbar(draw, width, height, scale=1.0):
    """iOS 스타일 상태바를 그린다 (배경은 이미 GREEN으로 채워진 상태)"""
    bar_h = int(IOS_STATUS_BAR_H * scale)
    font_size = int(28 * scale)

    try:
        # 시스템 폰트 시도
        font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", font_size)
        font_small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", int(20 * scale))
    except:
        font = ImageFont.load_default()
        font_small = font

    # 시간 "9:41" (왼쪽)
    time_x = int(40 * scale)
    time_y = bar_h // 2 - font_size // 2
    draw.text((time_x, time_y), "9:41", fill=WHITE, font=font)

    # 오른쪽 아이콘들 (배터리, 와이파이, 신호)
    right_x = width - int(180 * scale)
    icon_y = bar_h // 2

    # 신호바 (4개의 작은 막대)
    bar_w = int(5 * scale)
    bar_gap = int(3 * scale)
    for i in range(4):
        bh = int((8 + i * 5) * scale)
        bx = right_x + i * (bar_w + bar_gap)
        by = icon_y - bh // 2
        draw.rectangle([bx, by, bx + bar_w, by + bh], fill=WHITE)

    # 와이파이 아이콘 (단순 호 3개)
    wifi_x = right_x + int(45 * scale)
    wifi_y = icon_y
    for r in [int(18 * scale), int(12 * scale), int(6 * scale)]:
        draw.arc(
            [wifi_x - r, wifi_y - r, wifi_x + r, wifi_y + r],
            start=200, end=340, fill=WHITE, width=int(2.5 * scale)
        )

    # 배터리 아이콘
    bat_x = right_x + int(80 * scale)
    bat_w = int(44 * scale)
    bat_h = int(22 * scale)
    bat_y = icon_y - bat_h // 2
    # 배터리 외곽
    draw.rectangle([bat_x, bat_y, bat_x + bat_w, bat_y + bat_h],
                   outline=WHITE, width=int(2 * scale))
    # 배터리 충전부 꼭지
    tip_w = int(4 * scale)
    tip_h = int(12 * scale)
    draw.rectangle([bat_x + bat_w + 1, bat_y + (bat_h - tip_h) // 2,
                    bat_x + bat_w + tip_w, bat_y + (bat_h - tip_h) // 2 + tip_h],
                   fill=WHITE)
    # 배터리 내부 충전 (80%)
    charge_w = int((bat_w - 6) * 0.8)
    draw.rectangle([bat_x + 3, bat_y + 3,
                    bat_x + 3 + charge_w, bat_y + bat_h - 3],
                   fill=WHITE)

# ─── 이미지 처리 ──────────────────────────────────────────
def process_screenshot(orig_path, iphone_out, ipad_out):
    img = Image.open(orig_path).convert("RGB")
    w, h = img.size  # 1080, 1920

    # 1) Android 상태바 제거 → iOS 상태바로 교체
    # 상태바 영역을 GREEN으로 다시 그리기
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, w, ANDROID_STATUS_BAR_H], fill=GREEN)
    draw_ios_statusbar(draw, w, ANDROID_STATUS_BAR_H, scale=1.0)

    # 2) Android 네비게이션바 제거 (하단 크롭)
    img_cropped = img.crop((0, 0, w, APP_CONTENT_BOTTOM))

    # ── iPhone (1284×2778) ──────────────────────────────
    # 콘텐츠를 1284 너비로 스케일, 비율 유지
    content_h = APP_CONTENT_BOTTOM  # 1762
    scale_w = IPHONE_SIZE[0] / w    # 1284/1080 = 1.1889
    new_h = int(content_h * scale_w)  # 1762 * 1.1889 ≈ 2094

    img_scaled = img_cropped.resize((IPHONE_SIZE[0], new_h), Image.LANCZOS)

    # 상하 패딩으로 2778 높이 맞추기
    pad_total = IPHONE_SIZE[1] - new_h
    pad_top = pad_total // 3
    pad_bot = pad_total - pad_top

    iphone_img = Image.new("RGB", IPHONE_SIZE, BG_COLOR)
    iphone_img.paste(img_scaled, (0, pad_top))
    iphone_img.save(iphone_out)
    print(f"  ✅ iPhone: {iphone_out}")

    # ── iPad (2048×2732) ───────────────────────────────
    scale_w_ipad = IPAD_SIZE[0] / w   # 2048/1080 = 1.896
    new_h_ipad = int(content_h * scale_w_ipad)

    img_scaled_ipad = img_cropped.resize((IPAD_SIZE[0], new_h_ipad), Image.LANCZOS)

    pad_total_ipad = IPAD_SIZE[1] - new_h_ipad
    pad_top_ipad = pad_total_ipad // 3
    pad_bot_ipad = pad_total_ipad - pad_top_ipad

    ipad_img = Image.new("RGB", IPAD_SIZE, BG_COLOR)
    ipad_img.paste(img_scaled_ipad, (0, pad_top_ipad))
    ipad_img.save(ipad_out)
    print(f"  ✅ iPad:   {ipad_out}")

# ─── 실행 ─────────────────────────────────────────────────
os.makedirs(f"{BASE_DIR}/iphone", exist_ok=True)
os.makedirs(f"{BASE_DIR}/ipad", exist_ok=True)

for i, orig in enumerate(ORIG_FILES, 1):
    if not os.path.exists(orig):
        print(f"⚠️  파일 없음: {orig}")
        continue
    print(f"\n📸 처리 중: {i}.png")
    process_screenshot(
        orig,
        f"{BASE_DIR}/iphone/{i}.png",
        f"{BASE_DIR}/ipad/{i}.png",
    )

print("\n🎉 완료! iphone/ 과 ipad/ 폴더에 저장되었습니다.")
