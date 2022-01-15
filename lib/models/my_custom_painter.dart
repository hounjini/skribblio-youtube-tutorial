import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'touch_points.dart';

class MyCustomPainter extends CustomPainter {
  MyCustomPainter({required this.pointsList});
  List<TouchPoints> pointsList;
  List<Offset> offsetPoints = [];

  @override
  void paint(Canvas canvas, Size size) {
    // .. : cascasde
    Paint background = Paint()..color = Colors.white;
    // => Paint background = Paint();
    //    background.color = Colors.white
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, background);
    canvas.clipRect(rect);

    // Logic for points, if thre is point, we need to display point.
    // if there is line, we nee dto connect the points.

    for (int i = 0; i < pointsList.length - 1; ++i) {
      // line
      if (pointsList[i] != null && pointsList[i + 1] != null) {
        canvas.drawLine(pointsList[i].points, pointsList[i + 1].points,
            pointsList[i].paint);
        // point
      } else if (pointsList[i] != null && pointsList[i + 1] == null) {
        offsetPoints.clear();
        offsetPoints.add(pointsList[i].points);
        /* 점 찍는데 이렇게 두개를 찍을 필요가 있을까?
           그냥 하나만 해도 될 것 같은데? */
        // 2시간 2분에서 정지.
        // https://www.youtube.com/watch?v=afCVHB2xm-g&t=336s
        offsetPoints.add(Offset(
            pointsList[i].points.dx + 0.1, pointsList[i].points.dy + 0.1));
        canvas.drawPoints(
            ui.PointMode.points, offsetPoints, pointsList[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
