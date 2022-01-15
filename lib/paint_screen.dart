import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:skribbl_clone/models/touch_points.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'final_leaderboard.dart';
import 'home_screen.dart';
import 'models/my_custom_painter.dart';
import 'sidebar/player_scoreboard__drawer.dart';
import 'widgets/waiting_lobby_screen.dart';

class PaintScreen extends StatefulWidget {
  /*
  const PaintScreen({Key? key, required this.data, required this.screenFrom})
      : super(key: key);
      */
  PaintScreen({required this.data, required this.screenFrom});
  final Map<String, String> data;
  final String screenFrom;

  @override
  _PaintScreenState createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  GlobalKey bottomKey = GlobalKey();
  late IO.Socket _socket;
  Map dataOfRoom = {};
  List<TouchPoints> points = [];
  StrokeCap strokeType = StrokeCap.round;
  Color selectedColor = Colors.black;
  double opacity = 1;
  double strokeWidth = 2;
  List<Widget> textBlankWidget = [];
  ScrollController _scrollController = ScrollController();
  TextEditingController controller = TextEditingController();
  List<Map> messages = []; //채팅 메시지
  int guessedUserCtr = 0; //올바르게 추측한 유저의 수.
  int _start = 60; //제한시간. 60초부터 시작.
  late Timer _timer;
  var scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map> scoreboard = [];
  bool isTextInputReadOnly = false;
  int maxPoints = 0;
  String winner = "";
  bool isShowFinalLeaderboard = false;

  @override
  void initState() {
    super.initState();
    connect();
    //widget: 현재 state와 연결된 widget
    print(widget.data);
  }

