"""진행 현황 웹 페이지(progress.html)를 만든다.

사용법:  python docs/progress-page/build.py
- progress.template.html 의 {{IMGxx}} 자리에 docs/blog/images/ 의 캡처를 base64로 넣어 progress.html 을 만든다.
- 만들어진 progress.html 은 저장소에 올리지 않는다(.gitignore). 게시는 Claude의 Artifact 기능으로 한다.
- 내용(숫자, 로드맵)은 템플릿 안에 직접 적혀 있으므로, docs/PROGRESS.md 를 고친 뒤 템플릿도 같이 고친다.
"""
import base64
from pathlib import Path

here = Path(__file__).parent
images = here.parent / "blog" / "images"

SLOTS = {
    "IMG06": "06-stats-summary-chart.jpg",
    "IMG07": "07-stats-customers-reservations.jpg",
    "IMG08": "08-stats-past-month.jpg",
    "IMG05": "05-home.jpg",
    "IMG03": "03-reservation-conflict.jpg",
}

html = (here / "progress.template.html").read_text(encoding="utf-8")
for slot, filename in SLOTS.items():
    data = base64.b64encode((images / filename).read_bytes()).decode()
    marker = "{{" + slot + "}}"
    assert marker in html, f"템플릿에 {marker} 가 없습니다"
    html = html.replace(marker, "data:image/jpeg;base64," + data)

out = here / "progress.html"
out.write_text(html, encoding="utf-8")
print(f"만들었습니다: {out} ({out.stat().st_size // 1024} KB)")
