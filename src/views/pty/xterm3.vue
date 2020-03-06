<template>
  <div>
    <el-button type="text" @click="v = true">点击打开 Dialog</el-button>
    <el-dialog
      :visible.sync="v"
      title="xp@127.0.0.1"
      center
      fullscreen
      @opened="doOpened"
      @open="doOpen"
      @close="doClose"
      :modal="false"
      :destroy-on-close="true"
    >

      <div ref="terminal"></div>

    </el-dialog>
  </div>
</template>

<script>
import { Terminal } from 'xterm'
import * as fit from 'xterm/lib/addons/fit/fit'
import { Base64 } from 'js-base64'
import * as webLinks from 'xterm/lib/addons/webLinks/webLinks'
import * as search from 'xterm/lib/addons/search/search'

import 'xterm/lib/addons/fullscreen/fullscreen.css'
import 'xterm/dist/xterm.css'
// import config from '@/config/config'

const defaultTheme = {
  foreground: '#ffffff',
  background: '#1b212f',
  cursor: '#ffffff',
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
const bindTerminalResize = (term, websocket) => {
  const onTermResize = size => {
    websocket.send(
      JSON.stringify({
        type: 'resize',
        rows: size.rows,
        cols: size.cols
      })
    )
  }
  // register resize event.
  term.on('resize', onTermResize)
  // unregister resize event when WebSocket closed.
  websocket.addEventListener('close', function() {
    term.off('resize', onTermResize)
  })
}
const bindTerminal = (term, websocket, bidirectional, bufferedTime) => {
  term.write('\r\nWelcome to Felix Web Ssh Terminal\n\r\n')
  term.socket = websocket
  let messageBuffer = null
  const handleWebSocketMessage = function(ev) {
    if (bufferedTime && bufferedTime > 0) {
      if (messageBuffer) {
        messageBuffer += ev.data
      } else {
        messageBuffer = ev.data
        setTimeout(function() {
          term.write(messageBuffer)
        }, bufferedTime)
      }
    } else {
      term.write(ev.data)
    }
  }

  const handleTerminalData = function(data) {
    // websocket.send(
    //   JSON.stringify({
    //     type: 'cmd',
    //     cmd: Base64.encode(data) // encode data as base64 format
    //   })
    // )
    websocket.send(data)
    console.log(data)

    if (data === '\r') {
      term.write('\r\n' + data)
    } else {
      term.write(data)
    }
  }

  websocket.onmessage = handleWebSocketMessage
  if (bidirectional) {
    term.on('data', handleTerminalData)
  }

  // send heartbeat package to avoid closing webSocket connection in some proxy environmental such as nginx.
  const heartBeatTimer = setInterval(function() {
    websocket.send(JSON.stringify({ type: 'heartbeat', data: '' }))
  }, 20 * 1000)

  websocket.addEventListener('close', function() {
    websocket.removeEventListener('message', handleWebSocketMessage)
    term.off('data', handleTerminalData)
    delete term.socket
    clearInterval(heartBeatTimer)
  })
}
export default {
  name: 'CompTerm',
  props: { obj: { type: Object, require: true }, visible: Boolean },
  data() {
    return {
      isFullScreen: false,
      searchKey: '',
      v: this.visible,
      ws: null,
      term: null,
      thisV: this.visible
    }
  },
  computed: {
    wsUrl() {
      //   const token = localStorage.getItem('token')
      //   return `${config.wsBase}/api/ws/${this.obj.ID || 0}?cols=${this.term.cols}&rows=${this.term.rows}&_t=${token}`
      return 'ws://127.0.0.1:8888/api/ws/ping4'
    }
  },
  watch: {
    visible(val) {
      this.v = val// 新增result的watch，监听变更并同步到myResult上
    }
  },

  methods: {

    onWindowResize() {
      // console.log("resize")
      this.term.fit() // it will make terminal resized.
    },
    doLink(ev, url) {
      if (ev.type === 'click') {
        window.open(url)
      }
    },
    doClose() {
      window.removeEventListener('resize', this.onWindowResize)
      // term.off("resize", this.onTerminalResize);
      if (this.ws) {
        this.ws.close()
      }
      if (this.term) {
        this.term.dispose()
      }
      this.$emit('pclose', false)// 子组件对openStatus修改后向父组件发送事件通知
    },
    doOpen() {

    },
    doOpened() {
      Terminal.applyAddon(fit)
      Terminal.applyAddon(webLinks)
      Terminal.applyAddon(search)
      this.term = new Terminal({
        rows: 35,
        fontSize: 18,
        cursorBlink: true,
        cursorStyle: 'bar',
        bellStyle: 'sound',
        theme: defaultTheme
      })
      this.term.open(this.$refs.terminal)
      this.term.webLinksInit(this.doLink)
      // term.on("resize", this.onTerminalResize);
      window.addEventListener('resize', this.onWindowResize)
      this.term.fit() // first resizing
      this.ws = new WebSocket('ws://127.0.0.1:8888/api/ws/ping4')
      this.ws.onerror = () => {
        this.$message.error('ws has no token, please login first')
        this.$router.push({ name: 'login' })
      }

      this.ws.onclose = () => {
        this.term.setOption('cursorBlink', false)
        this.$message('console.web_socket_disconnect')
      }
      bindTerminal(this.term, this.ws, true, -1)
      bindTerminalResize(this.term, this.ws)
    }

  }

}
</script>

<style scoped>

</style>
