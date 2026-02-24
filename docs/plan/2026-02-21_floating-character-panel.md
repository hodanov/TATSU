# Plan

通知発火時にドラゴンキャラクターの画像と吹き出しテキストを
デスクトップ最前面に表示する FloatingCharacterPanel を実装する。
AppKit の NSPanel を使い、LSUIElement=true のメニューバーアプリ環境でも
他アプリの手前に常時表示できるようにする。

## Scope

- In:
  - `build.sh` への PNG リソースコピー行の追加
  - `build.sh` の swiftc コマンドへの新規ファイル追加
  - `TATSU/FloatingCharacterPanel.swift` の新規作成（NSPanel サブクラス）
  - `TATSU/AppDelegate.swift` の `timerModel(_:didRequestNotification:)` への呼び出し挿入
- Out:
  - Assets.xcassets / actool パイプラインの整備
  - 音声・ボイス合成（AVSpeechSynthesizer 等）
  - アニメーション（フェードイン/アウト以外の複雑な動き）
  - テスト追加（FloatingCharacterPanel は UI コンポーネントのため除外）

## Implementation Notes

### FloatingCharacterPanel の設計方針

```swift
// スタイル
styleМask: .borderless           // 枠なし
level: NSWindow.Level.floating   // 最前面（LSUIElement=true 環境でも有効）
backgroundColor: .clear          // 透明背景
isOpaque: false
canBecomeKey: false              // キーウィンドウを奪わない
collectionBehavior: .canJoinAllSpaces  // 全スペース・フルスクリーンでも表示

// 表示仕様
// - 画面右下に配置（NSScreen.main の visibleFrame から計算）
// - ドラゴン画像（tatsu_icon_flying_dragon.png）+ 吹き出しテキスト
// - 5秒後に自動非表示（DispatchQueue.main.asyncAfter）
// - .standing / .walk の通知タイプごとにセリフを変える
```

### リソースパス

`Assets.xcassets` はビルドパイプライン未統合のため使用不可。
`Bundle.main.path(forResource:ofType:)` で読み込む。

### 通知タイプ別セリフ

| NotificationType | 表示テキスト（案）   |
| ---------------- | -------------------- |
| `.standing`      | 立ち上がる時間だよ！ |
| `.walk`          | 散歩しよう！         |

## Action items

- [ ] `tatsu_icon_flying_dragon.png` の背景透過（アルファチャンネル）を確認する
- [ ] `build.sh` に PNG コピー行を追加する（`cp` を Info.plist コピーの直後に挿入）
- [ ] `TATSU/FloatingCharacterPanel.swift` を新規作成する
- [ ] `build.sh` の swiftc コマンドに `FloatingCharacterPanel.swift` を追加する
- [ ] `AppDelegate.swift` の `timerModel(_:didRequestNotification:)` に呼び出しを挿入する
- [ ] `./build.sh && open build/TATSU.app` でビルド＆動作確認する

## Open questions

- `tatsu_icon_flying_dragon.png` は背景透過か？白背景なら NSImageView に
  `imageScaling` + 角丸クリッピングが必要になる
- 吹き出しの実装は NSTextField（シンプル）か NSView サブクラスで
  CoreGraphics 描画（吹き出し形状あり）か、どちらにするか？
- フルスクリーンアプリ上での表示は `canJoinAllSpaces` だけで十分か、
  実機で確認が必要
