import 'package:example/progress_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:microsoft_viewer/microsoft_viewer.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MicrosoftViewer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String fileLinkXLS = "https://onlinetestcase.com/wp-content/uploads/2023/06/100-kb.xlsx";
  String fileLinkWord = "https://calibre-ebook.com/downloads/demos/demo.docx";
  String fileLinkPPT = "https://wiki.documentfoundation.org/images/4/47/Extlst-test.pptx";
  //List<int> fileBytes=[];
  late MicrosoftViewer microsoftViewer = const MicrosoftViewer([], false);
  bool showProgress = false;
  @override
  void initState() {
    //microsoftViewer=MicrosoftViewer([]);
    if(kIsWeb){
      getAssetFile("word-asset");
    }else {
      getFileData("word");
    }

    super.initState();
  }

  Future<void> getFileData(String type) async {
    setState(() {
      showProgress = true;
    });
    String filePath = fileLinkWord;
    switch (type) {
      case "xls":
        filePath = fileLinkXLS;
        break;
      case "ppt":
        filePath = fileLinkPPT;
        break;
    }
    var response = await http.get(Uri.parse(filePath));
    setState(() {
      Key newKey = UniqueKey();
      microsoftViewer = MicrosoftViewer(
        response.bodyBytes,
        false,
        key: newKey,
      );
      showProgress = false;
    });
  }

  Future<void> getAssetFile(String type) async {
    setState(() {
      showProgress = true;
    });
    String fileName = "assets/demo.docx";
    if(type == "xls-asset") {
      fileName = "assets/2024-calendar-planner-v2.xlsx";
    }else if (type == "ppt-asset") {
      fileName = "assets/Abstract Color Wave PowerPoint Templates.pptx";
    }
    ByteData byteData = await rootBundle.load(fileName);
    setState(() {
      Key newKey = UniqueKey();
      microsoftViewer = MicrosoftViewer(
        Uint8List.sublistView(byteData),
        false,
        key: newKey,
      );
      showProgress = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: const Text("MicrosoftViewer Demo"),
      ),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              const SizedBox(
                height: 10,
              ),
              kIsWeb?Container():Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    child: const Text("Word File"),
                    onTap: () {
                      getFileData("word");
                    },
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  InkWell(
                    child: const Text("XLS File"),
                    onTap: () {
                      getFileData("xls");
                    },
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  InkWell(
                    child: const Text("PPT File"),
                    onTap: () {
                      getFileData("ppt");
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                  ),
                  InkWell(
                    child: const Text("Word from assets"),
                    onTap: () {
                      getAssetFile("word-asset");
                    },
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  InkWell(
                    child: const Text("XLS from assets"),
                    onTap: () {
                      getAssetFile("xls-asset");
                    },
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  InkWell(
                    child: const Text("PPT from assets"),
                    onTap: () {
                      getAssetFile("ppt-asset");
                    },
                  )
                ],
              ),
              //SizedBox(
              //    height: 500,
              //    child: WebViewWidget(controller: webViewController)),
              microsoftViewer
            ],
          ),
          showProgress ? const ProgressIndicatorView() : Container()
        ],
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
