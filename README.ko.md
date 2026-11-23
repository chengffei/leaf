<p align="center">
  <img src="docs/images/icon.png" width="128" alt="Leaf">
</p>

<h1 align="center">Leaf</h1>

<p align="center">
  이중 클릭하면 읽고, 닫으면 끝.<br>
  작고 가벼운 Mac 전용 전자책 리더. 무료 오픈 소스.
</p>

<p align="center">
  <a href="https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg"><b>다운로드</b></a> ·
  <a href="https://chengffei.github.io/leaf/">웹사이트</a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <b>한국어</b> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a>
</p>

<p align="center">
  <img src="docs/images/reading.png" width="760" alt="Leaf 읽기 화면">
</p>

## 왜 Leaf인가

책 한 권에 윈도우 하나. Finder에서 책을 이중 클릭하면 바로 읽을 수 있습니다. 윈도우를 닫으면 Leaf도 종료됩니다.

- **서재가 없습니다.** 가져오기도, 파일 복사도, 계정도 필요 없습니다.
- **읽던 곳에서 이어서.** 파일 이름을 바꾸거나 옮겨도 그대로입니다.
- **Mac다운 앱.** 기본 메뉴, 단축키, 찾아보기와 번역을 지원합니다. 약 5MB.

## 읽기에 집중한 디자인

- **여섯 가지 포맷.** EPUB, MOBI, AZW3, PDF, FB2, CBZ를 변환 없이 엽니다. MOBI와 AZW3는 DRM이 없어야 합니다. PDF는 원래 레이아웃을 유지합니다.
- **글꼴은 마음대로.** 원하는 서체를 쓸 수 있고 Literata가 내장되어 있습니다. 크기 80~200%, 굵기 5단계, 줄 간격, 문단 간격, 자간, 여백, 정렬을 조절할 수 있습니다.
- **프리셋.** 좁게, 표준, 큰 글자, 저시력, 전자잉크. 나만의 프리셋도 저장할 수 있습니다.
- **테마.** 종이, 세피아, 전자잉크, 다크, 또는 시스템 설정을 따릅니다.
- **남은 시간.** 오른쪽 아래를 클릭하면 퍼센트, 위치, 장과 책의 남은 시간을 차례로 보여줍니다. 남은 시간은 읽는 속도로 계산합니다.
- **그 자리에서 각주.** 번호를 클릭하면 주석이 바로 그 자리에 나타납니다. 이동한 뒤에는 `⌘[`로 돌아옵니다.
- **찾기와 이동.** `⌘F`는 결과를 장별로 보여주고, `⌘L`은 원하는 퍼센트나 위치로 이동합니다.
- **떠 있는 목차.** `⌘T`를 누르면 본문 위에 떠서 열리므로 본문이 다시 배치되지 않습니다.
- **레이아웃.** 본문 폭과 1단 또는 2단을 고르고, 페이지 가장자리를 클릭해 넘깁니다.
- **이미지.** 이중 클릭하면 원래 크기로 봅니다.
- **하이라이트와 메모.** 텍스트를 선택하고 네 가지 색 중 하나를 고르면 하이라이트가 되고 메모를 붙일 수 있습니다. `⌘D`로 페이지를 책갈피에 추가합니다. 메모 패널(`⇧⌘N`)에 장별로 모두 표시됩니다.
- **내보내기.** Markdown 또는 Kindle의 My Clippings 형식으로 저장해 Readwise와 Obsidian에서 바로 씁니다.
- **한 번에 단어 찾아보기.** 단어를 선택하고 `⌃⌘D`를 누르거나, 선택 영역 위에 나타나는 막대의 찾아보기를 누릅니다.
- **책 소개.** 책 메타데이터의 소개를 패널 맨 위에 표시합니다.
- **8개 언어.** 영어, 중국어 간체, 중국어 번체, 일본어, 한국어, 프랑스어, 독일어, 스페인어.

## 다른 앱과 비교

[Readest](https://github.com/readest/readest)는 기능이 가장 많습니다. Apple Books는 Mac에 기본으로 들어 있습니다. Calibre는 장서 관리에 가장 강합니다. Leaf는 책을 여는 일만 합니다. [전체 비교표](https://chengffei.github.io/leaf/#compare)를 참고하세요.

## 다음 계획

- 출판사 스타일보다 내 글꼴 설정 우선, TXT 지원
- 실제 페이지 번호, 앞을 훑어본 뒤 돌아오는 방법
- Finder 썸네일, 훑어보기, Spotlight 검색은 그 다음

계획 없음: 서재, 스토어, 계정, 동기화.

## 설치

1. [Leaf.dmg](https://github.com/chengffei/leaf/releases/latest/download/Leaf.dmg)를 다운로드하고 Leaf를 '응용 프로그램'으로 드래그합니다.
2. Leaf는 Apple의 공증을 받지 않아 처음 실행할 때 macOS가 차단합니다. 한 번 열고 '완료'를 클릭한 다음, '시스템 설정 › 개인정보 보호 및 보안'에서 아래로 스크롤해 '그래도 열기'를 클릭하세요.

macOS 15 이상이 필요합니다.

## 단축키

| 동작 | 키 |
|---|---|
| 페이지 넘기기 | `←` `→`, 스페이스, 또는 트랙패드에서 좌우로 쓸기 |
| 목차 | `⌘T` 또는 `T`, 또는 왼쪽 아래 장 이름 클릭 |
| 글자 크기 | `⌘=` 크게, `⌘-` 작게, `⌘0` 실제 크기 |
| 찾기 | `⌘F`, `⌘G` 다음, `⇧⌘G` 이전 |
| 이동 | `⌘L` |
| 크기와 테마 | 오른쪽 위 `Aa`, 또는 페이지에서 오른쪽 클릭 |
| 설정 | `⌘,` |
| 하이라이트 | 텍스트를 선택한 뒤 색 선택 |
| 책갈피 | `⌘D` |
| 메모 | `⇧⌘N` |
| 찾아보기 | `⌃⌘D` |

## 소스에서 빌드

Xcode 26과 [XcodeGen](https://github.com/yonaskolb/XcodeGen)이 필요합니다.

```sh
xcodegen generate
./scripts/install.sh      # 빌드 후 /Applications에 설치
./scripts/make-dmg.sh     # ~/Downloads에 DMG 생성
```

구조 설명과 알려진 문제는 [DEVELOPMENT.md](DEVELOPMENT.md)(중국어)에 있습니다.

## 크레딧

렌더링과 포맷 해석은 [foliate-js](https://github.com/johnfactotum/foliate-js)(MIT)를 사용합니다. `TestBooks/`의 샘플 도서는 [Project Gutenberg](https://www.gutenberg.org/)의 퍼블릭 도메인 작품입니다.

## 기여하기

기여를 환영합니다. 코드를 기여하려면 [기여자 라이선스 계약](CLA.md)에 동의해야 합니다.

## 라이선스

[GPL-3.0](LICENSE). foliate-js는 MIT 라이선스를 유지합니다(`Web/foliate/LICENSE`).
