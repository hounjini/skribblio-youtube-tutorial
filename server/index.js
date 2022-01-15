const express = require("express");
var http = require("http");
const app = express();
const port = process.env.PORT || 3000;
var server = http.createServer(app);
const mongoos = require("mongoose");
const Room = require('./models/Room');

var socket = require('socket.io');
var io = socket(server);
const getWord = require('./api/getWord');
const { SocketAddress } = require("net");

//middleware
app.use(express.json());

var username = 'skribbl'
var password = 'AbOPmR1uPD1Gr2wz'
const DB = 'mongodb+srv://' + username + ':' + password + '@cluster0.2bpxm.mongodb.net/Cluster0?retryWrites=true&w=majority';

mongoos.connect(DB).then(() => {
    console.log('Connection Succesful!');
}).catch((e) => {
    console.log(e);
})

io.on('connection', (socket) => {
    console.log('connected');
    //create game callback
    // 호출하는 쪽에서 foo({nickname, name, occupancy, maxRounds}) 로 호출함.
    // 이를 받을 foo(data) => data['nickname'], ...
    // foo({nickname, name, occupancy, maxRounds}) => nickname == nickname 등등 순서에 관계 없이 하나씩 꺼내쓸 수 있음.
    // python에서 변수명 지정해서 호출하는 느낌으로.
    //socket.on('create-game', async({nickname, name, occupancy, maxRounds}) => {
    socket.on('create-game', async({nickname, name, maxRounds, occupancy}) => {
        try {
            let room = await Room.findOne({name});
            
            //let room = new Room();
            const word = getWord();
            room.word = word;
            room.name = name;
            room.occupancy = occupancy;
            room.maxRounds = maxRounds;

            let player = {
                socketID: socket.id,
                nickname,
                isPartyLeader: true,
            }

            //paleyr에 현재 player schema넣기.
            room.players.push(player);
            room = await room.save();

            //socket.io의 socket은 namespace밑에 room이라는 단위로 묶여있다.
            //그리고 name이라는 room을 만들어 이 socket을 넣는다.
            // https://socket.io/docs/v3/rooms/
            socket.join(name);

            //https://socket.io/docs/v3/emit-cheatsheet/
            io.to(name).emit('updateRoom', room);
            console.log("here, ok");
        } catch(err) {
            console.log(err);
        }
    })
    //async 함수 만듦. 이름은 없음.
    socket.on('join-game', async({nickname, name}) => {
        try {
            console.log("lets tring to join game room: " + name);
            // var a = "value of variable a"
            // {a} == {'a' : 'value of variable a'}
            let room = await Room.findOne({name});
            // let room = await Room.findOne({'name' : name});
            if(!room) {
                console.log("cannot join room - no room found");
                socket.emit('notCorrectGame', 'Please enter valid room name');
                return;
            }

            // player can join the room.
            if(room.isJoin) {
                let player = {
                    socketID: socket.id,
                    nickname,
                }
                room.players.push(player);
                socket.join(name);

                // 시작하면, 사람들이 못나가고..?
                // 시작과 나가는거랑 같이 관리되는 느낌인데.
                if(room.players.length === room.occupancy) {
                    room.isJoin = false;
                }
                room.turn = room.players[room.turnIndex];
                room = await room.save();
                //broadcast to the sockets in the room.
                io.to(name).emit('updateRoom', room);
            } else {    //if player cannot join the room
                socket.emit('notCorrectGame', 'The game is in progress, please try later.');
            }
        } catch (err) {
            console.log(err);
        }
    });

    // whiteboard sockets
    socket.on('paint', ({details, roomName}) => {
        io.to(roomName).emit('points', {details: details});
    });


    socket.on('color-change', ({color, roomName}) => {
        io.to(roomName).emit('color-change', color);
    })

    socket.on('stroke-width', ({value, roomName}) => {
        io.to(roomName).emit('stroke-width', value);
    })

    socket.on('clean-screen', ({roomName}) => {
        io.to(roomName).emit('clean-screen', '');
    })

    socket.on('msg', async ({username, msg, word, roomName, guessedUserCtr, totalTime, timeTaken}) => {
        try {
            //메시지가 word, 정답이면
            if(msg == word) {
                let room = await Room.find({name : roomName});
                let userPlayer = room[0].players.filter(
                    (player) => player.nickname === username
                )

                if(timeTaken !== 0) {
                    userPlayer[0].points += Math.round((200 / timeTaken));
                }

                room = await room[0].save();
                // 올바르게 예측한 경우 그 채팅은 정답대신 Guessed it을 보낸다.
                io.to(roomName).emit('msg', {
                    username: username,
                    msg: 'Guessed it!',
                    guessedUserCtr: guessedUserCtr + 1
                })
                io.to(roomName).emit('close-input', "");
            } else {
                io.to(roomName).emit('msg', {
                    username: username,
                    msg: msg,
                    guessedUserCtr: guessedUserCtr
                });
            }
        } catch (err) {
            console.log(err.toString());
        }
    })

    socket.on('change-turn', async(name) => {
        try {
            let room = await Room.findOne({name});
            let idx = room.turnIndex;
            //모든사람들이 1번씩 다 했으면 다음 라운드로 간다.
            if(idx + 1 === room.players.length) {
                room.currentRound += 1;
            }
            // the game is going on.
            if(room.currentRound <= room.maxRounds) {
                const word = getWord();
                room.word = word;
                room.turnIndex = (idx + 1) % room.players.length;
                room.turn = room.players[room.turnIndex];
                room = await room.save();
                io.to(name).emit('change-turn', room);
            } else {    //show the leade board.
                io.to(name).emit('show-leaderboard', room.players);
            }
        } catch(err) {
            console.log(err);
        }
    })

    socket.on('updateScore', async(name) => {
        console.log("updateScorea called");
        try {
            console.log("find room called");
            const room = await Room.findOne({name : name});
            console.log("emitting update score here");
            console.log(room)
            io.to(name).emit('updateScore', room);
            console.log("emitting update score finished.");
        } catch (err) {
            console.log(err);
        }
    })

    socket.on('disconnect', async() => {
        try {
            let room = await Room.findOne({"players.socketID" : socket.id})
            if(room === null) {
                return;
            }
            for(let i = 0; i < room.players.length; ++i) {
                console.log("lets find someone with socket.id " + socket.id)
                console.log(room.players[i].socketID);
                if(room.players[i].socketID === socket.id) {  //이 사람이 끊어지 사람인 경우.
                    console.log("found!! : " + socket.id);
                    room.players.splice(i, 1);  //array에서 플레이어 제거.
                    break;
                }
            }

            room = await room.save();
            //only 1 left
            if(room.players.length === 1) {
                console.log("this room has only 1 player.");
                //send to all, but except me.
                socket.broadcast.to(room.name).emit('show-leaderboard', room.players);
                console.log("show leaderboard sent.");
                //io.to(name).emit() => send to all in the room named 'name'
            } else {
                console.log("there is more than 1 player. just notify user disconnected.");
                socket.broadcast.to(room.name).emit('user-disconnected', room);
            }
        } catch (err) {
            console.log(err);
        }
    })
})

server.listen(port, "0.0.0.0", () => {
    console.log("Server started, running on port " + port);
})