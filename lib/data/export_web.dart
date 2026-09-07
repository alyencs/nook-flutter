import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands the export to the browser as a download.
///
/// A blob and a click on a temporary anchor — the same thing any download link
/// does. Nothing is uploaded; the file is built in the page and saved locally.
Future<String> saveExport(String contents, String filename) async {
  final blob = web.Blob(
    [contents.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Give the browser a moment to start the download before releasing the blob.
  await Future<void>.delayed(const Duration(milliseconds: 200));
  web.URL.revokeObjectURL(url);
  return filename;
}
