# Tether

Tether your unjailbroken iPhone to your desktop computer via USB for free*! This was inspired by [iProxy](https://github.com/udibr/iProxy), but I always had trouble getting the damn ad-hoc wifi network to work reliably.

Right now this is mainly proof-of-concept... but it works! It will let you create a SOCKS proxy running on your iPhone and mirror the socket to your local machine over USB via usbmuxd.

## Instructions

### Getting the Code

	$ git clone git@github.com:chrisballinger/Tether-iOS.git
	$ cd Tether-iOS
	$ git submodule update --init --recursive

### Installing Tether (iOS)

Open `Tether.xcodeproj` and select the `Tether` target and install it on your iPhone. This will start a SOCKS proxy on port `8123` on the phone, but be warned that you must keep the app in the foreground to accept new sockets. Currently the app is just a blank white screen. You can theoretically use any other SOCKS proxy app instead but I haven't tested this.

### Installing TetherMac 

Now build the `TetherMac` target and run it on your local machine. This will create a local listening socket on port `8000` that forwards everything to port `8123` on the phone over USB.

### Configuring Firefox

Open up Firefox and go to Preferences -> Advanced -> Network -> Manual Proxy Configuration. **Important**: make sure to delete the entries and ports for HTTP proxy, SSL proxy and FTP proxy or Firefox will use those instead of the SOCKS proxy settings. Enter `127.0.0.1` for SOCKS Host and `8000` for the port and make sure SOCKS v5 is selected. 

Now go to `about:config` in the address bar and change `network.proxy.socks_remote_dns` to `true`. This will make sure you resolve domain names over the SOCKS proxy instead of on your local machine.

### Problems Connecting? Try this.

1. Close Tether, TetherMac and Firefox.
2. Open up the Tether iOS app and keep it in the foreground.
3. Connect your iPhone to your computer with a USB cable.
4. Open up TetherMac.
5. Open up Firefox and double-check your proxy settings.

## Caveats / TODO

* The interface isn't very user friendly, so it would be nice to pretty it up a bit.
* In order to install the iOS app you need a $99/yr iOS Apple Developer account, or a friend with one willing to install it for you.
* It would be nice to also tether your iPhone to your iPad via [MultipeerConnectivity framework](https://developer.apple.com/library/ios/documentation/MultipeerConnectivity/Reference/MultipeerConnectivityFramework/Introduction/Introduction.html) but I heard it's pretty slow in practice.
* You must keep the iOS app in the foreground to accept new connections. Once a connection has been established you can background the app for short times without interrupting your active connections by pretending to be a VoIP app.
* Not all of your internet traffic can go over a SOCKS proxy. Possible solution to investigate is [tun2socks](https://code.google.com/p/badvpn/wiki/tun2socks). I made [some progress porting it to Mac OS X](https://github.com/chrisballinger/badvpn/tree/darwin).
* This shit leaks memory all over the place.


## Dependencies

* [ProxyKit](https://github.com/chrisballinger/proxykit) - Objective-C SOCKS 5 / RFC 1928 proxy server and socket client libraries built upon GCDAsyncSocket.
* [libusbmuxd](https://github.com/libimobiledevice/libusbmuxd) - A client library to multiplex USB connections from and to iOS devices.


## Author

[Chris Ballinger](https://github.com/chrisballinger)

[![bitcoin](https://coinbase.com/assets/buttons/donation_large-6ec72b1a9eec516944e50a22aca7db35.png)](https://coinbase.com/checkouts/1cf35f00d722205726f50b940786c413) [![donation](https://chatsecure.org/static/images/paypal_donate.png)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=XRBHJ9AX5VWNA) 

## License

GPLv3+