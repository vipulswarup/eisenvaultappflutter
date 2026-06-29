This is a very basic package to view Microsoft Documents like Word, SpreadSheet and Presentations.

Its built for the latest Microsoft files with extensions .docx, .xlsx and .pptx.

Currently its a very basic viewer and more features will be added progressively.

Email to info@karmalaya.in, in case you are ready to fund the project, contribute further to this project or need some specific customization.

## Features

1. Read .docx file and show text, images and tables with most of the formatting options handled.
2. Read .xlsx file and show the tables, with minimum formatting.
3. Read .pptx file and show text, background image and diagrams, with minimum formatting.

## Getting started

Add the package to your project and then pass the bytes of the .docx/.xlsx/.pptx to the Viewer.

## Usage

Add MicrosoftViewer into your build function as any other widget. Pass the byte data from the document you want to view. If the size of the widget is constrained by any height/width, set the next parameter as true.

Below is a simple example.

```dart
//for getting data from asset files
ByteData byteData=await rootBundle.load(fileName);

@override
Widget build(BuildContext context) {
  return MicrosoftViewer(Uint8List.sublistView(byteData),false);
}
//for getting data from network
var response = await http.get(Uri.parse(filePath));
@override
Widget build(BuildContext context) {
  return SizedBox(
      height:200,
      child:MicrosoftViewer(response.bodyBytes,true)
  );
}
```

## Additional information

Microsoft office files are created on a proprietary logic and needs a lot of research to understand it.

Hence building this package needs a lot of effort to understand the logic and then convert them into Flutter widgets.

There are many 3rd party SDKs available with complex features but charge heavily for the same.

Most of the Flutter developer need just the simple viewer functionality and this package is built with that requirement.

Any financial support or knowledge sharing or effort sharing will help in building this package faster.
