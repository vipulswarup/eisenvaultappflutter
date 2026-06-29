import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:microsoft_viewer/models/presentation.dart';
import 'package:microsoft_viewer/models/presentation_color_schemes.dart';
import 'package:microsoft_viewer/models/presentation_custom_diagram.dart';
import 'package:microsoft_viewer/models/presentation_preset_shapes.dart';
import 'package:microsoft_viewer/models/relationship.dart';
import 'package:microsoft_viewer/models/slide_layout.dart';
import 'package:microsoft_viewer/widget/custom_diagram.dart';
import 'package:microsoft_viewer/widget/preset_diagram.dart';
import 'package:microsoft_viewer/widget/preset_parallelogram.dart';
import 'package:xml/xml.dart' as xml;

import '../models/presentation_paragraph.dart';
import '../models/presentation_shape.dart';
import '../models/presentation_text.dart';
import '../models/presentation_text_box.dart';
import '../models/slide.dart';
import '../models/web_images.dart';

///Class for processing .pptx files
class PresentationProcessor {
  ///Function for processing .pptx file
  void getPresentationDetails(ArchiveFile presentationFile, Presentation presentation) {
    final fileContent = utf8.decode(presentationFile.content);
    final presentationDoc = xml.XmlDocument.parse(fileContent);
    var slidesRoot = presentationDoc.findAllElements("p:sldIdLst");
    if (slidesRoot.isNotEmpty) {
      var slides = slidesRoot.first.findAllElements("p:sldId");
      if (slides.isNotEmpty) {
        for (var slide in slides) {
          int id = 0;
          String rId = "";
          var tempId = slide.getAttribute("id");
          if (tempId != null) {
            id = int.parse(tempId);
          }
          var tempRid = slide.getAttribute("r:id");
          if (tempRid != null) {
            rId = tempRid;
          }
          presentation.slides.add(Slide(id, rId, ""));
        }
      }
    }
    var slideSz = presentationDoc.findAllElements("p:sldSz");
    if (slideSz.isNotEmpty) {
      var tempCX = slideSz.first.getAttribute("cx");
      if (tempCX != null) {
        presentation.width = int.parse(tempCX);
      }
      var tempCY = slideSz.first.getAttribute("cy");
      if (tempCY != null) {
        presentation.height = int.parse(tempCY);
      }
    }
    var masterSlidesRoot = presentationDoc.findAllElements("p:sldMasterIdLst");
    if (masterSlidesRoot.isNotEmpty) {
      var masterSlides = masterSlidesRoot.first.findAllElements("p:sldMasterId");
      if (masterSlides.isNotEmpty) {
        for (var slide in masterSlides) {
          int id = 0;
          String rId = "";
          var tempId = slide.getAttribute("id");
          if (tempId != null) {
            id = int.parse(tempId);
          }
          var tempRid = slide.getAttribute("r:id");
          if (tempRid != null) {
            rId = tempRid;
          }
          presentation.masterSlides.add(Slide(id, rId, ""));
        }
      }
    }
  }

  ///Function for processing all shapes
  void getAllShapes(ArchiveFile presentationFile, Slide slide) {
    final fileContent = utf8.decode(presentationFile.content);
    final diagramDoc = xml.XmlDocument.parse(fileContent);
    var diagramsRoot = diagramDoc.findAllElements("dsp:sp");
    if (diagramsRoot.isNotEmpty) {
      for (var diagram in diagramsRoot) {
        String id = "";
        String text = "";
        double offsety = 0;
        Offset offset = const Offset(0, 0);
        Size size = const Size(0, 0);
        var tempId = diagram.getAttribute("modelId");
        if (tempId != null) {
          id = tempId;
        }
        var checkTxtBody = diagram.findAllElements("dsp:txBody");
        if (checkTxtBody.isNotEmpty) {
          var checkParaElement = checkTxtBody.first.findAllElements("a:p");
          if (checkParaElement.isNotEmpty) {
            var txtElement = checkParaElement.first.findAllElements("a:t");
            if (txtElement.isNotEmpty) {
              text = txtElement.first.innerText;
            }
          }
        }
        var checkSlFrm = diagram.findAllElements("a:xfrm");
        if (checkSlFrm.isNotEmpty) {
          var checkOffE = checkSlFrm.first.findAllElements("a:off");
          if (checkOffE.isNotEmpty) {
            var tempX = checkOffE.first.getAttribute("x");
            if (tempX != null) {}
            var tempY = checkOffE.first.getAttribute("y");
            if (tempY != null) {
              offsety = double.parse(tempY);
            }
          }
        }

        var checkTxFrm = diagram.findAllElements("dsp:txXfrm");
        if (checkTxFrm.isNotEmpty) {
          var checkOffE = checkTxFrm.first.findAllElements("a:off");
          if (checkOffE.isNotEmpty) {
            double x = 0;
            double y = 0;
            var tempX = checkOffE.first.getAttribute("x");
            if (tempX != null) {
              x = double.parse(tempX);
            }
            var tempY = checkOffE.first.getAttribute("y");
            if (tempY != null) {
              y = double.parse(tempY);
            }
            offset = Offset(x, y + offsety);
          }
          var checkExtE = checkTxFrm.first.findAllElements("a:ext");
          if (checkExtE.isNotEmpty) {
            double x = 0;
            double y = 0;
            var tempX = checkExtE.first.getAttribute("cx");
            if (tempX != null) {
              x = double.parse(tempX);
            }
            var tempY = checkExtE.first.getAttribute("cy");
            if (tempY != null) {
              y = double.parse(tempY);
            }
            size = Size(x, y);
          }
        }
        slide.components.add(PresentationShape(id, text, offset, size));
      }
    }
  }

