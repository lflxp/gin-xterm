学习和了解gotty的实现原理，并基于gin-web + vue + xterm.js 实现了一套完整的功能

## 使用

`环境准备`：`npm` `go`

`前端` [gin-xterm](https://github.com/lflxp/gin-xterm)

```bash
git clone https://github.com/lflxp/gin-xterm
cd gin-xterm
make all
```

`后端` [message](https://github.com/lflxp/message)

```bash
cd message
go install
./message
```

## Xtermjs 知识点

1. 是否需要解析键盘的各种回车、ctrl+c、ctrl+d等操作

解答：不需要，因为后端默认是以bash作为命令输入口

2. 不需要解析键盘操作，那各种结果处理怎么做

解答： 前后端需要规划好一套数据结构去处理三种情况,格式使用： msgType + base64.encode(messageType)

* 正常消息发送 -> msgType = 0 , messageType为输入字符
    > websocket.send('0' + Base64.encode(data))
* 定时任务发送 -> msgType = 1 , messageType忽略
    > websocket.send('1')
* Resize任务发送 -> msgType = 2 , messageType为【rows:cols】
    > websocket.send('2' + Base64.encode(size.rows + ':' + size.cols))

3. xtermjs前端背景大小、鼠标滑动、字体大小、光标怎么设置

解答: 
```javascript
this.term = new Terminal({
    rendererType: 'canvas', // 渲染类型
    rows: this.rows,
    cols: this.cols,
    convertEol: true, // 启用时，光标将设置为下一行的开头
    scrollback: 10, // 终端中的回滚量
    disableStdin: false, // 是否应禁用输入
    fontSize: 18,
    cursorBlink: true, // 光标闪烁
    cursorStyle: 'bar', // 光标样式 underline
    bellStyle: 'sound',
    theme: defaultTheme
})
```

4. 如何查看键盘输入的详细信息

解答：借助xtermjs提供的事件监听打印object查看
```javascript
this.term.on('key', function(key, ev) {
    console.log(key, ev, ev.keyCode)
})
```

5. 自定义xtermjs主题样式怎么弄？

解答：
```javascript
const defaultTheme = {
  foreground: '#ffffff', // 字体
  background: '#1b212f', // 背景色
  cursor: '#ffffff', // 设置光标
  selection: 'rgba(255, 255, 255, 0.3)',
  black: '#000000',
  brightBlack: '#808080',
  red: '#ce2f2b',
  brightRed: '#f44a47',
  green: '#00b976',
  brightGreen: '#05d289',
  yellow: '#e0d500',
  brightYellow: '#f4f628',
  magenta: '#bd37bc',
  brightMagenta: '#d86cd8',
  blue: '#1d6fca',
  brightBlue: '#358bed',
  cyan: '#00a8cf',
  brightCyan: '#19b8dd',
  white: '#e5e5e5',
  brightWhite: '#ffffff'
}
```

6. xtermjs和websocket如何相互联动

解答：

* websocket创建

```javascript
this.ws = new WebSocket('ws://127.0.0.1:8888/api/ws/ping5')
this.ws.onerror = () => {
    this.$message.error('ws has no token, please login first')
    this.$router.push({ name: 'login' })
}

this.ws.onclose = () => {
    this.term.setOption('cursorBlink', false)
    this.$message('console.web_socket_disconnect')
}
```

* xtermjs创建

查看上面第3个问题

* 联动

`websocket`加入xtermjs`term.socket = websocket`

`websocket`发送信息`websocket.send($info)`

7. 有完整DEMO示例吗？

解答：

* [Xterm.js v3](https://github.com/lflxp/gin-xterm/blob/master/src/views/pty/xterm3.vue)
* [Xterm.js v4](https://github.com/lflxp/gin-xterm/blob/master/src/views/pty/index.vue)

## Golang Websocket

1. 不需要解析Quit操作，那怎么判断程序结束去杀掉线程呢

解答：根据`exec.Command`的`cmd.Wait()`去判断，退出自动触发`quitChan <- true`去结束线程

2. 后端websocket使用的什么项目

解答： `github.com/gorilla/websocket`

3. 如何实现golang命令行exec.Command的结果实时联动操作的？

解答：通过pty/tty在linux启动一个pid线程实现的，具体资料如下：

* [Linux中tty、pty、pts的概念区别](https://blog.csdn.net/fuhanghang/article/details/83691158)
* [golang pty pkg](github.com/creack/pty)

4. gin或者go http如何做到websocket连接的切换？

解答：`http`升级为[websocket](github.com/gorilla/websocket)

```golang
...

import "github.com/gorilla/websocket"

var upGrader = websocket.Upgrader{
	ReadBufferSize:  1024 * 1024,
	WriteBufferSize: 1024 * 1024 * 10,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func ping(c *gin.Context) {
	//升级get请求为webSocket协议
	ws, err := upGrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
    defer ws.Close()
    
    // todo
    ...
}
```

5. 如何处理每个websocket的多个goroutine正常退出

解答：通过quit Channel + for select

```golang
// 发送命令的执行结果
// 不执行具体任务
func (this *ClientContext) Send(quitChan chan bool) {
	defer setQuit(quitChan)

	buf := make([]byte, 1024)

	for {
		select {
		case <-quitChan:
			log.Info("Close Send Channel")
			return
		default:
			// 读取命令执行结果并通过ws反馈给用户
			size, err := this.Pty.Read(buf)
			if err != nil {
				log.Errorf("%s命令执行错误退出: %s", this.Request.RemoteAddr, err.Error())
				return
			}
			log.Infof("Send Size: %d buf: %s buf[:size]: %s\n", size, string(buf), string(buf[:size]))
			if err = this.write(buf[:size]); err != nil {
				log.Error(err.Error())
				return
			}
		}
	}
}
```

6. 如何判断各种操作类型以及怎么执行

解答：

* 预先设计数据格式
* for select + switch

```golang
// 判断命令
// @Params msg:message
switch message[0] {
case Input:
    // TODO: 用户是否能写入
    if !this.Xtermjs.Options.PermitWrite {
        break
    }

    // base64解码
    decode, err := utils.DecodeBase64Bytes(string(message[1:]))
    if err != nil {
        log.Error(err.Error())
        break
    }

    // 向pty中传入执行命令
    _, err = this.Pty.Write(decode)
    if err != nil {
        log.Error(err.Error())
        return
    }
case Ping:
    this.write([]byte("pong"))
case ResizeTerminal:
    // @数据格式 type+rows:cols
    // base64解码
    decode, err := utils.DecodeBase64(string(message[1:]))
    if err != nil {
        log.Error(err.Error())
        break
    }

    tmp := strings.Split(decode, ":")
    rows, err := strconv.Atoi(tmp[0])
    if err != nil {
        log.Error(err.Error())
        this.write([]byte(err.Error()))
        break
    }
    cols, err := strconv.Atoi(tmp[1])
    if err != nil {
        log.Error(err.Error())
        this.write([]byte(err.Error()))
        break
    }
    window := struct {
        row uint16
        col uint16
        x   uint16
        y   uint16
    }{
        uint16(rows),
        uint16(cols),
        0,
        0,
    }
    syscall.Syscall(
        syscall.SYS_IOCTL,
        this.Pty.Fd(),
        syscall.TIOCSWINSZ,
        uintptr(unsafe.Pointer(&window)),
    )
default:
    this.write([]byte(fmt.Sprintf("Unknow Message Type %s", string(message[0]))))
    log.Error("Unknow Message Type %v", message[0])
}
```

7. 如何设置exec.Command在pty终端的窗口大小

解答：

```golang
window := struct {
    row uint16
    col uint16
    x   uint16
    y   uint16
}{
    uint16(rows),
    uint16(cols),
    0,
    0,
}
syscall.Syscall(
    syscall.SYS_IOCTL,
    this.Pty.Fd(),
    syscall.TIOCSWINSZ,
    uintptr(unsafe.Pointer(&window)),
)
```

8. 还需要注意什么

* 明确命令下发渠道和作用

> this.Pty.Write([]byte(***))

* 明确websocket下发渠道和作用

> this.WsConn.Write([]byte(***))

* 如何操作正在执行中的cmd程序

> this.Cmd.Process.Signal(syscall.Signal(this.Xtermjs.Options.CloseSignal))

* 明确一个exec.Command和一个webscoket.Conn如何对一个http请求保持长连接请求的

一个http.Request请求由cmd.Wait() + go Send() + go Receive() + Channel 将一个完整链路进行串联起来

* 如何下手？设计一个符合场景的struct

```golang
// 服务端内部处理对象
type ClientContext struct {
	Xtermjs    *XtermJs        // 前端配置
	Request    *http.Request   // http客户端请求
	WsConn     *websocket.Conn // websocket连接
	Cmd        *exec.Cmd       // exec.Command实例
	Pty        *os.File        // 命令行pty代理
	Cache      *bytes.Buffer   // 命令缓存
	CacheMutex *sync.Mutex     // 缓存并发锁
	WriteMutex *sync.Mutex     // 并发安全 通过ws发送给客户
}
```

## 参考

* https://github.com/yudai/gotty @release-1.0
* https://github.com/creack/pty
* https://mojotv.cn/2019/05/27/xtermjs-go