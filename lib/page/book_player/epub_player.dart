import 'dart:convert';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/book.dart';
import 'package:anx_reader/dao/book_note.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/models/book_style.dart';
import 'package:anx_reader/models/read_theme.dart';
import 'package:anx_reader/models/toc_item.dart';
import 'package:anx_reader/service/book_player/book_player_server.dart';
import 'package:anx_reader/utils/coordinates_to_part.dart';
import 'package:anx_reader/utils/get_base_path.dart';
import 'package:anx_reader/utils/js/convert_dart_color_to_js.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/models/book_note.dart';
import 'package:anx_reader/widgets/context_menu.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/page_turning/diagram.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/page_turning/types_and_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubPlayer extends StatefulWidget {
  final String content;
  final Book book;
  final Function showOrHideAppBarAndBottomBar;

  const EpubPlayer(
      {super.key,
      required this.content,
      required this.showOrHideAppBarAndBottomBar,
      required this.book});

  @override
  State<EpubPlayer> createState() => EpubPlayerState();
}

class EpubPlayerState extends State<EpubPlayer> {
  late InAppWebViewController webViewController;
  late ContextMenu contextMenu;
  String cfi = '';
  double percentage = 0.0;
  String chapterTitle = '';
  String chapterHref = '';
  int chapterCurrentPage = 0;
  int chapterTotalPages = 0;
  List<TocItem> toc = [];
  OverlayEntry? contextMenuEntry;

  void prevPage() {
    webViewController.evaluateJavascript(source: 'prevPage()');
  }

  void nextPage() {
    webViewController.evaluateJavascript(source: 'nextPage()');
  }

  void prevChapter() {
    webViewController.evaluateJavascript(source: '''
      prevSection()
      ''');
  }

  void nextChapter() {
    webViewController.evaluateJavascript(source: '''
      nextSection()
      ''');
  }

  Future<void> goToPercentage(double value) async {
    await webViewController.evaluateJavascript(source: '''
      goToPercent($value); 
      ''');
  }

  void changeTheme(ReadTheme readTheme) {
    String backgroundColor = convertDartColorToJs(readTheme.backgroundColor);
    String textColor = convertDartColorToJs(readTheme.textColor);

    webViewController.evaluateJavascript(source: '''
      changeStyle({
        backgroundColor: '#$backgroundColor',
        fontColor: '#$textColor',
      })
      ''');
  }

  void changeStyle(BookStyle bookStyle) {
    webViewController.evaluateJavascript(source: '''
      changeStyle({
        fontSize: ${bookStyle.fontSize},
        spacing: '${bookStyle.lineHeight}',
        paragraphSpacing: ${bookStyle.paragraphSpacing},
        topMargin: ${bookStyle.topMargin},
        bottomMargin: ${bookStyle.bottomMargin},
        sideMargin: ${bookStyle.sideMargin},
        letterSpacing: ${bookStyle.letterSpacing},
      })
    ''');
  }

  void goToHref(String href) {
    webViewController.evaluateJavascript(source: '''
      goToHref('$href');
      ''');
  }

  void addAnnotation(BookNote bookNote) {
    webViewController.evaluateJavascript(source: '''
      addAnnotation({
        id: ${bookNote.id},
        type: '${bookNote.type}',
        value: '${bookNote.cfi}',
        color: '#${bookNote.color}',
        note: '${bookNote.content}',
      })
      ''');
  }

  void removeAnnotation(String cfi) {
    webViewController.evaluateJavascript(source: '''
      removeAnnotation('$cfi');
      ''');
  }

  void onClick(Map<String, dynamic> location) {
    if (contextMenuEntry != null) {
      removeOverlay();
      return;
    }
    final x = location['x'];
    final y = location['y'];
    final part = coordinatesToPart(x, y);
    final currentPageTurningType = Prefs().pageTurningType;
    final pageTurningType = pageTurningTypes[currentPageTurningType];
    switch (pageTurningType[part]) {
      case PageTurningType.prev:
        prevPage();
        break;
      case PageTurningType.next:
        nextPage();
        break;
      case PageTurningType.menu:
        widget.showOrHideAppBarAndBottomBar(true);
        break;
    }
  }