  ///Function for processing slides
  Future<void> readAllSlides(Presentation presentation, List<Relationship> relationShips, Archive archive, String presentationOutputDirectory) async {
    for (int i = 0; i < presentation.slides.length; i++) {
      var slideRelation = relationShips.firstWhereOrNull((rel) {
        return rel.id == presentation.slides[i].rId;
      });
      if (slideRelation != null) {
        var slideFile = archive.singleWhere((archiveFile) {
          return archiveFile.name.endsWith(slideRelation.target);
        });
        if (slideFile.isFile) {
          final fileContent = utf8.decode(slideFile.content);
          final slideDoc = xml.XmlDocument.parse(fileContent);
          presentation.slides[i].fileName = slideFile.name.split("/").last;
          var spElement = slideDoc.findAllElements("p:sp");
          if (spElement.isNotEmpty) {
            for (int j = 0; j < spElement.length; j++) {
              var checkCustomDiagram = spElement.elementAt(j).findAllElements("a:custGeom");
              if (checkCustomDiagram.isNotEmpty) {
                var pathListElement = checkCustomDiagram.first.findAllElements("a:pathLst");
                if (pathListElement.isNotEmpty) {
                  double offsetX = 0;
                  double offsetY = 0;
                  int width = 0;
                  int height = 0;
                  String clrScheme = "";
                  String srgbClr = "";
                  int rotate = 0;
                  int flipH = 0;
                  int flipV = 0;
                  String lumMod = "";
                  String lumOff = "";
                  Map<String, double> offsetValue = {"offsetX": offsetX, "offsetY": offsetY};
                  Map<String, int> rotFlip = {"rot": rotate, "flipH": flipH, "flipV": flipV};
                  Map<String, int> widthHeight = {"width": width, "height": height};
                  Map<String, String> colorDetails = {"clrScheme": clrScheme, "lumMod": lumMod, "lumOff": lumOff, "srgbClr": srgbClr};
                  getGroupDetails(spElement.elementAt(j), offsetValue, rotFlip, widthHeight, colorDetails);
                  offsetX = offsetValue["offsetX"]!;
                  offsetY = offsetValue["offsetY"]!;
                  rotate = rotFlip["rot"]!;
                  flipH = rotFlip["flipH"]!;
                  flipV = rotFlip["flipV"]!;
                  width = widthHeight["width"]!;
                  height = widthHeight["height"]!;
                  clrScheme = colorDetails["clrScheme"]!;
                  lumMod = colorDetails["lumMod"]!;
                  lumOff = colorDetails["lumOff"]!;
                  srgbClr = colorDetails["srgbClr"]!;
                  /*if (spElement.elementAt(j).parentElement != null &&
                      spElement.elementAt(j).parentElement?.name.toString() == "p:grpSp") {
                    var grpSpPr = spElement.elementAt(j).parentElement?.findAllElements("p:grpSpPr");
                    if (grpSpPr != null && grpSpPr.isNotEmpty) {
                      var chckOff = grpSpPr.first.findAllElements("a:off");
                      if (chckOff.isNotEmpty) {
                        var offX = chckOff.first.getAttribute("x");
                        if (offX != null) {
                          offsetX = double.parse(offX);
                        }
                        var offY = chckOff.first.getAttribute("y");
                        if (offY != null) {
                          offsetY = double.parse(offY);
                        }
                      }
                      var chkChOff=grpSpPr.first.findAllElements("a:chOff");
                      if(chkChOff.isNotEmpty){
                        //print("a:chOff");
                        //print(chkChOff);
                        var offX=chkChOff.first.getAttribute("x");
                        if(offX!=null){
                          //print(offsetX);
                          offsetX=offsetX-double.parse(offX);
                          //print(offsetX);
                        }
                        var offY=chkChOff.first.getAttribute("y");
                        if(offY!=null){
                          //print(offsetY);
                          offsetY=offsetY-double.parse(offY);
                          //print(offsetY);
                        }
                      }
                    }
                  }*/

                  var xfrmElement = spElement.elementAt(j).findAllElements("a:xfrm");
                  if (xfrmElement.isNotEmpty) {
                    var chkOff = xfrmElement.first.findAllElements("a:off");
                    if (chkOff.isNotEmpty) {
                      var offX = chkOff.first.getAttribute("x");
                      var offY = chkOff.first.getAttribute("y");
                      if (offX != null && offY != null) {
                        offsetX = double.parse(offX) + offsetX;
                        offsetY = double.parse(offY) + offsetY;
                      }
                    }
                    var chkExt = xfrmElement.first.findAllElements("a:ext");
                    if (chkExt.isNotEmpty) {
                      var tempWidth = chkExt.first.getAttribute("cx");
                      var tempHeight = chkExt.first.getAttribute("cy");
                      if (tempWidth != null && tempHeight != null) {
                        width = int.parse(tempWidth);
                        height = int.parse(tempHeight);
                      }
                    }
                    var chkRotate = xfrmElement.first.getAttribute("rot");
                    if (chkRotate != null) {
                      rotate = rotate + int.parse(chkRotate) ~/ 60000;
                    }
                    var chkFlipH = xfrmElement.first.getAttribute("flipH");
                    if (chkFlipH != null) {
                      if (chkFlipH == "1") {
                        flipH = 1;
                      }
                    }
                    var chkFlipV = xfrmElement.first.getAttribute("flipV");
                    if (chkFlipV != null) {
                      if (chkFlipV == "1") {
                        flipV = 1;
                      }
                    }
                  }

                  var chkSpPr = spElement.elementAt(j).findAllElements("p:spPr");
                  if (chkSpPr.isNotEmpty) {
                    var chkSolidFill = chkSpPr.first.findAllElements("a:solidFill");
                    if (chkSolidFill.isNotEmpty) {
                      var chkSchemeClr = chkSolidFill.first.findAllElements("a:schemeClr");
                      if (chkSchemeClr.isNotEmpty) {
                        var tempVal = chkSchemeClr.first.getAttribute("val");
                        if (tempVal != null) {
                          clrScheme = tempVal;
                        }
                        var chkLumMod = chkSchemeClr.first.findAllElements("a:lumMod");
                        if (chkLumMod.isNotEmpty) {
                          var tempLumMod = chkLumMod.first.getAttribute("val");
                          if (tempLumMod != null) {
                            lumMod = tempLumMod;
                          }
                        }
                        var chkLumOff = chkSchemeClr.first.findAllElements("a:lumOff");
                        if (chkLumOff.isNotEmpty) {
                          var tempLumOff = chkLumOff.first.getAttribute("val");
                          if (tempLumOff != null) {
                            lumOff = tempLumOff;
                          }
                        }
                      }
                      var chkRGBClr = chkSolidFill.first.findAllElements("a:srgbClr");
                      if (chkRGBClr.isNotEmpty) {
                        var tempVal = chkRGBClr.first.getAttribute("val");
                        if (tempVal != null) {
                          srgbClr = tempVal;
                        }
                      }
                    }
                  }
                  var pathElement = pathListElement.first.findAllElements("a:path");
                  var pathChildElements = pathElement.first.childElements;
                  PresentationCustomDiagram presentationCustomDiagram = PresentationCustomDiagram(offsetX, offsetY, width, height);
                  presentationCustomDiagram.clrScheme = clrScheme;
                  presentationCustomDiagram.srgbClr = srgbClr;
                  if (rotate != 0) {
                    presentationCustomDiagram.rotate = rotate;
                  }
                  if (flipH == 1) {
                    presentationCustomDiagram.flipH = "1";
                  }
                  if (flipV == 1) {
                    presentationCustomDiagram.flipV = "1";
                  }
                  if (lumOff.isNotEmpty) {
                    presentationCustomDiagram.lumOff = lumOff;
                  }
                  if (lumMod.isNotEmpty) {
                    presentationCustomDiagram.lumMod = lumMod;
                  }
                  for (var path in pathChildElements) {
                    List<Points> points = [];
                    var pt = path.findAllElements("a:pt");
                    if (pt.isNotEmpty) {
                      for(var pts in pt) {
                        points.add(Points(double.parse(pts.getAttribute("x") ?? "0"), double.parse(pts.getAttribute("y") ?? "0")));
                      }
                    }
                    if (points.isNotEmpty) {
                      PathAction pathAction = PathAction(points, path.localName);
                      presentationCustomDiagram.pathList.add(pathAction);
                    }
                  }
                  if (presentationCustomDiagram.pathList.isNotEmpty) {
                    presentation.slides[i].components.add(presentationCustomDiagram);
                  }
                }
              }

              var checkPresetShape = spElement.elementAt(j).findAllElements("a:prstGeom");
              if (checkPresetShape.isNotEmpty) {
                double offsetX = 0;
                double offsetY = 0;
                int width = 0;
                int height = 0;

                /*if (spElement.elementAt(j).parentElement != null &&
                    spElement.elementAt(j).parentElement?.name.toString() == "p:grpSp") {
                  var grpSpPr = spElement.elementAt(j).parentElement?.findAllElements("p:grpSpPr");
                  if (grpSpPr != null && grpSpPr.isNotEmpty) {
                    var chckOff = grpSpPr.first.findAllElements("a:off");
                    if (chckOff.isNotEmpty) {
                      var offX = chckOff.first.getAttribute("x");
                      if (offX != null) {
                        offsetX = double.parse(offX);
                      }
                      var offY = chckOff.first.getAttribute("y");
                      if (offY != null) {
                        offsetY = double.parse(offY);
                      }
                    }
                    var chkChOff=grpSpPr.first.findAllElements("a:chOff");
                    if(chkChOff.isNotEmpty){
                      //print("a:chOff");
                      //print(chkChOff);
                      var offX=chkChOff.first.getAttribute("x");
                      if(offX!=null){
                        //print(offsetX);
                        offsetX=offsetX-double.parse(offX);
                        //print(offsetX);
                      }
                      var offY=chkChOff.first.getAttribute("y");
                      if(offY!=null){
                        //print(offsetY);
                        offsetY=offsetY-double.parse(offY);
                        //print(offsetY);
                      }
                    }

                  }
                }*/

                String fillClrScheme = "";
                String lumMod = "";
                String lumOff = "";
                String srgbClr = "";
                int rotate = 0;
                int flipH = 0;
                int flipV = 0;
                Map<String, double> offsetValue = {"offsetX": offsetX, "offsetY": offsetY};
                Map<String, int> rotFlip = {"rot": rotate, "flipH": flipH, "flipV": flipV};
                Map<String, int> widthHeight = {"width": width, "height": height};
                Map<String, String> colorDetails = {"clrScheme": fillClrScheme, "lumMod": lumMod, "lumOff": lumOff, "srgbClr": srgbClr};
                getGroupDetails(spElement.elementAt(j), offsetValue, rotFlip, widthHeight, colorDetails);

                offsetX = offsetValue["offsetX"]!;
                offsetY = offsetValue["offsetY"]!;
                rotate = rotFlip["rot"]!;
                flipH = rotFlip["flipH"]!;
                flipV = rotFlip["flipV"]!;
                width = widthHeight["width"]!;
                height = widthHeight["height"]!;
                fillClrScheme = colorDetails["clrScheme"]!;
                lumMod = colorDetails["lumMod"]!;
                lumOff = colorDetails["lumOff"]!;
                srgbClr = colorDetails["srgbClr"]!;

                var xfrmElement = spElement.elementAt(j).findAllElements("a:xfrm");
                if (xfrmElement.isNotEmpty) {
                  var chkOff = xfrmElement.first.findAllElements("a:off");
                  if (chkOff.isNotEmpty) {
                    var offX = chkOff.first.getAttribute("x");
                    var offY = chkOff.first.getAttribute("y");
                    if (offX != null && offY != null) {
                      offsetX = double.parse(offX) + offsetX;
                      offsetY = double.parse(offY) + offsetY;
                    }
                  }

                  var chkExt = xfrmElement.first.findAllElements("a:ext");
                  if (chkExt.isNotEmpty) {
                    var extX = chkExt.first.getAttribute("cx");
                    var extY = chkExt.first.getAttribute("cy");
                    if (extX != null && extY != null) {
                      width = int.parse(extX);
                      height = int.parse(extY);

                      //size = Size(double.parse(extX), double.parse(extY));
                    }
                  }

                  var chkRotate = xfrmElement.first.getAttribute("rot");
                  if (chkRotate != null) {
                    rotate = rotate + (int.parse(chkRotate) ~/ 60000);
                  }
                  var chkFlipH = xfrmElement.first.getAttribute("flipH");
                  if (chkFlipH != null) {
                    if (chkFlipH == "1") {
                      flipH = 1;
                    }
                  }
                  var chkFlipV = xfrmElement.first.getAttribute("flipV");
                  if (chkFlipV != null) {
                    if (chkFlipV == "1") {
                      flipV = 1;
                    }
                  }
                }
                String presetShapeType = "";
                String adjVal = "";

                String adjVal2 = "";
                String adjVal3 = "";
                var chkPresetShapeType = checkPresetShape.first.getAttribute("prst");
                if (chkPresetShapeType != null) {
                  presetShapeType = chkPresetShapeType;
                  if (chkPresetShapeType == "rect" || chkPresetShapeType == "roundRect" || chkPresetShapeType == "ellipse") {
                    if ((width + widthHeight["width"]!) > 0 && (height + widthHeight["height"]!) > 0) {
                      width = width + widthHeight["width"]!;
                      height = height + widthHeight["height"]!;
                    }
                  }
                }
                var chkPresetAdjVal = checkPresetShape.first.findAllElements("a:gd");
                if (chkPresetAdjVal.isNotEmpty) {
                  var checkFormula = chkPresetAdjVal.first.getAttribute("fmla");
                  if (checkFormula != null) {
                    adjVal = checkFormula;
                  }
                  if (chkPresetAdjVal.length > 1) {
                    var checkFormula2 = chkPresetAdjVal.elementAt(1).getAttribute("fmla");
                    if (checkFormula2 != null) {
                      adjVal2 = checkFormula2;
                    }
                  }
                  if (chkPresetAdjVal.length > 2) {
                    var checkFormula3 = chkPresetAdjVal.elementAt(2).getAttribute("fmla");
                    if (checkFormula3 != null) {
                      adjVal3 = checkFormula3;
                    }
                  }
                }
                var chkShapePr = spElement.elementAt(j).findAllElements("p:spPr");
                if (chkShapePr.isNotEmpty) {
                  var chkSolidFill = chkShapePr.first.findAllElements("a:solidFill");
                  if (chkSolidFill.isNotEmpty) {
                    var chkSchemeClr = chkSolidFill.first.findAllElements("a:schemeClr");
                    if (chkSchemeClr.isNotEmpty) {
                      var tempVal = chkSchemeClr.first.getAttribute("val");
                      if (tempVal != null) {
                        fillClrScheme = tempVal;
                      }
                      var chkLumMod = chkSchemeClr.first.findAllElements("a:lumMod");
                      if (chkLumMod.isNotEmpty) {
                        var tempLumMod = chkLumMod.first.getAttribute("val");
                        if (tempLumMod != null) {
                          lumMod = tempLumMod;
                        }
                      }
                      var chkLumOff = chkSchemeClr.first.findAllElements("a:lumOff");
                      if (chkLumOff.isNotEmpty) {
                        var tempLumOff = chkLumOff.first.getAttribute("val");
                        if (tempLumOff != null) {
                          lumOff = tempLumOff;
                        }
                      }
                    }
                  } else {
                    var chkPStyle = spElement.elementAt(j).findAllElements("p:style");
                    if (chkPStyle.isNotEmpty) {
                      var chkFillRef = chkPStyle.first.findAllElements("a:fillRef");
                      if (chkFillRef.isNotEmpty) {
                        var chkSchemeClr = chkFillRef.first.findAllElements("a:schemeClr");
                        if (chkSchemeClr.isNotEmpty) {
                          var tempVal = chkSchemeClr.first.getAttribute("val");
                          if (tempVal != null) {
                            fillClrScheme = tempVal;
                          }
                          var chkLumMod = chkSchemeClr.first.findAllElements("a:lumMod");
                          if (chkLumMod.isNotEmpty) {
                            var tempLumMod = chkLumMod.first.getAttribute("val");
                            if (tempLumMod != null) {
                              lumMod = tempLumMod;
                            }
                          }
                          var chkLumOff = chkSchemeClr.first.findAllElements("a:lumOff");
                          if (chkLumOff.isNotEmpty) {
                            var tempLumOff = chkLumOff.first.getAttribute("val");
                            if (tempLumOff != null) {
                              lumOff = tempLumOff;
                            }
                          }
                        }
                      }
                    }
                  }
                }
                //var chkIsTextBox = spElement.elementAt(j).findAllElements("a:t");
                //if(chkIsTextBox.isEmpty) {
                PresentationPresetShapes presentationPresetShapes = PresentationPresetShapes(presetShapeType, adjVal, fillClrScheme);
                presentationPresetShapes.top = offsetY;
                presentationPresetShapes.left = offsetX;
                presentationPresetShapes.width = width;
                presentationPresetShapes.height = height;
                if (adjVal2.isNotEmpty) {
                  presentationPresetShapes.adjValue2 = adjVal2;
                }
                if (adjVal3.isNotEmpty) {
                  presentationPresetShapes.adjValue3 = adjVal3;
                }
                if (rotate != 0) {
                  presentationPresetShapes.rotate = rotate;
                }
                if (flipH == 1) {
                  presentationPresetShapes.flipH = "1";
                }
                if (flipV == 1) {
                  presentationPresetShapes.flipV = "1";
                }
                if (lumOff.isNotEmpty) {
                  presentationPresetShapes.lumOff = lumOff;
                }
                if (lumMod.isNotEmpty) {
                  presentationPresetShapes.lumMod = lumMod;
                }
                presentation.slides[i].components.add(presentationPresetShapes);
                //}
              }
              var checkTextBody = spElement.elementAt(j).findAllElements("p:txBody");
              if (checkTextBody.isNotEmpty) {
                var tempTextBox =
                    await compute(getPresentationTextBox, GetPresentationTextBoxParam(spElement.elementAt(j), presentation.slides[i].clearMap));
                if (tempTextBox != null) {
                  presentation.slides[i].components.add(tempTextBox);
                }
              }
            }
          }

          var checkSlideRel = archive.singleWhereOrNull((archiveFile) {
            return archiveFile.name.endsWith("${presentation.slides[i].fileName}.rels");
          });
          if (checkSlideRel != null) {
            List<Relationship> slideLevelRelations = [];
            final fileContent = utf8.decode(checkSlideRel.content);
            String drawingTarget = "";
            String layoutTarget = "";
            String slideMaster = "";
            final document = xml.XmlDocument.parse(fileContent);
            final relationshipsElement = document.findAllElements("Relationship");
            for (var rel in relationshipsElement) {
              if (rel.getAttribute("Id") != null) {
                slideLevelRelations.add(Relationship(rel.getAttribute("Id").toString(), rel.getAttribute("Target").toString()));
              }
              if (rel.getAttribute("Type") != null && rel.getAttribute("Type")!.endsWith("relationships/diagramDrawing")) {
                drawingTarget = rel.getAttribute("Target").toString().replaceAll("../", "");
              }
              if (rel.getAttribute("Type") != null && rel.getAttribute("Type")!.endsWith("relationships/slideLayout")) {
                layoutTarget = rel.getAttribute("Target").toString().replaceAll("../", "");
              }
            }
            if (drawingTarget.isNotEmpty) {
              var diagramFile = archive.singleWhereOrNull((archiveFile) {
                return archiveFile.name.endsWith(drawingTarget);
              });
              if (diagramFile != null) {
                getAllShapes(diagramFile, presentation.slides[i]);
              }
            }
            if (layoutTarget.isNotEmpty) {
              var checkLayoutRel = archive.singleWhereOrNull((archiveFile) {
                return archiveFile.name.endsWith("${layoutTarget.split("/").last}.rels");
              });
              List<Relationship> layoutRelations = [];
              if (checkLayoutRel != null) {
                final fileContent2 = utf8.decode(checkLayoutRel.content);
                final document2 = xml.XmlDocument.parse(fileContent2);
                final relationshipsElement2 = document2.findAllElements("Relationship");

                for (var rel in relationshipsElement2) {
                  if (rel.getAttribute("Id") != null) {
                    //print(rel.getAttribute("Id"));
                    //print(rel.getAttribute("Target"));
                    if (rel.getAttribute("Type") != null) {
                      if (rel.getAttribute("Type")!.endsWith("relationships/slideMaster")) {
                        if (rel.getAttribute("Target") != null) {
                          slideMaster = rel.getAttribute("Target")!.replaceAll("../", "");
                        }
                      }
                    }
                    layoutRelations.add(Relationship(rel.getAttribute("Id").toString(), rel.getAttribute("Target").toString()));
                  }
                }
              }
              //print(i);
              //print(layoutTarget);
              var layoutFile = archive.singleWhereOrNull((archiveFile) {
                return archiveFile.name.endsWith(layoutTarget);
              });
              if (layoutFile != null) {
                //print("0.5");
                final fileContent3 = utf8.decode(layoutFile.content);
                final document3 = xml.XmlDocument.parse(fileContent3);
                var chkBg = document3.findAllElements("p:bg");
                if (chkBg.isNotEmpty) {
                  var chkBlip = chkBg.first.findAllElements("a:blip");
                  if (chkBlip.isNotEmpty) {
                    var chkEmbed = chkBlip.first.getAttribute("r:embed");
                    if (chkEmbed != null) {
                      var layoutRelTarget = layoutRelations.firstWhereOrNull((rel) {
                        return rel.id == chkEmbed;
                      });
                      if (layoutRelTarget != null) {
                        //print(layoutRelTarget.target.split("/").last);
                        if(kIsWeb){
                          presentation.slides[i].backgroundImagePath = layoutRelTarget.target
                              .split("/")
                              .last;
                        }else {
                          presentation.slides[i].backgroundImagePath = "$presentationOutputDirectory/${layoutRelTarget.target
                              .split("/")
                              .last}";
                        }
                      }
                    }
                  }
                }
                var chkShape = document3.findAllElements("p:sp");
                if (chkShape.isNotEmpty) {
                  //print("1");
                  SlideLayout slideLayout = SlideLayout();
                  for (var shapeElement in chkShape) {
                    //print("2");
                    var chkPara = shapeElement.findAllElements("p:ph");
                    if (chkPara.isNotEmpty) {
                      //print("3");
                      String type = "", idx = "", sz = "", anchor = "", schemeClr = "";
                      int defaultSz = 0;
                      var tempType = chkPara.first.getAttribute("type");
                      if (tempType != null) {
                        type = tempType;
                      }
                      var tempIdx = chkPara.first.getAttribute("idx");
                      if (tempIdx != null) {
                        idx = tempIdx;
                      }
                      var tempSz = chkPara.first.getAttribute("sz");
                      if (tempSz != null) {
                        sz = tempSz;
                      }
                      var chkBodyPr = shapeElement.findAllElements("a:bodyPr");
                      if (chkBodyPr.isNotEmpty) {
                        var tempAnchor = chkBodyPr.first.getAttribute("anchor");
                        if (tempAnchor != null) {
                          anchor = tempAnchor;
                        }
                      }
                      var chkDefaultRPr = shapeElement.findAllElements("a:defRPr");
                      if (chkDefaultRPr.isNotEmpty) {
                        var tempDefaultSz = chkDefaultRPr.first.getAttribute("sz");
                        if (tempDefaultSz != null) {
                          defaultSz = int.parse(tempDefaultSz);
                        }
                      }
                      //print("type");
                      //print(type);
                      //print("idx");
                      //print(idx);
                      SlideLayoutParagraph paragraph = SlideLayoutParagraph(type, idx, sz, anchor, schemeClr, defaultSz);
                      var xfrmElement = shapeElement.findAllElements("a:xfrm");
                      if (xfrmElement.isNotEmpty) {
                        var chkOff = xfrmElement.first.findAllElements("a:off");
                        if (chkOff.isNotEmpty) {
                          var offX = chkOff.first.getAttribute("x");
                          var offY = chkOff.first.getAttribute("y");
                          if (offX != null && offY != null) {
                            paragraph.x = double.parse(offX);
                            paragraph.y = double.parse(offY);
                          }
                        }
                        var chkExt = xfrmElement.first.findAllElements("a:ext");
                        if (chkExt.isNotEmpty) {
                          var extX = chkExt.first.getAttribute("cx");
                          var extY = chkExt.first.getAttribute("cy");
                          if (extX != null && extY != null) {
                            paragraph.width = int.parse(extX);
                            paragraph.height = int.parse(extY);
                          }
                        }
                      }
                      slideLayout.paragraphs.add(paragraph);
                    }
                    var checkPresetShape = shapeElement.findAllElements("a:prstGeom");
                    if (checkPresetShape.isNotEmpty) {
                      double offsetX = 0;
                      double offsetY = 0;
                      int width = 0;
                      int height = 0;

                      /*if (shapeElement.parentElement != null &&
                          shapeElement.parentElement?.name.toString() == "p:grpSp") {
                        var grpSpPr = shapeElement.parentElement?.findAllElements("p:grpSpPr");
                        if (grpSpPr != null && grpSpPr.isNotEmpty) {
                          var chckOff = grpSpPr.first.findAllElements("a:off");
                          if (chckOff.isNotEmpty) {
                            var offX = chckOff.first.getAttribute("x");
                            if (offX != null) {
                              offsetX = double.parse(offX);
                            }
                            var offY = chckOff.first.getAttribute("y");
                            if (offY != null) {
                              offsetY = double.parse(offY);
                            }
                          }
                          var chkChOff=grpSpPr.first.findAllElements("a:chOff");
                          if(chkChOff.isNotEmpty){
                            //print("a:chOff");
                            //print(chkChOff);
                            var offX=chkChOff.first.getAttribute("x");
                            if(offX!=null){
                              //print(offsetX);
                              offsetX=offsetX-double.parse(offX);
                              //print(offsetX);
                            }
                            var offY=chkChOff.first.getAttribute("y");
                            if(offY!=null){
                              //print(offsetY);
                              offsetY=offsetY-double.parse(offY);
                              //print(offsetY);
                            }
                          }

                        }
                      }*/

                      var xfrmElement = shapeElement.findAllElements("a:xfrm");
                      if (xfrmElement.isNotEmpty) {
                        var chkOff = xfrmElement.first.findAllElements("a:off");
                        if (chkOff.isNotEmpty) {
                          var offX = chkOff.first.getAttribute("x");
                          var offY = chkOff.first.getAttribute("y");
                          if (offX != null && offY != null) {
                            offsetX = double.parse(offX) + offsetX;
                            offsetY = double.parse(offY) + offsetY;
                          }
                        }
                        var chkExt = xfrmElement.first.findAllElements("a:ext");
                        if (chkExt.isNotEmpty) {
                          var extX = chkExt.first.getAttribute("cx");
                          var extY = chkExt.first.getAttribute("cy");
                          if (extX != null && extY != null) {
                            width = int.parse(extX);
                            height = int.parse(extY);
                            //size = Size(double.parse(extX), double.parse(extY));
                          }
                        }
                      }
                      String presetShapeType = "";
                      String adjVal = "";
                      String fillClrScheme = "";
                      String lumMod = "";
                      String lumOff = "";
                      var chkPresetShapeType = checkPresetShape.first.getAttribute("prst");
                      if (chkPresetShapeType != null) {
                        presetShapeType = chkPresetShapeType;
                      }
                      var chkPresetAdjVal = checkPresetShape.first.findAllElements("a:gd");
                      if (chkPresetAdjVal.isNotEmpty) {
                        var checkFormula = chkPresetAdjVal.first.getAttribute("fmla");
                        if (checkFormula != null) {
                          adjVal = checkFormula;
                        }
                      }
                      var chkSpPr = shapeElement.findAllElements("p:spPr");
                      if (chkSpPr.isNotEmpty) {
                        var chkSolidFill = chkSpPr.first.findAllElements("a:solidFill");
                        if (chkSolidFill.isNotEmpty) {
                          var chkSchemeClr = chkSolidFill.first.findAllElements("a:schemeClr");
                          if (chkSchemeClr.isNotEmpty) {
                            var tempVal = chkSchemeClr.first.getAttribute("val");
                            if (tempVal != null) {
                              fillClrScheme = tempVal;
                            }
                            var chkLumMod = chkSchemeClr.first.findAllElements("a:lumMod");
                            if (chkLumMod.isNotEmpty) {
                              var tempLumMod = chkLumMod.first.getAttribute("val");
                              if (tempLumMod != null) {
                                lumMod = tempLumMod;
                              }
                            }
                            var chkLumOff = chkSchemeClr.first.findAllElements("a:lumOff");
                            if (chkLumOff.isNotEmpty) {
                              var tempLumOff = chkLumOff.first.getAttribute("val");
                              if (tempLumOff != null) {
                                lumOff = tempLumOff;
                              }
                            }
                          }
                        } else {
                          var chkFillRef = chkSpPr.first.findAllElements("a:fillRef");
                          if (chkFillRef.isNotEmpty) {
                            var chkSchemeClr = chkFillRef.first.findAllElements("a:schemeClr");
                            if (chkSchemeClr.isNotEmpty) {
                              var tempVal = chkSchemeClr.first.getAttribute("val");
                              if (tempVal != null) {
                                fillClrScheme = tempVal;
                              }
                              var chkLumMod = chkSchemeClr.first.findAllElements("a:lumMod");
                              if (chkLumMod.isNotEmpty) {
                                var tempLumMod = chkLumMod.first.getAttribute("val");
                                if (tempLumMod != null) {
                                  lumMod = tempLumMod;
                                }
                              }
                              var chkLumOff = chkSchemeClr.first.findAllElements("a:lumOff");
                              if (chkLumOff.isNotEmpty) {
                                var tempLumOff = chkLumOff.first.getAttribute("val");
                                if (tempLumOff != null) {
                                  lumOff = tempLumOff;
                                }
                              }
                            }
                          }
                        }
                      }
                      //var chkIsTextBox=shapeElement.findAllElements("a:t");
                      //if(chkIsTextBox.isEmpty) {
                      PresentationPresetShapes presentationPresetShapes = PresentationPresetShapes(presetShapeType, adjVal, fillClrScheme);
                      presentationPresetShapes.top = offsetY;
                      presentationPresetShapes.left = offsetX;
                      presentationPresetShapes.width = width;
                      presentationPresetShapes.height = height;
                      var chkPh = shapeElement.findAllElements("p:ph");
                      if (chkPh.isNotEmpty) {
                        //print(chkPh);
                        var type = chkPh.first.getAttribute("type");
                        if (type != null) {
                          presentationPresetShapes.phType = type;
                        }
                        var idx = chkPh.first.getAttribute("idx");
                        if (idx != null) {
                          presentationPresetShapes.idx = idx;
                        }
                      }
                      if (lumOff.isNotEmpty) {
                        presentationPresetShapes.lumOff = lumOff;
                      }
                      if (lumMod.isNotEmpty) {
                        presentationPresetShapes.lumMod = lumMod;
                      }
                      slideLayout.components.add(presentationPresetShapes);
                      //}
                    }
                    var checkCustomDiagram = shapeElement.findAllElements("a:custGeom");
                    if (checkCustomDiagram.isNotEmpty) {
                      var pathListElement = checkCustomDiagram.first.findAllElements("a:pathLst");
                      if (pathListElement.isNotEmpty) {
                        double offsetX = 0;
                        double offsetY = 0;
                        int width = 0;
                        int height = 0;
                        String clrScheme = "";
                        String lumMod = "";
                        String lumOff = "";
                        String srgbClr = "";
                        int rotate = 0;
                        int flipH = 0;
                        int flipV = 0;
                        Map<String, double> offsetValue = {"offsetX": offsetX, "offsetY": offsetY};
                        Map<String, int> rotFlip = {"rot": rotate, "flipH": flipH, "flipV": flipV};
                        Map<String, int> widthHeight = {"width": width, "height": height};
                        Map<String, String> colorDetails = {"clrScheme": clrScheme, "lumMod": lumMod, "lumOff": lumOff, "srgbClr": srgbClr};
                        getGroupDetails(shapeElement, offsetValue, rotFlip, widthHeight, colorDetails);
                        offsetX = offsetValue["offsetX"]!;
                        offsetY = offsetValue["offsetY"]!;
                        rotate = rotFlip["rot"]!;
                        flipH = rotFlip["flipH"]!;
                        flipV = rotFlip["flipV"]!;
                        width = widthHeight["width"]!;
                        height = widthHeight["height"]!;
                        clrScheme = colorDetails["clrScheme"]!;
                        lumMod = colorDetails["lumMod"]!;
                        lumOff = colorDetails["lumOff"]!;
                        srgbClr = colorDetails["srgbClr"]!;

                        var xfrmElement = shapeElement.findAllElements("a:xfrm");
                        if (xfrmElement.isNotEmpty) {
                          var chkOff = xfrmElement.first.findAllElements("a:off");
                          if (chkOff.isNotEmpty) {
                            var offX = chkOff.first.getAttribute("x");
                            var offY = chkOff.first.getAttribute("y");
                            if (offX != null && offY != null) {
                              offsetX = double.parse(offX) + offsetX;
                              offsetY = double.parse(offY) + offsetY;
                            }
                          }
                          var chkExt = xfrmElement.first.findAllElements("a:ext");
                          if (chkExt.isNotEmpty) {
                            var tempWidth = chkExt.first.getAttribute("cx");
                            var tempHeight = chkExt.first.getAttribute("cy");
                            if (tempWidth != null && tempHeight != null) {
                              width = int.parse(tempWidth);
                              height = int.parse(tempHeight);
                            }
                          }
                          var chkRotate = xfrmElement.first.getAttribute("rot");
                          if (chkRotate != null) {
                            rotate = rotate + (int.parse(chkRotate) ~/ 60000);
                          }
                          var chkFlipH = xfrmElement.first.getAttribute("flipH");
                          if (chkFlipH != null) {
                            if (chkFlipH == "1") {
                              flipH = 1;
                            }
                          }
                          var chkFlipV = xfrmElement.first.getAttribute("flipV");
                          if (chkFlipV != null) {
                            if (chkFlipV == "1") {
                              flipV = 1;
                            }
                          }
                        }

                        var chkSpPr = shapeElement.findAllElements("p:spPr");
                        if (chkSpPr.isNotEmpty) {
                          var chkSolidFill = chkSpPr.first.findAllElements("a:solidFill");
                          if (chkSolidFill.isNotEmpty) {
                            var chkSchemeClr = chkSolidFill.first.findAllElements("a:schemeClr");
                            if (chkSchemeClr.isNotEmpty) {
                              var tempVal = chkSchemeClr.first.getAttribute("val");
                              if (tempVal != null) {
                                clrScheme = tempVal;
                              }
                              var chkLumMod = chkSchemeClr.first.findAllElements("a:lumMod");
                              if (chkLumMod.isNotEmpty) {
                                var tempLumMod = chkLumMod.first.getAttribute("val");
                                if (tempLumMod != null) {
                                  lumMod = tempLumMod;
                                }
                              }
                              var chkLumOff = chkSchemeClr.first.findAllElements("a:lumOff");
                              if (chkLumOff.isNotEmpty) {
                                var tempLumOff = chkLumOff.first.getAttribute("val");
                                if (tempLumOff != null) {
                                  lumOff = tempLumOff;
                                }
                              }
                            }
                            var chkRGBClr = chkSolidFill.first.findAllElements("a:srgbClr");
                            if (chkRGBClr.isNotEmpty) {
                              var tempVal = chkRGBClr.first.getAttribute("val");
                              if (tempVal != null) {
                                srgbClr = tempVal;
                              }
                            }
                          }
                        }
                        var pathElement = pathListElement.first.findAllElements("a:path");
                        var pathChildElements = pathElement.first.childElements;
                        PresentationCustomDiagram presentationCustomDiagram = PresentationCustomDiagram(offsetX, offsetY, width, height);
                        presentationCustomDiagram.clrScheme = clrScheme;
                        presentationCustomDiagram.srgbClr = srgbClr;
                        if (rotate != 0) {
                          presentationCustomDiagram.rotate = rotate;
                        }
                        if (flipH == 1) {
                          presentationCustomDiagram.flipH = "1";
                        }
                        if (flipV == 1) {
                          presentationCustomDiagram.flipV = "1";
                        }
                        if (lumOff.isNotEmpty) {
                          presentationCustomDiagram.lumOff = lumOff;
                        }
                        if (lumMod.isNotEmpty) {
                          presentationCustomDiagram.lumMod = lumMod;
                        }
                        for (var path in pathChildElements) {
                          List<Points> points = [];
                          var pt = path.findAllElements("a:pt");
                          if (pt.isNotEmpty) {
                            for (var pts in pt) {
                              points.add(Points(double.parse(pts.getAttribute("x") ?? "0"), double.parse(pts.getAttribute("y") ?? "0")));
                            }
                          }
                          if (points.isNotEmpty) {
                            PathAction pathAction = PathAction(points, path.localName);
                            presentationCustomDiagram.pathList.add(pathAction);
                          }
                        }
                        if (presentationCustomDiagram.pathList.isNotEmpty) {
                          slideLayout.components.add(presentationCustomDiagram);
                        }
                      }
                    }
                  }
                  presentation.slides[i].slideLayout = slideLayout;
                }
              }
              //print("slideMaster");
              //print(slideMaster.split("/").last+".rels");

              var slideMasterRelFile = archive.singleWhereOrNull((archiveFile) {
                //print(archiveFile.name);
                return archiveFile.name.endsWith("${slideMaster.split("/").last}.rels");
              });
              //print("slideMasterRelFile");
              //print(slideMasterRelFile);
              if (slideMasterRelFile != null) {
                final fileContent4 = utf8.decode(slideMasterRelFile.content);
                final document4 = xml.XmlDocument.parse(fileContent4);
                final relationshipsElement3 = document4.findAllElements("Relationship");
                String themeFile = "";
                for (var rel in relationshipsElement3) {
                  if (rel.getAttribute("Type") != null) {
                    if (rel.getAttribute("Type")!.endsWith("relationships/theme")) {
                      if (rel.getAttribute("Target") != null) {
                        themeFile = rel.getAttribute("Target")!.replaceAll("../", "");
                      }
                    }
                  }
                }
                // print("themeFile");
                //print(themeFile);
                if (themeFile.isNotEmpty) {
                  var selectedThemeFile = archive.singleWhereOrNull((archiveFile) {
                    return archiveFile.name.endsWith(themeFile);
                  });
                  if (selectedThemeFile != null) {
                    final fileContent5 = utf8.decode(selectedThemeFile.content);
                    final document5 = xml.XmlDocument.parse(fileContent5);
                    var chkColorScheme = document5.findAllElements("a:clrScheme");
                    if (chkColorScheme.isNotEmpty) {
                      for (var clrSch in chkColorScheme.first.childElements) {
                        String name = "", sysClrName = "", sysClrLast = "", srgbClr = "";
                        name = clrSch.name.local;
                        var chkSysClr = clrSch.findAllElements("a:sysClr");
                        if (chkSysClr.isNotEmpty) {
                          var tempClrName = chkSysClr.first.getAttribute("val");
                          if (tempClrName != null) {
                            sysClrName = tempClrName;
                          }
                          var tempClrLast = chkSysClr.first.getAttribute("lastClr");
                          if (tempClrLast != null) {
                            sysClrLast = tempClrLast;
                          }
                        }
                        var chksrgbClr = clrSch.findAllElements("a:srgbClr");
                        if (chksrgbClr.isNotEmpty) {
                          var tempSrgbClr = chksrgbClr.first.getAttribute("val");
                          if (tempSrgbClr != null) {
                            srgbClr = tempSrgbClr;
                          }
                        }
                        presentation.slides[i].colorSchemes.add(
                            PresentationColorSchemes(presentation.slides[i].colorSchemes.length.toString(), name, sysClrName, sysClrLast, srgbClr));
                      }
                    }
                  }
                }
              }
              var slideMasterFile = archive.singleWhereOrNull((archiveFile) {
                //print(archiveFile.name);
                return archiveFile.name.endsWith(slideMaster.split("/").last);
              });
              if (slideMasterFile != null) {
                final fileContent6 = utf8.decode(slideMasterFile.content);
                final document6 = xml.XmlDocument.parse(fileContent6);
                var chkClearMap = document6.findAllElements("p:clrMap");
                if (chkClearMap.isNotEmpty) {
                  //print(chkClearMap);
                  for (var attribute in chkClearMap.first.attributes) {
                    //print(attribute);
                    presentation.slides[i].clearMap[attribute.name.toString()] = attribute.value;
                    //print(presentation.slides[i].clearMap);
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  ///Function for displaying the presentations
  Future<List<Widget>> displayPresentation(Presentation presentation,List<WebImages> webImages) async {
    List<Widget> tempList = [];
    List<Widget> slideWidgets = [];
    for (int i = 0; i < presentation.slides.length; i++) {
      List<Widget> tempSlideWidget = await compute(getSlideDetails, GetSlideParam(presentation.slides[i], presentation.width, presentation.height,webImages));
      slideWidgets.addAll(tempSlideWidget);
    }
    tempList.add(Container(
      color: Colors.grey,
      width: 500,
      margin: const EdgeInsets.all(8),
      child: Column(
        children: slideWidgets,
      ),
    ));
    return tempList;
  }

  ///Function for getting slide details
  static List<Widget> getSlideDetails(GetSlideParam params) {
    List<Widget> tempSlide = [];
    List<Widget> tempShapes = [];
    List<Widget> slideWidget = [];
    double maxWidth = 600;
    double maxHeight = 450;
    double divisionFactor = 12700;
    if (params.slide.slideLayout != null) {
      for (int j = 0; j < params.slide.slideLayout!.components.length; j++) {
        Map<String, double> maxWidthHeight = {"maxWidth": maxWidth, "maxHeight": maxHeight};
        switch (params.slide.slideLayout!.components[j].runtimeType.toString()) {
          case "PresentationPresetShapes":
            List<Widget> tempGetShapes = showPresetShape(
                params.slide.slideLayout!.components[j], params.slide.clearMap, params.slide.colorSchemes, divisionFactor, maxWidthHeight);
            tempShapes.addAll(tempGetShapes);
            break;
          case "PresentationCustomDiagram":
            List<Widget> tempGetCustomDiagrams = showCustomDiagram(
                params.slide.slideLayout!.components[j], params.slide.clearMap, params.slide.colorSchemes, divisionFactor, maxWidthHeight);
            tempShapes.addAll(tempGetCustomDiagrams);
            break;
          case "PresentationTextBox":
            List<Widget> tempGetTextBoxes = showTextBox(params.slide.slideLayout!.components[j], divisionFactor, maxWidthHeight,
                params.slide.slideLayout, params.slide.clearMap, params.slide.colorSchemes);
            tempShapes.addAll(tempGetTextBoxes);
            break;
        }
        maxWidth = maxWidthHeight["maxWidth"]!;
        maxHeight = maxWidthHeight["maxHeight"]!;
      }

    }
    for (int j = 0; j < params.slide.components.length; j++) {
      Map<String, double> maxWidthHeight = {"maxWidth": maxWidth, "maxHeight": maxHeight};
      switch (params.slide.components[j].runtimeType.toString()) {
        case "PresentationPresetShapes":
          //print(params.slide.fileName);
          List<Widget> tempGetShapes =
              showPresetShape(params.slide.components[j], params.slide.clearMap, params.slide.colorSchemes, divisionFactor, maxWidthHeight);
          tempShapes.addAll(tempGetShapes);
          break;
        case "PresentationCustomDiagram":
          List<Widget> tempGetCustomDiagrams =
              showCustomDiagram(params.slide.components[j], params.slide.clearMap, params.slide.colorSchemes, divisionFactor, maxWidthHeight);
          tempShapes.addAll(tempGetCustomDiagrams);
          break;
        case "PresentationTextBox":
          List<Widget> tempGetTextBoxes = showTextBox(
              params.slide.components[j], divisionFactor, maxWidthHeight, params.slide.slideLayout, params.slide.clearMap, params.slide.colorSchemes);
          tempShapes.addAll(tempGetTextBoxes);
          break;
      }
      maxWidth = maxWidthHeight["maxWidth"]!;
      maxHeight = maxWidthHeight["maxHeight"]!;
    }


    if (tempShapes.isNotEmpty) {
      tempSlide.add(SizedBox(
          height: maxHeight,
          width: maxWidth,
          child: Stack(
            children: tempShapes,
          )));
    }
    if(kIsWeb){
      WebImages? webImage=params.webImages.firstWhereOrNull((img){
        return img.name == params.slide.backgroundImagePath;
      });
      if(webImage!=null) {
        slideWidget.add(SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            constraints: BoxConstraints(
                minHeight: params.height != null ? params.height!.toDouble() / 914400 : 450,
                minWidth: params.width != null ? params.width!.toDouble() / 914400 : 450),
            decoration: params.slide.backgroundImagePath != ""
                ? BoxDecoration(
              color: Colors.white,
              image: DecorationImage(
                image: MemoryImage(webImage.bytes),
                fit: BoxFit.fill,
              ),
            )
                : const BoxDecoration(
              color: Colors.white,
            ),
            width: maxWidth,
            margin: const EdgeInsets.all(8),
            child: Column(
              children: tempSlide,
            ),
          ),
        ))
        ;
      }
    }else{
    slideWidget.add(SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: BoxConstraints(
            minHeight: params.height != null ? params.height!.toDouble() / 914400 : 450,
            minWidth: params.width != null ? params.width!.toDouble() / 914400 : 450),
        decoration: params.slide.backgroundImagePath != ""
            ? BoxDecoration(
                color: Colors.white,
                image: DecorationImage(
                  image: FileImage(File(params.slide.backgroundImagePath)),
                  fit: BoxFit.fill,
                ),
              )
            : const BoxDecoration(
                color: Colors.white,
              ),
        width: maxWidth,
        margin: const EdgeInsets.all(8),
        child: Column(
          children: tempSlide,
        ),
      ),
    ))
    ;}
    return slideWidget;
  }
  ///Function for getting text boxes
  static PresentationTextBox? getPresentationTextBox(GetPresentationTextBoxParam params) {
    Offset offset = const Offset(0, 0);
    Size size = const Size(0, 0);
    double offsetY = 0;
    double offsetX = 0;
    if (params.spElement.parentElement != null && params.spElement.parentElement?.name.toString() == "p:grpSp") {
      var grpSpPr = params.spElement.parentElement?.findAllElements("p:grpSpPr");
      if (grpSpPr != null && grpSpPr.isNotEmpty) {
        var chckOff = grpSpPr.first.findAllElements("a:off");
        if (chckOff.isNotEmpty) {
          var offX = chckOff.first.getAttribute("x");
          if (offX != null) {
            offsetX = double.parse(offX);
          }
          var offY = chckOff.first.getAttribute("y");
          if (offY != null) {
            offsetY = double.parse(offY);
          }
        }
        var chkChOff = grpSpPr.first.findAllElements("a:chOff");
        if (chkChOff.isNotEmpty) {
          //print("a:chOff");
          //print(chkChOff);
          var offX = chkChOff.first.getAttribute("x");
          if (offX != null) {
            //print(offsetX);
            offsetX = offsetX - double.parse(offX);
            //print(offsetX);
          }
          var offY = chkChOff.first.getAttribute("y");
          if (offY != null) {
            //print(offsetY);
            offsetY = offsetY - double.parse(offY);
            //print(offsetY);
          }
        }
      }
    }
    var xfrmElement = params.spElement.findAllElements("a:xfrm");
    if (xfrmElement.isNotEmpty) {
      var chkOff = xfrmElement.first.findAllElements("a:off");
      if (chkOff.isNotEmpty) {
        var offX = chkOff.first.getAttribute("x");
        var offY = chkOff.first.getAttribute("y");
        if (offX != null && offY != null) {
          offset = Offset(double.parse(offX) + offsetX, double.parse(offY) + offsetY);
        }
      }
      var chkExt = xfrmElement.first.findAllElements("a:ext");
      if (chkExt.isNotEmpty) {
        var extX = chkExt.first.getAttribute("cx");
        var extY = chkExt.first.getAttribute("cy");
        if (extX != null && extY != null) {
          size = Size(double.parse(extX), double.parse(extY));
        }
      }
    }
    List<PresentationParagraph> presentationParagraphs = [];
    params.spElement.findAllElements("p:txBody").forEach((txt) {
      var chkPara = txt.findAllElements("a:p");
      List<PresentationText> presentationTexts = [];
      if (chkPara.isNotEmpty) {
        for (var para in chkPara) {
          var chkParaProp = para.findAllElements("a:pPr");
          String align = "";
          if (chkParaProp.isNotEmpty) {
            var chkAlg = chkParaProp.first.getAttribute("algn");
            if (chkAlg != null) {
              align = chkAlg;
            }
          }
          presentationTexts = [];
          var chkR = para.findAllElements("a:r");
          if (chkR.isNotEmpty) {
            for (var r in chkR) {
              double fontSize = 20;
              String colorScheme = "";
              bool isBold = false;
              String lumMod = "";
              String lumOff = "";
              var rPr = r.findAllElements("a:rPr");
              if (rPr.isNotEmpty) {
                var tempSize = rPr.first.getAttribute("sz");
                if (tempSize != null) {
                  fontSize = double.parse(tempSize) / 180;
                }
                var tempBold = rPr.first.getAttribute("b");
                if (tempBold != null) {
                  if (tempBold == "1") {
                    isBold = true;
                  }
                }
                var chkSchemeClr = rPr.first.findAllElements("a:schemeClr");

                if (chkSchemeClr.isNotEmpty) {
                  var tempClrScheme = chkSchemeClr.first.getAttribute("val");

                  if (tempClrScheme != null) {
                    if (params.clrMap[tempClrScheme] != null) {
                      colorScheme = params.clrMap[tempClrScheme]!;
                    } else {
                      colorScheme = tempClrScheme;
                    }
                  }
                  var chkLumMod = chkSchemeClr.first.findAllElements("a:lumMod");
                  if (chkLumMod.isNotEmpty) {
                    var tempLumMod = chkLumMod.first.getAttribute("val");
                    if (tempLumMod != null) {
                      lumMod = tempLumMod;
                    }
                  }
                  var chkLumOff = chkSchemeClr.first.findAllElements("a:lumOff");
                  if (chkLumOff.isNotEmpty) {
                    var tempLumOff = chkLumOff.first.getAttribute("val");
                    if (tempLumOff != null) {
                      lumOff = tempLumOff;
                    }
                  }
                }
              }
              var text = "";
              r.findAllElements("a:t").forEach((txt2) {
                text += txt2.innerText;
              });

              if (text.isNotEmpty) {
                PresentationText presentationText = PresentationText(text, fontSize);
                if (colorScheme.isNotEmpty) {
                  presentationText.colorScheme = colorScheme;
                }
                if (isBold) {
                  presentationText.isBold = true;
                }
                if (lumOff.isNotEmpty) {
                  presentationText.lumOff = lumOff;
                }
                if (lumMod.isNotEmpty) {
                  presentationText.lumMod = lumMod;
                }
                presentationTexts.add(presentationText);
              }
            }
          }
          if (presentationTexts.isNotEmpty || params.spElement.findAllElements("p:ph").isNotEmpty) {
            PresentationParagraph paragraph = PresentationParagraph();
            paragraph.textSpans = presentationTexts;
            if (align.isNotEmpty) {
              paragraph.align = align;
            }
            var chkPh = params.spElement.findAllElements("p:ph");
            if (chkPh.isNotEmpty) {
              //print(chkPh);
              var type = chkPh.first.getAttribute("type");
              if (type != null) {
                paragraph.type = type;
              }
              var idx = chkPh.first.getAttribute("idx");
              if (idx != null) {
                paragraph.idx = idx;
              }
            }
            presentationParagraphs.add(paragraph);
          }
        }
      }
    });
    if (presentationParagraphs.isNotEmpty) {
      PresentationTextBox presentationTextBox = PresentationTextBox(offset, size);
      presentationTextBox.presentationParas = presentationParagraphs;
      return presentationTextBox;
    } else {
      return null;
    }
  }
  ///Funtion for getting group details
  void getGroupDetails(xml.XmlElement spElement, Map<String, double> offsetValues, Map<String, int> rotFlip, Map<String, int> widthHeight,
      Map<String, String> colorDetails) {
    if (spElement.parentElement != null && spElement.parentElement!.name.toString() == "p:grpSp") {
      var grpSpPr = spElement.parentElement!.findAllElements("p:grpSpPr");

      if (grpSpPr.isNotEmpty) {
        var chckOff = grpSpPr.first.findAllElements("a:off");
        if (chckOff.isNotEmpty) {
          var offX = chckOff.first.getAttribute("x");
          if (offX != null) {
            offsetValues["offsetX"] = offsetValues["offsetX"]! + double.parse(offX);
          }
          var offY = chckOff.first.getAttribute("y");
          if (offY != null) {
            offsetValues["offsetY"] = offsetValues["offsetY"]! + double.parse(offY);
          }
        }
        var chkChOff = grpSpPr.first.findAllElements("a:chOff");
        if (chkChOff.isNotEmpty) {
          //print("a:chOff");
          //print(chkChOff);
          var offX = chkChOff.first.getAttribute("x");
          if (offX != null) {
            //print(offsetX);
            offsetValues["offsetX"] = offsetValues["offsetX"]! - double.parse(offX);
            //print(offsetX);
          }
          var offY = chkChOff.first.getAttribute("y");
          if (offY != null) {
            //print(offsetY);
            offsetValues["offsetY"] = offsetValues["offsetY"]! - double.parse(offY);
            //print(offsetY);
          }
        }
        var chkExt = grpSpPr.first.findAllElements("a:ext");

        if (chkExt.isNotEmpty) {
          var extCx = chkExt.first.getAttribute("cx");

          if (extCx != null) {
            widthHeight["width"] = widthHeight["width"]! + int.parse(extCx);
          }
          var extCy = chkExt.first.getAttribute("cy");

          if (extCy != null) {
            widthHeight["height"] = widthHeight["height"]! + int.parse(extCy);
          }
        }

        var chkChExt = grpSpPr.first.findAllElements("a:chExt");

        if (chkChExt.isNotEmpty) {
          var extCx = chkChExt.first.getAttribute("cx");
          if (extCx != null) {
            widthHeight["width"] = widthHeight["width"]! - int.parse(extCx);
          }
          var extCy = chkChExt.first.getAttribute("cy");
          if (extCy != null) {
            widthHeight["height"] = widthHeight["height"]! - int.parse(extCy);
          }
        }

        var chkXfrm = grpSpPr.first.findAllElements("a:xfrm");
        if (chkXfrm.isNotEmpty) {
          var tempRot = chkXfrm.first.getAttribute("rot");
          if (tempRot != null) {
            if (rotFlip["rot"] == null) {
              rotFlip["rot"] = 0;
            }
            rotFlip["rot"] = rotFlip["rot"]! + (int.parse(tempRot) ~/ 60000);
          }
          var tempFlipH = chkXfrm.first.getAttribute("flipH");
          if (tempFlipH != null) {
            rotFlip["flipH"] = int.parse(tempFlipH);
          }
          var tempFlipV = chkXfrm.first.getAttribute("flipV");
          if (tempFlipV != null) {
            rotFlip["flipV"] = int.parse(tempFlipV);
          }
        }
        var chkSolidFill = grpSpPr.first.findAllElements("a:solidFill");
        if (chkSolidFill.isNotEmpty) {
          var chkSchemeClr = chkSolidFill.first.findAllElements("a:schemeClr");
          if (chkSchemeClr.isNotEmpty) {
            var tempVal = chkSchemeClr.first.getAttribute("val");
            if (tempVal != null) {
              colorDetails["clrScheme"] = tempVal;
            }
            var chkLumMod = chkSchemeClr.first.findAllElements("a:lumMod");
            if (chkLumMod.isNotEmpty) {
              var tempLumMod = chkLumMod.first.getAttribute("val");
              if (tempLumMod != null) {
                colorDetails["lumMod"] = tempLumMod;
              }
            }
            var chkLumOff = chkSchemeClr.first.findAllElements("a:lumOff");
            if (chkLumOff.isNotEmpty) {
              var tempLumOff = chkLumOff.first.getAttribute("val");
              if (tempLumOff != null) {
                colorDetails["lumOff"] = tempLumOff;
              }
            }
          }
          var chkRGBClr = chkSolidFill.first.findAllElements("a:srgbClr");
          if (chkRGBClr.isNotEmpty) {
            var tempVal = chkRGBClr.first.getAttribute("val");
            if (tempVal != null) {
              colorDetails["srgbClr"] = tempVal;
            }
          }
        }
      }

      getGroupDetails(spElement.parentElement!, offsetValues, rotFlip, widthHeight, colorDetails);
    }
  }
  ///Function for modifying color
  static Color modifyColor(Color originalColor, String? lumMod, String? lumOff) {
    // Calculate luminance factors
    double lumModFactor = 1; // Value range is between 0 to 1
    double lumOffFactor = 0 / 100000; // Value range is between 0 to 1
    if (lumMod != null) {
      lumModFactor = double.parse(lumMod) / 100000;
    }
    if (lumOff != null) {
      lumOffFactor = double.parse(lumOff) / 100000;
    }
    // Calculate the new luminance level
    //HSLColor hslColor = HSLColor.fromColor(originalColor);

    // Compute new lightness
    //double newLightness = (hslColor.lightness * lumModFactor) - lumOffFactor;

    // Clamp lightness to be between 0.0 and 1.0
    //newLightness = newLightness.clamp(0.0, 1.0);

    // Convert back to RGB
    //HSLColor newHSLColor = hslColor.withLightness(newLightness);

    //return newHSLColor.toColor();
    // Adjust the color based on luminance modifications
    // This is a simplified adjustment. You might want to consider different ways to calculate luminance.
    double r = (originalColor.r / 255.0) * lumModFactor + lumOffFactor;
    double g = (originalColor.g / 255.0) * lumModFactor + lumOffFactor;
    double b = (originalColor.b / 255.0) * lumModFactor + lumOffFactor;

    // Clamp values to the range [0, 1]
    r = r.clamp(0, 1);
    g = g.clamp(0, 1);
    b = b.clamp(0, 1);

    return Color.fromARGB(255, (r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt());
  }
  ///Function for showing preset shapes
  static List<Widget> showPresetShape(PresentationPresetShapes presentationPresetShape, Map<String, String> clearMap,
      List<PresentationColorSchemes> colorSchemes, double divisionFactor, Map<String, double> maxWidthHeight) {
    List<Widget> tempShapes = [];
    if (presentationPresetShape.left / divisionFactor + presentationPresetShape.width / divisionFactor > maxWidthHeight["maxWidth"]!) {
      maxWidthHeight["maxWidth"] = presentationPresetShape.left / divisionFactor + presentationPresetShape.width / divisionFactor;
    }
    if (presentationPresetShape.top / divisionFactor + presentationPresetShape.height / divisionFactor > maxWidthHeight["maxHeight"]!) {
      maxWidthHeight["maxHeight"] = presentationPresetShape.top / divisionFactor + presentationPresetShape.height / divisionFactor;
    }
    if (presentationPresetShape.type == "roundRect") {
      String color = "0xff000000";
      if (presentationPresetShape.fillColorScheme.isNotEmpty) {
        String clrSchemeVal = presentationPresetShape.fillColorScheme;
        if (clearMap[clrSchemeVal] != null) {
          clrSchemeVal = clearMap[clrSchemeVal]!;
        }
        var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
          //print(clrSch.name);
          return clrSch.name == clrSchemeVal;
        });
        if (clrScheme != null) {
          if (clrScheme.sysClrLast.isNotEmpty) {
            color = "0xff${clrScheme.sysClrLast}";
          } else if (clrScheme.srgbClr.isNotEmpty) {
            color = "0xff${clrScheme.srgbClr}";
          }
        }
      }

      Color adjustedColor = Color(int.parse(color));
      if (presentationPresetShape.lumMod != null || presentationPresetShape.lumOff != null) {
        adjustedColor = modifyColor(adjustedColor, presentationPresetShape.lumMod, presentationPresetShape.lumOff);
      }

      double borderRadius = 0;
      if (presentationPresetShape.adjValue.isNotEmpty) {
        String tempBorderRadius = presentationPresetShape.adjValue.replaceAll("val ", "");
        borderRadius = double.parse(tempBorderRadius) / 1000;
        //print(borderRadius);
      }
      double rotate = 0;
      bool flipH = false;
      bool flipV = false;
      if (presentationPresetShape.rotate != null) {
        rotate = presentationPresetShape.rotate! * pi / 180;
      }
      if (presentationPresetShape.flipH != null && presentationPresetShape.flipH == "1") {
        flipH = true;
      }
      if (presentationPresetShape.flipV != null && presentationPresetShape.flipV == "1") {
        flipV = true;
      }
      tempShapes.add(Positioned(
          top: presentationPresetShape.top != 0 ? presentationPresetShape.top / divisionFactor : 0,
          left: presentationPresetShape.left != 0 ? presentationPresetShape.left / divisionFactor : 0,
          child: Transform.rotate(
            angle: rotate,
            child: Transform.flip(
              flipX: flipH,
              flipY: flipV,
              child: Container(
                width: presentationPresetShape.width / (divisionFactor),
                height: presentationPresetShape.height / divisionFactor,
                decoration: BoxDecoration(color: adjustedColor, borderRadius: BorderRadius.circular(borderRadius.toDouble())),
              ),
            ),
          )));
    } else if (presentationPresetShape.type == "rect") {
      String color = "";
      if (presentationPresetShape.fillColorScheme.isNotEmpty) {
        String clrSchemeVal = presentationPresetShape.fillColorScheme;
        if (clearMap[clrSchemeVal] != null) {
          clrSchemeVal = clearMap[clrSchemeVal]!;
        }
        var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
          //print(clrSch.name);
          return clrSch.name == clrSchemeVal;
        });
        if (clrScheme != null) {
          if (clrScheme.sysClrLast.isNotEmpty) {
            color = "0xff${clrScheme.sysClrLast}";
          } else if (clrScheme.srgbClr.isNotEmpty) {
            color = "0xff${clrScheme.srgbClr}";
          }
        }
      }
      Color adjustedColor = Colors.transparent;
      if (color.isNotEmpty) {
        adjustedColor = Color(int.parse(color));
        if (presentationPresetShape.lumMod != null || presentationPresetShape.lumOff != null) {
          adjustedColor = modifyColor(adjustedColor, presentationPresetShape.lumMod, presentationPresetShape.lumOff);
        }
      }
      double rotate = 0;
      bool flipH = false;
      bool flipV = false;
      if (presentationPresetShape.rotate != null) {
        rotate = presentationPresetShape.rotate! * pi / 180;
      }
      if (presentationPresetShape.flipH != null && presentationPresetShape.flipH == "1") {
        flipH = true;
      }
      if (presentationPresetShape.flipV != null && presentationPresetShape.flipV == "1") {
        flipV = true;
      }
      tempShapes.add(Positioned(
          top: presentationPresetShape.top != 0 ? presentationPresetShape.top / divisionFactor : 0,
          left: presentationPresetShape.left != 0 ? presentationPresetShape.left / divisionFactor : 0,
          child: Transform.rotate(
            angle: rotate,
            child: Transform.flip(
              flipX: flipH,
              flipY: flipV,
              child: Container(
                width: presentationPresetShape.width / (divisionFactor),
                height: presentationPresetShape.height / divisionFactor,
                decoration: BoxDecoration(
                  color: color.isNotEmpty ? adjustedColor : Colors.transparent,
                ),
              ),
            ),
          )));
    } else if (presentationPresetShape.type == "blockArc") {
      String color = "";
      if (presentationPresetShape.fillColorScheme.isNotEmpty) {
        String clrSchemeVal = presentationPresetShape.fillColorScheme;
        if (clearMap[clrSchemeVal] != null) {
          clrSchemeVal = clearMap[clrSchemeVal]!;
        }
        var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
          //print(clrSch.name);
          return clrSch.name == clrSchemeVal;
        });
        if (clrScheme != null) {
          if (clrScheme.sysClrLast.isNotEmpty) {
            color = "0xff${clrScheme.sysClrLast}";
          } else if (clrScheme.srgbClr.isNotEmpty) {
            color = "0xff${clrScheme.srgbClr}";
          }
        }
      }
      Color adjustedColor = Colors.transparent;
      if (color.isNotEmpty) {
        adjustedColor = Color(int.parse(color));
        if (presentationPresetShape.lumMod != null || presentationPresetShape.lumOff != null) {
          adjustedColor = modifyColor(adjustedColor, presentationPresetShape.lumMod, presentationPresetShape.lumOff);
        }
      }
      double rotate = 0;
      bool flipH = false;
      bool flipV = false;
      if (presentationPresetShape.rotate != null) {
        rotate = presentationPresetShape.rotate! * pi / 180;
      }
      if (presentationPresetShape.flipH != null && presentationPresetShape.flipH == "1") {
        flipH = true;
      }
      if (presentationPresetShape.flipV != null && presentationPresetShape.flipV == "1") {
        flipV = true;
      }
      tempShapes.add(Positioned(
          top: presentationPresetShape.top != 0 ? presentationPresetShape.top / divisionFactor : 0,
          left: presentationPresetShape.left != 0 ? presentationPresetShape.left / divisionFactor : 0,
          child: Transform.rotate(
            angle: rotate,
            child: Transform.flip(
              flipX: flipH,
              flipY: flipV,
              child: SizedBox(
                  width: presentationPresetShape.width.toDouble() / divisionFactor,
                  height: presentationPresetShape.height.toDouble() / divisionFactor,
                  child: CustomPaint(painter: PresetDiagram(presentationPresetShape, divisionFactor.toDouble(), adjustedColor), child: Container())),
            ),
          )));
    } else if (presentationPresetShape.type == "round2SameRect") {
      String color = "0xff000000";
      if (presentationPresetShape.fillColorScheme.isNotEmpty) {
        String clrSchemeVal = presentationPresetShape.fillColorScheme;
        if (clearMap[clrSchemeVal] != null) {
          clrSchemeVal = clearMap[clrSchemeVal]!;
        }
        var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
          //print(clrSch.name);
          return clrSch.name == clrSchemeVal;
        });
        if (clrScheme != null) {
          if (clrScheme.sysClrLast.isNotEmpty) {
            color = "0xff${clrScheme.sysClrLast}";
          } else if (clrScheme.srgbClr.isNotEmpty) {
            color = "0xff${clrScheme.srgbClr}";
          }
        }
      }
      Color adjustedColor = Colors.transparent;
      if (color.isNotEmpty) {
        adjustedColor = Color(int.parse(color));
        if (presentationPresetShape.lumMod != null || presentationPresetShape.lumOff != null) {
          adjustedColor = modifyColor(adjustedColor, presentationPresetShape.lumMod, presentationPresetShape.lumOff);
        }
      }
      double borderRadius = 0;
      if (presentationPresetShape.adjValue.isNotEmpty) {
        String tempBorderRadius = presentationPresetShape.adjValue.replaceAll("val ", "");
        borderRadius = double.parse(tempBorderRadius) / 1000;
        //print(borderRadius);
      }
      double rotate = 0;
      bool flipH = false;
      bool flipV = false;
      if (presentationPresetShape.rotate != null) {
        rotate = presentationPresetShape.rotate! * pi / 180;
      }
      if (presentationPresetShape.flipH != null && presentationPresetShape.flipH == "1") {
        flipH = true;
      }
      if (presentationPresetShape.flipV != null && presentationPresetShape.flipV == "1") {
        flipV = true;
      }
      tempShapes.add(Positioned(
          top: presentationPresetShape.top != 0 ? presentationPresetShape.top / divisionFactor : 0,
          left: presentationPresetShape.left != 0 ? presentationPresetShape.left / divisionFactor : 0,
          child: Transform.rotate(
            angle: rotate,
            child: Transform.flip(
              flipX: flipH,
              flipY: flipV,
              child: Container(
                width: presentationPresetShape.width / (divisionFactor),
                height: presentationPresetShape.height / divisionFactor,
                decoration: BoxDecoration(
                    color: adjustedColor,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(borderRadius.toDouble()), topRight: Radius.circular(borderRadius))),
              ),
            ),
          )));
    } else if (presentationPresetShape.type == "parallelogram") {
      String color = "";
      if (presentationPresetShape.fillColorScheme.isNotEmpty) {
        String clrSchemeVal = presentationPresetShape.fillColorScheme;
        if (clearMap[clrSchemeVal] != null) {
          clrSchemeVal = clearMap[clrSchemeVal]!;
        }
        var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
          //print(clrSch.name);
          return clrSch.name == clrSchemeVal;
        });
        if (clrScheme != null) {
          if (clrScheme.sysClrLast.isNotEmpty) {
            color = "0xff${clrScheme.sysClrLast}";
          } else if (clrScheme.srgbClr.isNotEmpty) {
            color = "0xff${clrScheme.srgbClr}";
          }
        }
      }
      Color adjustedColor = Colors.transparent;
      if (color.isNotEmpty) {
        adjustedColor = Color(int.parse(color));
        if (presentationPresetShape.lumMod != null || presentationPresetShape.lumOff != null) {
          adjustedColor = modifyColor(adjustedColor, presentationPresetShape.lumMod, presentationPresetShape.lumOff);
        }
      }
      double rotate = 0;
      bool flipH = false;
      bool flipV = false;
      if (presentationPresetShape.rotate != null) {
        rotate = presentationPresetShape.rotate! * pi / 180;
      }
      if (presentationPresetShape.flipH != null && presentationPresetShape.flipH == "1") {
        flipH = true;
      }
      if (presentationPresetShape.flipV != null && presentationPresetShape.flipV == "1") {
        flipV = true;
      }
      tempShapes.add(Positioned(
          top: presentationPresetShape.top != 0 ? presentationPresetShape.top / divisionFactor : 0,
          left: presentationPresetShape.left != 0 ? presentationPresetShape.left / divisionFactor : 0,
          child: Transform.rotate(
            angle: rotate,
            child: Transform.flip(
              flipX: flipH,
              flipY: flipV,
              child: SizedBox(
                  width: presentationPresetShape.width.toDouble() / divisionFactor,
                  height: presentationPresetShape.height.toDouble() / divisionFactor,
                  child: CustomPaint(
                      painter:
                          PresetParallelogram(int.parse(presentationPresetShape.adjValue.replaceAll("val ", "")), adjustedColor, divisionFactor),
                      child: Container())),
            ),
          )));
    } else if (presentationPresetShape.type == "ellipse") {
      String color = "0xff000000";
      if (presentationPresetShape.fillColorScheme.isNotEmpty) {
        String clrSchemeVal = presentationPresetShape.fillColorScheme;
        if (clearMap[clrSchemeVal] != null) {
          clrSchemeVal = clearMap[clrSchemeVal]!;
        }
        var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
          //print(clrSch.name);
          return clrSch.name == clrSchemeVal;
        });
        if (clrScheme != null) {
          if (clrScheme.sysClrLast.isNotEmpty) {
            color = "0xff${clrScheme.sysClrLast}";
          } else if (clrScheme.srgbClr.isNotEmpty) {
            color = "0xff${clrScheme.srgbClr}";
          }
        }
      }

      Color adjustedColor = Color(int.parse(color));
      if (presentationPresetShape.lumMod != null || presentationPresetShape.lumOff != null) {
        adjustedColor = modifyColor(adjustedColor, presentationPresetShape.lumMod, presentationPresetShape.lumOff);
      }
      double rotate = 0;
      bool flipH = false;
      bool flipV = false;
      if (presentationPresetShape.rotate != null) {
        rotate = presentationPresetShape.rotate! * pi / 180;
      }
      if (presentationPresetShape.flipH != null && presentationPresetShape.flipH == "1") {
        flipH = true;
      }
      if (presentationPresetShape.flipV != null && presentationPresetShape.flipV == "1") {
        flipV = true;
      }
      tempShapes.add(Positioned(
          top: presentationPresetShape.top != 0 ? presentationPresetShape.top / divisionFactor : 0,
          left: presentationPresetShape.left != 0 ? presentationPresetShape.left / divisionFactor : 0,
          child: Transform.rotate(
            angle: rotate,
            child: Transform.flip(
              flipX: flipH,
              flipY: flipV,
              child: Container(
                width: presentationPresetShape.width / (divisionFactor),
                height: presentationPresetShape.height / divisionFactor,
                decoration: BoxDecoration(color: adjustedColor, shape: BoxShape.circle),
              ),
            ),
          )));
    }
    return tempShapes;
  }
  ///Function for showing custom diagram
  static List<Widget> showCustomDiagram(PresentationCustomDiagram presentationCustomDiagram, Map<String, String> clearMap,
      List<PresentationColorSchemes> colorSchemes, double divisionFactor, Map<String, double> maxWidthHeight) {
    List<Widget> tempShapes = [];
    if (presentationCustomDiagram.x / divisionFactor + presentationCustomDiagram.width / divisionFactor > maxWidthHeight["maxWidth"]!) {
      maxWidthHeight["maxWidth"] = presentationCustomDiagram.x / divisionFactor + presentationCustomDiagram.width / divisionFactor;
    }
    if (presentationCustomDiagram.y / divisionFactor + presentationCustomDiagram.height / divisionFactor > maxWidthHeight["maxHeight"]!) {
      maxWidthHeight["maxHeight"] = presentationCustomDiagram.y / divisionFactor + presentationCustomDiagram.height / divisionFactor;
    }
    String clrSchemeVal = presentationCustomDiagram.clrScheme ?? "";
    String color = "";
    if (presentationCustomDiagram.srgbClr!.isNotEmpty) {
      color = "0xff${presentationCustomDiagram.srgbClr}";
    } else {
      if (clearMap[clrSchemeVal] != null) {
        clrSchemeVal = clearMap[clrSchemeVal]!;
      }
      var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
        //print(clrSch.name);
        return clrSch.name == clrSchemeVal;
      });
      if (clrScheme != null) {
        if (clrScheme.sysClrLast.isNotEmpty) {
          color = "0xff${clrScheme.sysClrLast}";
        } else if (clrScheme.srgbClr.isNotEmpty) {
          color = "0xff${clrScheme.srgbClr}";
        }
      }
    }
    Color adjustedColor = Colors.transparent;
    if (color.isNotEmpty) {
      adjustedColor = Color(int.parse(color));
      if (presentationCustomDiagram.lumMod != null || presentationCustomDiagram.lumOff != null) {
        adjustedColor = modifyColor(adjustedColor, presentationCustomDiagram.lumMod, presentationCustomDiagram.lumOff);
      }
    }
    double rotate = 0;
    bool flipH = false;
    bool flipV = false;
    if (presentationCustomDiagram.rotate != null) {
      rotate = presentationCustomDiagram.rotate! * pi / 180;
    }
    if (presentationCustomDiagram.flipH != null && presentationCustomDiagram.flipH == "1") {
      //flipH=true;
    }
    if (presentationCustomDiagram.flipV != null && presentationCustomDiagram.flipV == "1") {
      flipV = true;
    }
    tempShapes.add(Positioned(
        top: presentationCustomDiagram.y != 0 ? presentationCustomDiagram.y / divisionFactor : 0,
        left: presentationCustomDiagram.x != 0 ? presentationCustomDiagram.x / divisionFactor : 0,
        child: SizedBox(
            //color: Colors.grey,
            width: presentationCustomDiagram.width.toDouble() / divisionFactor,
            height: presentationCustomDiagram.height.toDouble() / divisionFactor,
            child: Transform.rotate(
                angle: rotate,
                child: Transform.flip(
                    flipX: flipH,
                    flipY: flipV,
                    child: CustomPaint(
                        painter: CustomDiagram(presentationCustomDiagram, divisionFactor.toDouble(), adjustedColor),
                        child: Container()))))));
    return tempShapes;
  }
  ///Function to show texts
  static List<Widget> showTextBox(PresentationTextBox presentationTextBox, double divisionFactor, Map<String, double> maxWidthHeight,
      SlideLayout? slideLayout, Map<String, String> clearMap, List<PresentationColorSchemes> colorSchemes) {
    List<Widget> tempShapes = [];
    if (presentationTextBox.offset.dx / divisionFactor + presentationTextBox.size.width / divisionFactor > maxWidthHeight["maxWidth"]!) {
      maxWidthHeight["maxWidth"] = presentationTextBox.offset.dx / divisionFactor + presentationTextBox.size.width / divisionFactor;
    }
    if (presentationTextBox.offset.dy / divisionFactor + presentationTextBox.size.height / divisionFactor > maxWidthHeight["maxHeight"]!) {
      maxWidthHeight["maxHeight"] = presentationTextBox.offset.dy / divisionFactor + presentationTextBox.size.height / divisionFactor;
    }
    List<Widget> textBoxTexts = [];
    String align = "";
    String paraColorScheme = "";
    //String paraLumMod = "";
    //String paraLumOff = "";
    double paraFontSize = 0;
    double paraX = 0;
    double paraY = 0;
    int paraWidth = 0;
    int paraHeight = 0;
    for (int k = 0; k < presentationTextBox.presentationParas.length; k++) {
      List<TextSpan> textSpans = [];
      if (presentationTextBox.presentationParas[k].align != null) {
        align = presentationTextBox.presentationParas[k].align!;
      }
      if (presentationTextBox.presentationParas[k].type != null && presentationTextBox.presentationParas[k].idx != null) {
        var paraDetails = slideLayout?.paragraphs.firstWhereOrNull((para) {
          return para.type == presentationTextBox.presentationParas[k].type && para.idx == presentationTextBox.presentationParas[k].idx;
        });
        if (paraDetails != null) {
          align = paraDetails.anchor;
          paraColorScheme = paraDetails.schemeClr;
          paraFontSize = paraDetails.defaultSz / 180;
          paraX = paraDetails.x ?? 0;
          paraY = paraDetails.y ?? 0;
          paraWidth = paraDetails.width ?? 0;
          paraHeight = paraDetails.height ?? 0;
          if (paraDetails.lumOff != null) {
            //paraLumOff = paraDetails.lumOff!;
          }
          if (paraDetails.lumMod != null) {
            //paraLumMod = paraDetails.lumMod!;
          }
        }
      }
      for (int l = 0; l < presentationTextBox.presentationParas[k].textSpans.length; l++) {
        double fontSize = presentationTextBox.presentationParas[k].textSpans[l].fontSize;
        if (paraFontSize != 0) {
          fontSize = paraFontSize.toDouble();
        }
        bool isBold = false;
        if (presentationTextBox.presentationParas[k].textSpans[l].isBold) {
          isBold = true;
        }
        TextStyle textStyle = TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black);
        if (presentationTextBox.presentationParas[k].textSpans[l].colorScheme != null || paraColorScheme.isNotEmpty) {
          //print("---");
          //print(params.slide.presentationTextBoxes[j].presentationParas[k]
          //    .textSpans[l].colorScheme);
          String clrSchemeVal = presentationTextBox.presentationParas[k].textSpans[l].colorScheme ?? paraColorScheme;
          if (clearMap[clrSchemeVal] != null) {
            clrSchemeVal = clearMap[clrSchemeVal]!;
          }
          var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
            //print(clrSch.name);
            return clrSch.name == clrSchemeVal;
          });
          //print("----");

          if (clrScheme != null) {
            //print("---");
            //print(clrScheme.name);
            String color = "";
            if (clrScheme.sysClrLast.isNotEmpty) {
              color = "0xff${clrScheme.sysClrLast}";
            } else if (clrScheme.srgbClr.isNotEmpty) {
              color = "0xff${clrScheme.srgbClr}";
            }
            Color adjustedColor = Colors.transparent;
            if (color.isNotEmpty) {
              adjustedColor = Color(int.parse(color));
              if (presentationTextBox.presentationParas[k].textSpans[l].lumMod != null ||
                  presentationTextBox.presentationParas[k].textSpans[l].lumOff != null) {
                adjustedColor = modifyColor(adjustedColor, presentationTextBox.presentationParas[k].textSpans[l].lumMod,
                    presentationTextBox.presentationParas[k].textSpans[l].lumOff);
              }
            }
            //print(color);
            //textStyle=textStyle..copyWith(color: Color(int.parse(color)));
            textStyle = TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: adjustedColor);
            //print(textStyle.color.toString());
          }
        }
        textSpans.add(TextSpan(text: presentationTextBox.presentationParas[k].textSpans[l].text, style: textStyle));
      }
      textBoxTexts.add(Expanded(
          child: RichText(
        text: TextSpan(children: textSpans),
        textAlign: TextAlign.start,
      )));
    }
    double offsetX = presentationTextBox.offset.dx;
    double offsetY = presentationTextBox.offset.dy;
    if (offsetX == 0 && offsetY == 0 && paraX != 0 && paraY != 0) {
      offsetX = paraX;
      offsetY = paraY;
    }
    if (presentationTextBox.size.height != 0 && presentationTextBox.size.width != 0) {
      tempShapes.add(Positioned(
          top: offsetY / divisionFactor,
          left: offsetX / divisionFactor,
          child: SizedBox(
            height: presentationTextBox.size.height / divisionFactor,
            width: presentationTextBox.size.width / divisionFactor,
            child: Column(
              crossAxisAlignment: align == "ctr" ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: textBoxTexts,
            ),
          )));
    } else if (paraHeight != 0 && paraWidth != 0) {
      tempShapes.add(Positioned(
          top: offsetY / divisionFactor,
          left: offsetX / divisionFactor,
          child: SizedBox(
            height: paraHeight / divisionFactor,
            width: paraWidth / divisionFactor,
            child: Column(
              crossAxisAlignment: align == "ctr" ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: textBoxTexts,
            ),
          )));
    } else {
      tempShapes.add(Positioned(
          top: offsetY / divisionFactor,
          left: offsetX / divisionFactor,
          child: Column(
            crossAxisAlignment: align == "ctr" ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: textBoxTexts,
          )));
    }
    return tempShapes;
  }
}
///To pass slide parameters
class GetSlideParam {
  ///Slide object
  Slide slide;
  ///Slide width
  int? width;
  ///Slide height
  int? height;
  ///Web Images list
  List<WebImages> webImages;
  ///Constructor
  GetSlideParam(this.slide, this.width, this.height,this.webImages);
}

///To pass parameters to text boxes
class GetPresentationTextBoxParam {
  ///Element object
  xml.XmlElement spElement;
  ///Color map
  Map<String, String> clrMap;
  ///Constructor
  GetPresentationTextBoxParam(this.spElement, this.clrMap);
}
