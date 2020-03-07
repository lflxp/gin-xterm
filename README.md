学习和了解gotty的实现原理，并基于gin-web + vue + xterm.js 实现了一套完整的功能

## 使用

`环境准备`：`npm` `go`

`前端` [gin-xterm](https://github.com/lflxp/gin-xterm)

```bash
git clone https://github.com/lflxp/gin-xterm
cd gin-xterm
make all
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

## 参考

* https://mojotv.cn/2019/05/27/xtermjs-go