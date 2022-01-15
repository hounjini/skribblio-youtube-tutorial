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

    /* 선 긋는데, 끝에서는 -1, -1을 보내도록 했다.
       (x, y) ~ (-1,-1) 점을 그리게 될 경우
       (-1, -1)은 끝이기 때문에
       그냥 (x,y) ~ (x,y) 로 변환해서 그리고 다음으로 넘어간다.
    */
    for (int i = 0; i < pointsList.length - 1; ++i) {
      // line
      if (pointsList[i] != null && pointsList[i + 1] != null) {
        if (pointsList[i + 1].points.dx == -1 &&
            pointsList[i + 1].points.dy == -1) {
          canvas.drawLine(
              pointsList[i].points, pointsList[i].points, pointsList[i].paint);
          i += 1;
        } else {
          canvas.drawLine(pointsList[i].points, pointsList[i + 1].points,
              pointsList[i].paint);
        }
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
        print("draw 3");
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