  void startTimer() {
    const oneSec = const Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        //제한시간 끝
        _socket.emit('change-turn', dataOfRoom['name']);
        setState(() {
          _timer.cancel();
        });
      } else {
        setState(() {
          _start -= 1;
        });
      }
    });
  }

  void renderTextBlank(String text) {
    textBlankWidget.clear();
    for (int i = 0; i < text.length; ++i) {
      textBlankWidget.add(const Text('_', style: TextStyle(fontSize: 30)));
    }
  }

  void connect() {
    _socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false
    });
    _socket.connect();

    if (widget.screenFrom == 'createRoom') {
      _socket.emit('create-game', widget.data);
    } else if (widget.screenFrom == "joinRoom") {
      _socket.emit('join-game', widget.data);
    }

    //listen to socket
    _socket.onConnect((data) {
      print('Connected');
      print(data);
      _socket.on('updateRoom', (roomData) {
        print("helo world?!\n");
        print("word : " + roomData['word']);
        setState(() {
          renderTextBlank(roomData['word']);
          dataOfRoom = roomData;
        });
        //all the users are joined, let's start.
        if (roomData['isJoin'] != true) {
          startTimer();
        }
        scoreboard.clear();
        for (int i = 0; i < roomData['players'].length; ++i) {
          setState(() {
            scoreboard.add({
              'username': roomData['players'][i]['nickname'],
              'points': roomData['players'][i]['points'].toString()
            });
          });
        }
      });

      //적당한 게임이 아닌 경우 앞으로 돌아간다.
      _socket.on(
          'notCorrectGame',
          (data) => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false));

      _socket.on('points', (point) {
        if (point['details'] != null) {
          print("point recevied!");
          print(point);
          setState(() {
            points.add(TouchPoints(
                points: Offset((point['details']['dx']).toDouble(),
                    (point['details']['dy']).toDouble()),
                paint: Paint()
                  ..strokeCap = strokeType
                  ..isAntiAlias = true
                  ..color = selectedColor.withOpacity(opacity)
                  ..strokeWidth = strokeWidth));
          });
        }
      });

      _socket.on('color-change', (colorString) {
        print("color change event occured: 0x" + colorString);
        int value = int.parse(colorString, radix: 16);
        Color newColor = Color(value);
        setState(() {
          selectedColor = newColor;
        });
      });

      _socket.on('stroke-width', (value) {
        print("stroke width changed: " +
            strokeWidth.toString() +
            " => " +
            value.toString());
        setState(() {
          strokeWidth = value.toDouble();
        });
      });

      _socket.on('clean-screen', (data) {
        print("clear screen!");
        setState(() {
          points.clear();
        });
      });

      _socket.on('msg', (msgData) {
        /*
        final RenderBox _renderBox =
            bottomKey.currentContext?.findRenderObject() as RenderBox;
        int move = _renderBox.size.height.toInt();
        print("move = " + move.toString());
        */
        setState(() {
          messages.add(msgData);
          guessedUserCtr = msgData['guessedUserCtr'];
        });
        //host is not able to guess.
        //모든 사람들이 다 맞췄다면 다음 유저가 그림 그리도록 하자?
        if (guessedUserCtr >= dataOfRoom['players'].length - 1) {
          _socket.emit('change-turn', dataOfRoom['name']);
        }

        // 채팅보내고 채팅창 자동으로 아래로 내린다.
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 70,
            //이렇게 하며 안되고 보이는대로 내려야한다.
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut);
      });

      _socket.on('change-turn', (data) {
        String oldWord = dataOfRoom['word'];
        //statefulWidget은 기본적으려 context를 가지고 있다.
        showDialog(
            context: context,
            builder: (context) {
              //Future: 미래에 실행하자
              //await, async랑 같이 사용.
              //https://beomseok95.tistory.com/309#%EC%98%A4%EB%A5%98%EC%99%80_%ED%95%A8%EA%BB%98_%EC%99%84%EB%A3%8C
              Future.delayed(Duration(seconds: 3), () {
                setState(() {
                  dataOfRoom = data;
                  renderTextBlank(data['word']);
                  guessedUserCtr = 0;
                  points.clear();
                  _start = 60;
                  isTextInputReadOnly = false;
                });
                // 일단 Alert을 보여준 후, 3초가 지나면 게임 데이터를 clear하고
                // alert을 없앤다. (이전 상태로 돌아간다.)
                Navigator.of(context).pop();
                _timer.cancel();
                startTimer();
              });
              return AlertDialog(
                  title: Center(
                child: Text('Word was $oldWord'),
              ));
            });
      });

      _socket.on('close-input', (_) {
        _socket.emit('updateScore', widget.data['name']);
        setState(() {
          isTextInputReadOnly = true;
        });
      });

      _socket.on('updateScore', (roomData) {
        scoreboard.clear();
        setState(() {
          for (int i = 0; i < roomData['players'].length; ++i) {
            scoreboard.add({
              'username': roomData['players'][i]['nickname'],
              'points': roomData['players'][i]['points'].toString()
            });
          }
        });
      });

      _socket.on('show-leaderboard', (roomPlayers) {
        scoreboard.clear();
        setState(() {
          for (int i = 0; i < roomPlayers.length; ++i) {
            scoreboard.add({
              'username': roomPlayers[i]['nickname'],
              'points': roomPlayers[i]['points'].toString()
            });
            /*
            {
              'points': 120,
              'username' : 'hounjini'
            }
            */

            if (maxPoints < int.parse(scoreboard[i]['points'])) {
              winner = scoreboard[i]['username'];
              maxPoints = int.parse(scoreboard[i]['points']);
            }
          }
          _timer.cancel();
          isShowFinalLeaderboard = true;
        });
      });

      _socket.on('user-disconnected', (roomData) {
        setState(() {
          dataOfRoom = roomData;
          scoreboard.clear();
          for (int i = 0; i < roomData['players'].length; ++i) {
            scoreboard.add({
              'username': roomData['players'][i]['nickname'],
              'points': roomData['players'][i]['points'].toString()
            });
          }
        });
      });
    });
  }

  @override
  //call this object is removed permanantly.
  void dispose() {
    _socket.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    void selectColor() {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text("Choose color"),
                  content: SingleChildScrollView(
                    child: BlockPicker(
                        pickerColor: selectedColor,
                        onColorChanged: (color) {
                          String colorString = color.toString();
                          String valueString =
                              colorString.split('(0x')[1].split(')')[0];
                          print("color changed to: " +
                              colorString +
                              " => " +
                              valueString);
                          Map _map = {
                            'color': valueString,
                            'roomName': dataOfRoom['name']
                          };
                          _socket.emit('color-change', _map);
                        }),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close')),
                  ]));
    }

    //TODO: 나중에 여기서 stack 대신에 column, extended로 바꿔서 한번 해보기.
    return Scaffold(
      key: scaffoldKey,
      drawer: PlayerScore(
        userData: scoreboard,
      ),
      backgroundColor: Colors.white,
      body: dataOfRoom != null
          ? dataOfRoom['isJoin'] != true
              ? !isShowFinalLeaderboard
                  ? Stack(children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: width,
                            height: height * 0.55,
                            child: GestureDetector(
                                //pan: 모든 터지, tab, second tab, longpress 등이 모두 pan 이다.
                                onPanUpdate: (details) {
                                  //print("onPanUpdate: " + details.localPosition.dx.toString());
                                  _socket.emit('paint', {
                                    'details': {
                                      'dx': details.localPosition.dx,
                                      'dy': details.localPosition
                                          .dy, //parent screen으로 좌표 가져온다.
                                    },
                                    'roomName': widget.data['name'],
                                  });
                                },
                                onPanStart: (details) {
                                  //print("onPanStart: " +
                                  //    details.localPosition.dx.toString());
                                  _socket.emit('paint', {
                                    'details': {
                                      'dx': details.localPosition.dx,
                                      'dy': details.localPosition
                                          .dy, //parent screen으로 좌표 가져온다.
                                    },
                                    'roomName': widget.data['name'],
                                  });
                                },
                                onPanEnd: (details) {
                                  //print("onPanEnd");
                                  _socket.emit('paint', {
                                    'details': null,
                                    'roomName': widget.data['name'],
                                  });
                                },
                                child: SizedBox.expand(
                                    // 끝이 둥근 사각형
                                    child: ClipRRect(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20)),
                                        //얘를 감싸고있는 부모가 변경되지 않아서, 화면이 그려지지 않아도 될 때,
                                        // repaint boundray는 독립적인 display를 가지고 있기 때문에 얘만 그리도록 한다.
                                        child: RepaintBoundary(
                                            child: CustomPaint(
                                          size: Size.infinite,
                                          painter: MyCustomPainter(
                                              pointsList: points),
                                        ))))),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.color_lens,
                                    color: selectedColor),
                                onPressed: () {
                                  selectColor();
                                },
                              ),
                              Expanded(
                                child: Slider(
                                  min: 1.0,
                                  max: 10,
                                  label: "Strokewidth: $strokeWidth",
                                  activeColor: selectedColor,
                                  value: strokeWidth,
                                  onChanged: (double value) {
                                    Map _map = {
                                      'value': value,
                                      'roomName': dataOfRoom['name']
                                    };
                                    _socket.emit('stroke-width', _map);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.layers_clear,
                                    color: selectedColor),
                                onPressed: () {
                                  Map _map = {'roomName': dataOfRoom['name']};
                                  _socket.emit('clean-screen', _map);
                                },
                              ),
                            ],
                          ),

                          // 내가 이번턴이 아닌 경우엔 text guessing을
                          // 내 턴인 경우엔 그려야할 단어를 볼 수 있음.
                          // 게임을 만들자 마자인 경우 turn이 없음. 게임이 시작되지 않았기 때문에.
                          dataOfRoom['turn'] != null &&
                                  dataOfRoom['turn']['nickname'] !=
                                      widget.data['nickname']
                              ? Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: textBlankWidget,
                                )
                              : Center(
                                  child: Text(
                                      dataOfRoom['word'] != null
                                          ? dataOfRoom['word']
                                          : "",
                                      style: TextStyle(fontSize: 30))),
                          Container(
                            height: MediaQuery.of(context).size.height * 0.3,
                            child: ListView.builder(
                                controller: _scrollController,
                                shrinkWrap:
                                    true, //https://stackoverflow.com/questions/54007073/what-does-the-shrinkwrap-property-do-in-flutter/54008230#54008230
                                //listview 에서 list를 보여주는데 필요한 만큼만 listview가 생성되게 한다.
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  var msg = messages[index];
                                  print(msg);
                                  /*
                        var msg = message[index].values;
                        {'name' : 'hounjini', 'msg' : 'hello'}
                        msg.elementAt(0) => hounjini
                        msg.elementAt(1) => hello
                      */
                                  return ListTile(
                                    title: Text(
                                      msg['username'],
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(msg['msg'],
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 16)),
                                  );
                                }),
                          ),
                        ],
                      ),
                      dataOfRoom['turn'] != null &&
                              dataOfRoom['turn']['nickname'] !=
                                  widget.data['nickname']
                          ? Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                key: bottomKey,
                                //margin: const EdgeInsets.symmetric(horizontal: 20),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: TextField(
                                  readOnly: isTextInputReadOnly,
                                  controller: controller,
                                  onSubmitted: (value) {
                                    //enter 치면 얘가 실행되게 된다.
                                    if (value.trim().isNotEmpty) {
                                      Map _map = {
                                        'username': widget.data['nickname'],
                                        'msg': value.trim(),
                                        'word': dataOfRoom['word'],
                                        'roomName': dataOfRoom['name'],
                                        'guessedUserCtr': guessedUserCtr,
                                        'totalTime': 60,
                                        'timeTaken': 60 - _start,
                                      };
                                      _socket.emit('msg', _map);
                                    }
                                    controller.clear();
                                  },
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.transparent),
                                    ),
