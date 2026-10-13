import 'report_print_service_stub.dart'
    if (dart.library.html) 'report_print_service_web.dart'
    as implementation;

class ReportPrintService {
  static void printHtml(String html) => implementation.printHtml(html);
}
