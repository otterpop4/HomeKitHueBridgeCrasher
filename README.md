# HomeKitHueBridgeCrasher
Sample app for iOS HomeKit to reproduce bug that crashes Philips Hue bridge (v 2.0)

The app uses HomeKit to communicate with the Hue Bridge, where light attributes are set via ‘HMCharacteristic writes'. In the app, writes are serialized on a per-characteristic basis; a new write is only made to the same characteristic once the completion handler for the -writeValue: method is returned for the previous write to that same characteristic.

The app can configure number of concurrent characteristic writes in the UI. It also has a timer that displays how much time has elapsed since the last successful characteristic write (as measured by the receipt of a completion handler for that characteristic). When this timer starts to grow unbounded, it’s clear that the Hue Bridge has become unresponsive. If you try to interact with the Hue Bridge using other apps on other devices, the Hue Bridge remains unresponsive until a power-cycle.

The app quickly gets the bridge in this unresponsive state with 40 concurrent writes, but I have managed to crash the bridge with a much lower number (as low as 2). Make sure that you have plenty of lights connected to allow for concurrent lights (a normal Hue lightbulb will have 3 characteristics to set).