  Future<void> onLoadStart(InAppWebViewController controller) async {
    ReadTheme readTheme = Prefs().readTheme;
    BookStyle bookStyle = Prefs().bookStyle;
    String backgroundColor = convertDartColorToJs(readTheme.backgroundColor);
    String textColor = convertDartColorToJs(readTheme.textColor);
    List<BookNote> annotationList = await selectBookNotesByBookId(widget.book.id);
    String allAnnotations = jsonEncode(annotationList.map((e) => e.toJson()).toList());

    controller.evaluateJavascript(source: '''
      const allAnnotations = $allAnnotations;
      const url = 'http://localhost:${Server().port}/book/${getBasePath(widget.book.filePath)}';
      let cfi = '${widget.book.lastReadPosition}';
      console.log('BookPlayer:' + cfi);
      let style = {
          fontSize: ${bookStyle.fontSize},
          letterSpacing: ${bookStyle.letterSpacing},
          spacing: ${bookStyle.lineHeight},
          paragraphSpacing: ${bookStyle.paragraphSpacing},
          fontColor: '#$textColor',
          backgroundColor: '#$backgroundColor',
          topMargin: ${bookStyle.topMargin},
          bottomMargin: ${bookStyle.bottomMargin},
          sideMargin: ${bookStyle.sideMargin},
          justify: true,
          hyphenate: true,
          scroll: false,
          animated: true
      }
  ''');
  }

  void setHandler(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
        handlerName: 'onRelocated',
        callback: (args) {
          Map<String, dynamic> location = args[0];
          cfi = location['cfi'];
          percentage = location['percentage'];
          chapterTitle = location['chapterTitle'];
          chapterHref = location['chapterHref'];
          chapterCurrentPage = location['chapterCurrentPage'];
          chapterTotalPages = location['chapterTotalPages'];
        });
    controller.addJavaScriptHandler(
        handlerName: 'onClick',
        callback: (args) {
          Map<String, dynamic> location = args[0];
          onClick(location);
        });
    controller.addJavaScriptHandler(
        handlerName: 'onSetToc',
        callback: (args) {
          List<dynamic> t = args[0];
          toc = t.map((i) => TocItem.fromJson(i)).toList();
        });
    controller.addJavaScriptHandler(
        handlerName: 'onSelectionEnd',
        callback: (args) {
          Map<String, dynamic> location = args[0];
          String cfi = location['cfi'];
          String text = location['text'];
          double x = location['pos']['point']['x'];
          double y = location['pos']['point']['y'];
          String dir = location['pos']['dir'];
          showContextMenu(context, x, y, dir, text, cfi, null);
        });
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    // progressSetter();
    // clickHandlers();
    setHandler(controller);
  }

  void removeOverlay() {
    if (contextMenuEntry == null || contextMenuEntry?.mounted == false) return;
    contextMenuEntry?.remove();
    contextMenuEntry = null;
  }

  @override
  void initState() {
    super.initState();
    contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
      onCreateContextMenu: (hitTestResult) async {
        webViewController.evaluateJavascript(source: "showContextMenu()");
      },
      onHideContextMenu: () {
        // removeOverlay();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
    InAppWebViewController.clearAllCache();
    Book book = widget.book;
    book.lastReadPosition = cfi;
    book.readingPercentage = percentage;
    updateBook(book);
    removeOverlay();
  }

  String indexHtmlPath = "localhost:${Server().port}/foliate-js/index.html";
  InAppWebViewSettings initialSettings = InAppWebViewSettings(
    supportZoom: false,
    transparentBackground: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(indexHtmlPath)),
            onLoadStart: (controller, url) => onLoadStart(controller),
            initialSettings: initialSettings,
            contextMenu: contextMenu,
            onWebViewCreated: (controller) => onWebViewCreated(controller),
            onConsoleMessage: (controller, consoleMessage) {
              if (consoleMessage.messageLevel == ConsoleMessageLevel.LOG) {
                AnxLog.info('Webview: ${consoleMessage.message}');
              } else if (consoleMessage.messageLevel ==
                  ConsoleMessageLevel.WARNING) {
                AnxLog.warning('Webview: ${consoleMessage.message}');
              } else if (consoleMessage.messageLevel ==
                  ConsoleMessageLevel.ERROR) {
                AnxLog.severe('Webview: ${consoleMessage.message}');
              }
            },
          ),
        ],
      ),
    );
  }
}
