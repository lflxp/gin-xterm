<template>
  <div
    style="height: 100%;
    background: #002833;"
  >
    <div id="terminal" ref="terminal" />
  </div>
</template>

<script>
// 引入xterm，请注意这里和3.x版本的引入路径不一样
import { Terminal } from 'xterm'
// import 'xterm/css/xterm.css'
// import 'xterm/lib/xterm.js'
import { WebLinksAddon } from 'xterm-addon-web-links'
// import { AttachAddon } from 'xterm-addon-attach'
import { FitAddon } from 'xterm-addon-fit'
import { SearchAddon } from 'xterm-addon-search'

export default {
  name: 'Shell',
  data() {
    return {
      shellWs: '',
      term: '', // 保存terminal实例
      rows: 40,
      cols: 100
    }
  },
  // created() {
  //   this.wsShell()
  // },
  mounted() {
    const _this = this
    // 获取容器宽高/字号大小，定义行数和列数
    // https://www.cnblogs.com/lhl66/p/7908133.html
    this.rows = document.body.clientHeight / 16 - 5
    this.cols = document.body.clientWidth / 14

    // 实例化terminal实例
    const term = new Terminal({
      rendererType: 'canvas', // 渲染类型
      rows: parseInt(_this.rows), // 行数
      cols: parseInt(_this.cols), // 不指定行数，自动回车后光标从下一行开始
      convertEol: true, // 启用时，光标将设置为下一行的开头
      scrollback: 50, // 终端中的回滚量
      disableStdin: false, // 是否应禁用输入。
      cursorStyle: 'underline', // 光标样式
      cursorBlink: true, // 光标闪烁
      theme: {
        foreground: '#7e9192', // 字体
        background: '#002833', // 背景色
        cursor: 'help', // 设置光标
        lineHeight: 16
      }
    })

    const ws = new WebSocket('ws://127.0.0.1:8888/api/ws/ping4')
    ws.onopen = function(evt) {
      console.log('OPEN')
    }
    ws.onclose = function(evt) {
      term.writeln('CLOSE')
      // ws = null
      ws.close()
    }

    ws.onmessage = function(evt) {
      console.log(evt.data)
      evt.data.split('\n').forEach(v => {
        term.write('\r\n' + v.replace(/^\s+|\s+$/g, ''))
      })
      term.prompt()
    }
    ws.onerror = function(evt) {
      term.writeln('ERROR: ' + evt.data)
    }

    // An addon for xterm.js that enables attaching to a web socket. This addon requires xterm.js v4+.
    // const attachAddon = new AttachAddon(ws)
    const fitAddon = new FitAddon()
    const searchAddon = new SearchAddon()
    // term.loadAddon(attachAddon)
    // Load WebLinksAddon on terminal, this is all that's needed to get web links
    // working in the terminal.
    term.loadAddon(new WebLinksAddon())
    term.loadAddon(searchAddon)

    // 挂载到dom
    term.open(this.$refs['terminal'])

    fitAddon.fit()

    // 换行并输入起始符“$”
    term.prompt = () => {
      term.write('\r$ ')
    }
    term.prompt()

    function runFakeTerminal(_this) {
      if (term._initialized) {
        return
      }
      // 初始化
      term._initialized = true

      term.writeln('Welcome to \x1B[1;3;31mxterm.js\x1B[0m')
      term.writeln('This is a local terminal emulation, without a real terminal in the back-end.')
      term.writeln('Type some keys and commands to play around.')

      term.prompt()

      // / **
      //     *添加事件监听器，用于按下键时的事件。事件值包含
      //     *将在data事件以及DOM事件中发送的字符串
      //     *触发了它。
      //     * @返回一个IDisposable停止监听。
      //  * /
      //   / ** 更新：xterm 4.x（新增）
      //  *为数据事件触发时添加事件侦听器。发生这种情况
      //  *用户输入或粘贴到终端时的示例。事件值
      //  *是`string`结果的结果，在典型的设置中，应该通过
      //  *到支持pty。
      //  * @返回一个IDisposable停止监听。
      //  * /
      // 支持输入与粘贴方法
      // term.onData(function(e) {
      //   console.log('onData', e)
      //   // const order = {
      //   //   Data: e,
      //   //   Op: 'stdin'
      //   // }

      //   // _this.onSend(order)
      // })

      // term.onKey(e => {
      //   const printable = !e.domEvent.altKey && !e.domEvent.altGraphKey && !e.domEvent.ctrlKey && !e.domEvent.metaKey

      //   if (e.domEvent.keyCode === 13) {
      //     // term.prompt()
      //     // this.prompt(term)
      //     ws.send(e.key)
      //   } else if (e.domEvent.keyCode === 8) {
      //     // Do not delete the prompt
      //     if (term._core.buffer.x > 2) {
      //       term.write('\b \b')
      //     }
      //   } else if (printable) {
      //     term.write(e.key)
      //     ws.send(e.key)
      //   }
      // })

      term.onKey(e => {
        const printable = !e.domEvent.altKey && !e.domEvent.altGraphKey && !e.domEvent.ctrlKey && !e.domEvent.metaKey
        if (e.domEvent.keyCode === 13) {
          // term.prompt()
          // term.write('\r\n')
          ws.send(e.key)
        } else if (e.domEvent.keyCode === 8) {
          if (term._core.buffer.x > 2) {
            term.write('\b \b')
          }
        } else if (printable) {
          term.write(e.key)
          ws.send(e.key)
        } else {
          ws.send(e.key)
        }
      })

      // setInterval(() => {
      //   ws.send('clear\r\n')
      // }, 1000)
      _this.term = term
    }
    runFakeTerminal(_this)
  },

  methods: {
    onSend(data) {
      // data = this.base.isObject(data) ? JSON.stringify(data) : data
      // data = this.base.isArray(data) ? data.toString() : data
      // data = data.replace(/\\\\/, '\\')
      // this.shellWs.onSend(data)
      console.log(data)
    },

    // 删除左右两端的空格
    trim(str) {
      return str.replace(/(^\s*)|(\s*$)/g, '')
    }
  }
}
</script>