//when textinput is focused.
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.transparent),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5FA),
                                    hintText: 'Your Guess',
                                    hintStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  textInputAction: TextInputAction.done,
                                ),
                              ))
                          : Container(),
                      SafeArea(
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Colors.black),
                          onPressed: () =>
                              scaffoldKey.currentState!.openDrawer(),
                          //PARENT로 해도 될 것 같지만, 그냥 GLOBALKEY로 SCAFFOLD를 지정하고
                          //클릭되면 그 SCAFFOLD를 찾아서 DRAWER를 연다.
                          //currentState가 null일 수도 있기 때문에 ! 를 붙여 이건 null이 될 수 없다 (이 에러는 무시한다.) 라고 표시.
                        ),
                      )
                    ])
                  : FinalLeaderboard(
                      scoreboard: scoreboard,
                      winner: winner,
                    ) //final leader board.
              : WaitingLobbyScreen(
                  lobbyName: dataOfRoom['name'],
                  noOfPlayers: dataOfRoom['players'].length,
                  occupancy: dataOfRoom['occupancy'],
                  players: dataOfRoom['players'])
          : Center(
              child: CircularProgressIndicator()), //만약 사람들이 아직 안들어왔으면 기다리자.
      floatingActionButton: Container(
          margin: EdgeInsets.only(bottom: 30),
          child: FloatingActionButton(
            onPressed: () {},
            elevation: 7,
            backgroundColor: Colors.white,
            child: Text('$_start',
                style: TextStyle(color: Colors.black, fontSize: 22)),
          )),
    );
  }
}
