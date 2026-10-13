// ignore_for_file: depend_on_referenced_packages

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens the browser print dialog for an MSCAS HTML report without
/// replacing the current Flutter web application.
void printHtml(String reportHtml) {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;

  iframe.style
    ..position = 'fixed'
    ..right = '0'
    ..bottom = '0'
    ..width = '0'
    ..height = '0'
    ..border = '0';

  iframe.srcdoc = reportHtml.toJS;

  void handleLoad(web.Event event) {
    final contentWindow = iframe.contentWindow;

    if (contentWindow != null) {
      contentWindow.print();
    }

    Future<void>.delayed(const Duration(seconds: 2), () {
      iframe.remove();
    });
  }

  iframe.addEventListener('load', handleLoad.toJS);

  web.document.body?.appendChild(iframe);
}
