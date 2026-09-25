# Share to Nook

The second way in. Copy link → open Nook → paste → Analyze is four steps; this
is share → Nook, and extraction has started by the time the app finishes
opening.

## One pipeline, two entrances

```
Paste Link ──────┐
                 ├─→ PasteLinkScreen ─→ platform detection ─→ source metadata
Share to Nook ───┘                    ─→ Gemini ─→ structured data ─→ save
```

`PasteLinkScreen` takes an optional `sharedUrl`. When it is set the field is
filled and `_analyze()` runs on the first frame. There is deliberately no
second extraction path: a shared post and a pasted one are the same post, and
one of them going stale while the other is maintained is the failure this
avoids.

## What ships: the Web Share Target

Nook deploys as a web app, so the mechanism that actually works for this build
is the [Web Share Target API](https://developer.mozilla.org/docs/Web/Manifest/share_target).
`web/manifest.json` declares:

```json
"share_target": {
    "action": ".",
    "method": "GET",
    "enctype": "application/x-www-form-urlencoded",
    "params": { "title": "shared_title", "text": "shared_text", "url": "shared_url" }
}
```

With Nook installed to the home screen, it appears in the Android share sheet.
Picking it opens `/?shared_url=…`, which is an ordinary navigation — so it works
whether Nook was running, backgrounded, or closed.

`lib/share/shared_link.dart` reads those parameters and clears them from the
address bar immediately, so a reload cannot save the same post twice.

### Why `text` is searched as well as `url`

Share sheets rarely hand over a bare URL. TikTok sends something like
`Check this out! https://vm.tiktok.com/ZSABCdefg/` in the *text* field and
leaves *url* empty. `SharedLink.firstLinkIn` pulls the first `http(s)` link out
of the sentence and drops the trailing punctuation.

### Requirements and limits

- **Installed as a PWA.** A browser tab is not in the share sheet; the app has
  to be added to the home screen first.
- **Android Chrome / Edge.** Share Target is not implemented in iOS Safari.
  An iPhone user still has Paste Link, which is why that stays.
- **HTTPS.** GitHub Pages serves over HTTPS, so this is satisfied.

## Native builds

Receiving a share on a packaged Android or iOS app needs platform plumbing that
cannot be written from Dart, and that this project — which builds and deploys
for the web — has no way to exercise. `lib/share/shared_link_io.dart` is
therefore a stub that returns null, which is the same state as an ordinary
launch.

What to add when Nook is built for a device:

### Android

In `android/app/src/main/AndroidManifest.xml`, inside the `<activity>`:

```xml
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>
```

Then read `Intent.EXTRA_TEXT` in `MainActivity` and pass it to Dart over a
`MethodChannel`, or add `receive_sharing_intent` and have it do both. Either
way the value goes into `initialSharedLink()` — nothing downstream changes.

### iOS

A Share Extension target in Xcode, with an App Group shared between the
extension and the app so the extension can hand the URL over. The extension
writes to the group's `UserDefaults`; `initialSharedLink()` reads it.

## Tested

`test/share_and_open_test.dart` covers the parsing, which is the part with the
edge cases: a link inside a sentence, trailing punctuation, a newline between
text and link, several links, and no link at all.

The browser half — the manifest entry and the share sheet — needs an installed
PWA on an Android device and was not exercised in CI.
