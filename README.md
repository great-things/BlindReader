# BlindReader - easy data access without looking

Please note: this is a very early version of this software. While it is reasonably easy to use *when configured*, configuring it requires some technical knowledge and some time. Basically, if you have no clue what to do after reading the "Setup" section, this project is probably in such an early state that you will not be happy with it. Work in progress.

## Motivation

Sometimes, people do not have the ability - or the desire - to look at screens, but they still want to get access to information from the internet. BlindReader wants to enable you to look up certain things without needing to see things, and without the learning curve a standard screen reader has.

## Setup

BlindReader is implemented as a web app that requires a server in the backend (may change in the future).

You will need a web server (on the internet or local) with the following setup:

* `index.html` from this repository should be put here: `<serverRoot>/app/blindReader/index.html`

* The `resources` folder from this repository should be put here: `<serverRoot>/app/blindReader/resources`

* There has to be a server endpoint at `<serverRoot>/api/loadUrl` which, when used with the parameter `query=<url>` (`/api/loadUrl?query=<url>`), loads the contents of the `<url>` URL and returns it as the HTTP response body

* Put a file in `<serverRoot>/app/blindReader/resources/rootHierarchy.json` and fill it according to the guide in the "rootHierarchy.json" section of this document

* Right now, there is only a German default configuration of this project. If you want to use this app in any other language, open `<serverRoot>/app/blindReader/resources/config.json` and change all the strings accordingly (the JSON keys should give you a hint about the meaning of the strings)

After you have done all that, you can access the app at `<serverRoot>/app/blindReader`

### rootHierarchy.json

The "rootHierarchy.json" file at `/app/blindReader/resources/rootHierarchy.json` is the main configuration file of this app, containing all the resources that are accessible to the user.

It contains a JSON object with the following keys:

* `"root"` is an array with a bunch of objects that describe the root layer of the navigation. Each item in there has the following keys:
  
  * `"title"`: The name of this item. Will be read aloud by the app
  
  * `"input"`: Usually a URL pointing to a RSS resouce. In put into whatever function is referenced by `"generatorFunction"`
  
  * `"generatorFunction"`: The name (as a string) of a built-in functoin that can handle the value (usually the URL) behind `"input"`. Currently, the following functions are supported:
    
    * `"rssFeedTreeGenerator"` can deal with an RSS feed and makes all the items accessible
    
    * `"tvPrimetimeTreeGenerator"` can deal with an RSS feed and only makes the items containing "20:15" in their title accessible

* `"allowedDomains"` is an array containing domains (strings; like `"www.something.com"`) of web resources that the app should be able to access. This is a security feature; no online resource that is not behind these domains is accessible

## Usage

There are two modes of this app: the setup mode (which may require a person who can see), and the main mode (which does not require the ability to see).

### setup mode

Before you can use the app in its main mode, you have to select a voice from the dropdown. You can test-listen to it using the button next to it (says something like "Listen to voice"), and finish the setup using the second button (says something like "Select voice").

### main mode

The main navigation is built as a bunch of layers (rootHierarchy.json defines the first layer) which can have items (also called sections).

The navigation works like this:

* Tap: go to the next section

* Long tap: go to the previous section

* Left-to-right swipe: Go one layer deeper

* Right-to-left swipe: Go one layer up

* Two-finger tap: Figure out where you are in the hierarchy

Each of these actions triggers voice output or some other sound, so you know when the app has noticed your input
