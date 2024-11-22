/*  ————————————————————————————————————————————————————————————————————————  *
 *
 *      mraid.js
 *      ~~~~~~~~
 *
 *      Implementation of the MRAID API for ad creatives
 *      Project: AdSDK
 *      Target interpreter: WKWebView
 *      Created by Virtual Minds GmbH on 15.02.2024
 *      Copyright © 2024 Virtual Minds GmbH. All rights reserved.
 */

"use strict";

/*  ————————————————————————————————————————————————————————————————————————  *
 *
 *    Anonymous wrapper for the `window.mraid.core` & `window.mraid` scopes.
 */
(function (window)
{
    // Check if mraid.js is already initialized
    if (("mraid" in window) && ("core" in window.mraid) && ("open" in window.mraid.core))
    {
        // No multiple definition.
        window.console.log("Loading 'mraid.js' multiple times has no effect beyond this nagging note.");
        return false;
    }

    // Initialise sub-scopes.
    window.mraid = {};
    window.mraid.core = {};

    /*  ————————————————————————————————————————————————————————————————————————  *
     *
     *    The `window.mraid.core` scope.
     *
     *    Private interface between the MRAID JS tier and the device's native platform.
     *    Functions from this scope are used by the Host or inside the mraid.js file.
     */
    (function (mraid)
    {
        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    Host Command Interface
         *    
         *    The interface contains the main logic related to the transfer of information from Ad to WKWebView.
         */

        /**
         *  Container for command interface housekeeping.
         * 
         * store:
         *  - `urlLoaderList` - array of URL's to pass to the host
         *  - `urlLoaderBusy` - flag, that work like barrier to avoid several requests to the host
         *    at the same time.
         *
         *  [private]
         */
        var hostInterface = {};

        hostInterface.urlLoaderList = [];

        // Initially, set `urlLoaderBusy` so host commands are queued up until MRAID broadcasts “ready”.
        hostInterface.urlLoaderBusy = true;

        /**
         *  Requests the contents of the given URL as soon as the net interface is free.
         * 
         *  Sends a new URL to `WKWebView` for processing, or queues the URL via `hostInterface`
         *  if `WKWebView` has not yet notified MRAID that the previous URL has been processed.
         *
         *  @caller:    mraid.core.performHostCommand()
         *  @caller:    mraid.core.completedHostCommand()
         *  @flow:      JS —> Host
         *  [private]
         */
        var startLoadingURL = function (targetURL)
        {
            if (hostInterface.urlLoaderBusy)
            {
                // Queue up while `window.location` is being processed.
                hostInterface.urlLoaderList.push(targetURL);
            }
            else
            {
                // Flag `window.location` as occupied.
                hostInterface.urlLoaderBusy = true;
                window.location = targetURL;
            }
        };  // startLoadingURL()

        /**
         *  Makes the native tier perform an SDK-internal command.
         * 
         *  Builds an URL to send to WKWebView. After processing, it passes the URL to the
         *  `startLoadingURL(targetURL)` function.
         * 
         *  URL = "mraid://" + "cmdName" + "argsMap".
         *
         *  @caller:    mraid.core.*()
         *  @flow:      JS —> Host
         *  [private]
         */
        var performHostCommand = function (cmdName, argsMap)
        {
            if (typeof(cmdName) == "string" && cmdName.length != 0)
            {
                if (argsMap == null || argsMap.constructor == Object)
                {
                    var commandURL = "mraid://" + encodeURIComponent(cmdName);
                    if (argsMap != null && Object.keys(argsMap).length != 0)
                    {
                        var rawQuery = JSON.stringify(argsMap);

                        commandURL += "?" + encodeURIComponent(rawQuery);
                    }

                    startLoadingURL(commandURL);

                    // Signal (halfway) success.
                    return true;
                }
                else
                {
                    window.console.log("Error: Command arguments must be given as a map object.");
                    return false;
                }
            }
            else
            {
                window.console.log("Error: Host command name must be a non-empty string.");
                return false;
            }
        };  /* performHostCommand() */

        mraid.core.performHostCommand = performHostCommand;

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    Handler Management for Events from the SDK's Native OS
         * 
         *    The interface responsible for subscribing to events sent from WKWebView (Host).
         */

        /**
         *  Container for event handlers.
         * 
         *  An associative array that stores the names of events as keys and
         *  an array with lambdas that you want to run when this event is called as a values.
         *
         *  [private]
         */
        var sdkEventHandlers = {};

        /**
         *  Lets the ad-facing JS tier install handling functions for events of the named type.
         * 
         *  Using this function, this JS file can subscribe to error and change events by passing a lambda.
         *  Adds a lambda to the `sdkEventHandlers` under the passed `eventName`.
         *
         *  @caller:    JS
         */
        mraid.core.addEventHandler = function (eventName, handlerFun)
        {
            // Array of handlers for the named event.
            var handlers = sdkEventHandlers[eventName];
            if (handlers == null)
                handlers = sdkEventHandlers[eventName] = [];

            for (var ind in handlers)
            {
                // Handler already there.
                if (handlers[ind] == handlerFun)
                    return;
            }

            // Add new handler.
            handlers.push(handlerFun);
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    Entry Points from the Native Layer
         */

        /**
         *  Tells the JS layer that the Swift layer is done performing the most recent
         *  SDK-internal command.
         *
         *  @caller:    Host
         *  @flow:      Host —> JS
         */
        mraid.core.completedHostCommand = function ()
        {
            // Previous command is done being processed.
            hostInterface.urlLoaderBusy = false;

            if (hostInterface.urlLoaderList.length != 0)
            {
                // More commands have queued up in the meantime.
                startLoadingURL(hostInterface.urlLoaderList.shift());
            }

            return "OK";
        };

        /**
         *  Informs the the receiver that the native layer has detected an error.
         *
         *  @caller:    Host
         *  @flow:      Host —> JS —> Ad
         */
        mraid.core.fireErrorEvent = function (errorMessage, actionName)
        {
            var handlers = sdkEventHandlers["error"];
            if (handlers != null)
            {
                for (var i = 0; i < handlers.length; ++i)
                {
                    handlers[i](errorMessage, actionName);
                }
            }

            return "OK";
        };

        /**
         *  Informs the the receiver about indicated property value changes.
         *
         *  @caller:    Host
         *  @flow:      Host —> JS —> Ad
         */
        mraid.core.fireChangeEvent = function (propName, propData)
        {
            var handlers = sdkEventHandlers["change"];
            if (handlers != null)
            {
                for (var ind in handlers)
                {
                    handlers[ind](propName, propData);
                }
            }

            return "OK";
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    MRAID functions encapsulation
         * 
         */

        /**
         *  @caller:    JS
         *  @flow:      Ad —> JS —> Host
         *  @spec:      MRAID-v3.0
         */
        mraid.core.open = function (remoteURL)
        {
            return performHostCommand("open", {
                url:              remoteURL
            });
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    ADITION API JS
         */

        if (! ("console" in window))
        {
            window.console = {};
        }

        /**
         *  Maps console.log() to an SDK-internal command
         *  making the message appear in the device log.
         */
        window.console.log = function ()
        {
            var text = "";
            var upr = arguments.length - 1;
            for (var ind = 0; ind <= upr; ++ind)
            {
                var sub = arguments[ind];
                if (typeof(sub) != "string")
                try {
                    sub = JSON.stringify(sub);
                } catch (error) {
                    sub = "[Error in JSON.stringify() for this object]";
                }
                if (ind > 0 && ind < upr)
                    text += ": ";
                text += sub;
            }

            return performHostCommand("consoleLog", {
                text:             text
            });
        };

        /**
         *  Rudimentary console.error() implementation.
         */
        window.console.error = function ()
        {
            var text = "[ERROR]:  ";
            var upr = arguments.length - 1;
            for (var ind = 0; ind <= upr; ++ind)
            {
                var sub = arguments[ind];
                if (typeof(sub) != "string")
                try {
                    sub = JSON.stringify(sub);
                } catch (error) {
                    sub = "[Error in JSON.stringify() for this object]";
                }
                if (ind > 0 && ind < upr)
                    text += ": ";
                text += sub;
            }

            return performHostCommand("consoleLog", {
                text:             text
            });
        };

        /**
         *  @spec:      ADITION
         */
        mraid.core.adsdkFireEvent = function (eventName, infoText)
        {
            return performHostCommand("adsdkFireEvent", {
            name:             eventName,
            info:             infoText
            });
        };

    })(window.mraid);      // `mraid.core` scope


    /*  ————————————————————————————————————————————————————————————————————————  *
     *
     *    The `window.mraid` scope.
     *
     *    Public high-level part of the MRAID API, facing the ad creative.
     */
    (function (mraid)
    {
        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    Public Constants
         */

        /**
         *  The names of MRAID creative states.
         */
        var STATES = mraid.STATES =
        {
            LOADING:            "loading",              // Before “ready” event.
            DEFAULT:            "default",              // After “ready” event.
            RESIZED:            "resized",              // After mraid.resize().
            EXPANDED:           "expanded",             // After mraid.expand().
            HIDDEN:             "hidden"                // After interstitial closed.
        };

        /**
         *  The names of handled events.
         */
        var EVENTS = mraid.EVENTS =
        {
            INFO:               "info",                 // ADITION
            ERROR:              "error",                // MRAID
            READY:              "ready",                // MRAID
            SIZECHANGE:         "sizeChange",           // MRAID
            STATECHANGE:        "stateChange",          // MRAID
            EXPOSURECHANGE:     "exposureChange"        // MRAID
        };

        /**
         *  Names of features that MRAID can theoretically support.
         *
         *  The values are keys into the “creative.supports” map.
         */
        var FEATURES = mraid.FEATURES =
        {
            PHONE:              "tel",                  // MRAID: Opens “tel:” URLs
            CALENDAR:           "calendar",             // MRAID: Calendar events
            INLVIDEO:           "inlineVideo",          // MRAID: Video player in HTML tag
            VPAID:              "vpaid",                // MRAID: VPAID handshake
            LOCATION:           "location"              // MRAID: Host's location data access
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    Internal Creative Properties
         */

        /**
         *  Container for creative properties.
         *
         *  Values are set at runtime by the SDK's native layer via the change
         *  handlers, using the mraid.core.fireChangeEvent() function.
         *
         *  [private]
         */
        var creative = {};

        creative.supports =
        {
            "tel":              false,
            "calendar":         false,                  // MRAID
            "inlineVideo":      false,                  // MRAID
            "vpaid":            false,                  // MRAID
            "location":         false                   // MRAID
        };

        creative.state          = STATES.LOADING;


        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    MRAID Event Dispatching
         */

        /**
         *  Container for MRAID event listener sets.
         *
         *  @type:  map «event name» ➜ «EventListenerSet»
         *
         *  [private]
         */
        var eventListeners = {};

        /**
         *  Class representing a bunch of MRAID event listeners,
         *  all listening for the same event.
         *
         *  [private]
         */
        var EventListenerSet = function (eventName)
        {
            // Private Instance Variables.
            var listenerMap = {};

            // Public Instance Variables.
            this.count = 0;

            // Add listener to the set.
            this.add = function (listenerFun)
            {
                var key = String(listenerFun);
                if (listenerMap[key] == null)
                {
                    listenerMap[key] = listenerFun;
                }
            };

            // Removes listener from the set.
            this.remove = function (listenerFun)
            {
                var key = String(listenerFun);
                if (listenerMap[key] != null)
                {
                    listenerMap[key] = null;
                    delete listenerMap[key];

                    return true;
                }
                else
                {
                    return false;
                }
            };

            // Removes all listeners from the set.
            this.removeAll = function ()
            {
                for (var key in listenerMap)
                {
                    this.remove(listenerMap[key]);
                }
            };

            // Emit passed arguments to all listeners.
            this.broadcast = function (args)
            {
                for (var key in listenerMap)
                {
                    listenerMap[key].apply(null, args);
                }
            };

            // Transorm set to the string for debuging.
            this.toString = function ()
            {
                var out = [eventName, ":"];
                for (var key in listenerMap)
                {
                    out.push("|", key, "|");
                }

                return out.join("");
            };
        };

        /**
         *  Broadcasts the event named in the 1st argument, passing
         *  all other arguments to any listener functions.
         *  [private]
         */
        var broadcastEvent = function (varargs)
        {
            var arglist = Array.prototype.slice.call(arguments);

            var eventName = arglist.shift();

            if (eventListeners[eventName] != null)
            {
                eventListeners[eventName].broadcast(arglist);
            }
            else
            if (eventName == EVENTS.ERROR)
            {
                window.console.log("Error: "+arglist[0]);
            }
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    Utility Functions
         */

        /**
         *  Container for utility functions.
         *
         *  [private]
         */
        var util = {};

        // Check if value is on an object
        util.memberp = function (value, container)
        {
            // `container.indexOf(value)` doesn't work with maps.
            for (var ind in container)
            {
                if (container[ind] == value)
                    return true;
            }
            return false;
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    Private Property Change Handlers
         *
         *    These handlers are used to apply value updates from the SDK's native
         *    layer to the private properties maintained by this API closure.
         *    Some of these handlers might trigger event listeners installed by a
         *    creative developer's user code.
         */

        /**
         *  Container for property change handlers.
         *
         *  @type:      map «propertyName» ➜ «function (newValue) ...»
         *  @note:      Since these functions are applied by the SDK native layer
         *              only, arguments are assumed to always be of the correct
         *              type and in the valid range.
         *
         *  [private]
         */
        var propertyChanger = {};

        /**
         *  Change handler for the “supports” property.
         *
         *  @flow:      Host —> JS
         *  @spec:      MRAID-v3.0
         *  [private]
         */
        propertyChanger["supports"] = function (newValue)
        {
            broadcastEvent(EVENTS.INFO, "Setting supports: " + JSON.stringify(newValue));
            creative.supports = {};
            for (var key in FEATURES)
            {
                creative.supports[FEATURES[key]] = util.memberp(FEATURES[key], newValue);
            }
        };

        /**
         *  Change handler for the “state” property.
         *
         *  @flow:      Host —> JS
         *  @spec:      MRAID-v3.0
         *  [private]
         */
        propertyChanger["state"] = function (newValue)
        {
            broadcastEvent(EVENTS.INFO, "Setting state: " + JSON.stringify(newValue));
            creative.state = newValue;
            broadcastEvent(EVENTS.STATECHANGE, creative.state);
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    Event dispatchers that connect status updates from the native layer with
         *    private creative property storage and user-defined event handlers.
         */

        /**
         *  Dispatcher for “change” events.
         *
         *  @caller:    mraid.core.fireChangeEvent()
         *  @flow:      Host —> JS
         *  @spec:      MRAID-v3.0
         */
        mraid.core.addEventHandler("change", function (propName, propData)
        {
            if (propName in propertyChanger)
            {
                propertyChanger[propName](propData);
            }
            else
            {
                window.console.log("Error: There is no change handler for the '"+String(propName)+"' property.");
            }
        });

        /**
         *  Dispatcher for “error” events.
         *
         *  @user:      mraid.core.fireErrorEvent()
         *  @flow:      Host —> JS
         *  @spec:      MRAID-v3.0
         */
        mraid.core.addEventHandler("error", function (errorMessage, actionName)
        {
            broadcastEvent(EVENTS.ERROR, errorMessage, actionName);
        });

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    MRAID API functions
         * 
         *    A public interface wich implement MRAID 3.0 functions.
         */

        /**
         *  Checks for the existence of an MRAID “ready” event listener and runs it.
         *  If a listener is not installed yet, reschedules itself until a listener
         *  is found or the allotted waiting time ran out.
         *
         *  This function is applied by the native ObjC tier as soon as the SDK's
         *  MRAID state is deemed to be ready for operation.
         *
         *  @param  startStampMillis    [ms]
         *              The `Date.now()` from when function was first applied.
         *
         *  @param  retryAfterMillis    [ms]
         *              Number of milliseconds after which to reschedule self.
         *
         *  @param  ceaseAfterMillis    [ms]
         *              Number of milliseconds after which to give up waiting.
         *
         *  @flow:      Host —> JS
         */
        mraid.core.postReady = function (startStampMillis, retryAfterMillis, ceaseAfterMillis)
        {
            var millisWaited = Date.now() - startStampMillis;

            var listenerSet = eventListeners["ready"];
            if (listenerSet != null)
            {
                // There is at least one listener registered.
                broadcastEvent(EVENTS.INFO, "Running MRAID 'ready' event listener after "+String(millisWaited / 1000.0)+" s.");

                // MRAID-v3.0: “ready” should only fire when the container is completely prepared for any MRAID request.
                listenerSet.broadcast();

                // Undefine this rigging.
                delete mraid.core["postReady"];
            }
            else
            {
                if (millisWaited < ceaseAfterMillis)
                {
                    // Reschedule with same arguments.
                    window.setTimeout(mraid.core.postReady, retryAfterMillis,
                                      startStampMillis,
                                      retryAfterMillis,
                                      ceaseAfterMillis);
                }
                else
                {
                    // Give up waiting.
                    broadcastEvent(EVENTS.INFO, "Giving up looking for MRAID 'ready' event listener after "+String(millisWaited / 1000.0)+" s.");

                    // Undefine this rigging.
                    delete mraid.core["postReady"];
                }
            }
        };

        /**
         *  Getter for the API Specification Version Number.
         * 
         *  The version number indicates the version of MRAID that the host supports
         *  (1.0, 2.0, or 3.0, etc.), NOT the version of the vendor's SDK.
         *
         *  @flow:      Ad —> JS
         *  @spec:      MRAID-v3.0
         */
        mraid.getVersion = function ()
        {
            return "3.0";
        };

        /**
         *  The ad calls this function to register a specific listener for a specific event.
         * 
         *  Supported events can be found in mraid.EVENTS.
         * 
         *  @flow:      Ad —> JS
         *  @spec:      MRAID-v3.0
         */
        mraid.addEventListener = function (eventName, listenerFun)
        {
            if (typeof(eventName) != "string" || eventName.length == 0)
            {
                broadcastEvent(EVENTS.ERROR, "Argument for <eventName> must be a non-empty string.", "addEventListener");
                return false;
            }
            else
            if (typeof(listenerFun) != "function")
            {
                broadcastEvent(EVENTS.ERROR, "Argument for <listenerFun> must be a function.", "addEventListener");
                return false;
            }
            else
            if (! util.memberp(eventName, EVENTS))
            {
                broadcastEvent(EVENTS.ERROR, "Unknown event name: '"+eventName+"'", "addEventListener");
                return false;
            }
            else
            {
                if (eventListeners[eventName] == null)
                    eventListeners[eventName] = new EventListenerSet(eventName);

                eventListeners[eventName].add(listenerFun);
                return true;
            }
        };

        /**
         *  When the ad no longer needs notification of a particular event,
         *  this function is used to unregister to that event.
         * 
         *  @flow:      Ad —> JS
         *  @spec:      MRAID-v3.0
         */
        mraid.removeEventListener = function (eventName, listenerFun)
        {
            if (typeof(eventName) != "string" || eventName.length == 0)
            {
                broadcastEvent(EVENTS.ERROR, "Argument for <eventName> must be a non-empty string.", "removeEventListener");
                return false;
            }
            else
            {
                var listenerSet = eventListeners[eventName];
                if (listenerSet != null)
                {
                  // Something to remove.
                  if (listenerFun != null)
                  {
                    // Remove named listener.
                    listenerSet.remove(listenerFun);
                  }
                  else
                  {
                    // Remove all listeners.
                    listenerSet.removeAll();
                  }

                  if (listenerSet.count == 0)
                  {
                    delete eventListeners[eventName];
                  }
                }
                return true;
            }
        };

        /**
         *  Shows the contents of the given URL in an external browser.
         *
         *  @flow:      Ad —> JS —> Host —> IOS Browser
         *  @spec:      MRAID-v3.0
         */
        mraid.open = function (remoteURL)
        {
            if (remoteURL == null)
            {
                broadcastEvent(EVENTS.ERROR, "Argument for <remoteURL> is missing.", "open");
                return false;
            }
            else
            {
                return mraid.core.open(remoteURL);
            }
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    MRAID API Properties
         * 
         *    A public interface wich implement MRAID 3.0 properties.
         */

        /**
         *  The ad can use the this property to query the host about which
         *  device-native features the app can access.
         * 
         *  All native features can be found in mraid.FEATURES.
         * 
         *  @flow:      Ad —> JS
         *  @spec:      MRAID-v3.0
         */
        mraid.supports = function (feature)
        {
            return !! creative.supports[feature];
        };

        /**
         *  The ad may use this function to query the host about the state of
         *  the ad container and make requests accordingly.
         * 
         *  All states can be found in mraid.STATES.
         * 
         *  @flow:      Ad —> JS
         *  @spec:      MRAID-v3.0
         */
        mraid.getState = function ()
        {
            return creative.state;
        };

        /*  ————————————————————————————————————————————————————————————————————————  *
         *
         *    ADITION AdSDK Extensions
         *
         *    These functions are specific to the ADITION implementation of MRAID.
         */

        if (! ("AdSDK" in window))
        {
            window.AdSDK = {};
        }

        var AdSDK = window.AdSDK;

        /**
         *  Passes a user-defined status message to the host app.
         *
         *  @flow:      Ad —> JS —> Host
         *  @spec:      ADITION
         */
        AdSDK.fireEvent = function (eventName, infoText)
        {
            if (typeof(eventName) != "string" || eventName.length == 0)
            {
                broadcastEvent(EVENTS.ERROR, "Argument for <eventName> must be a non-empty string.", "AdSDK.fireEvent");
                return false;
            }
            else
            {
                return mraid.core.adsdkFireEvent(eventName, (infoText == null) ? "" : String(infoText));
            }
        };

        /**
         *  A utility for sending an arbitrary signal to any external
         *  service, whithout expecting any data to be returned.
         *
         *  • Irrespective of the oversimplified implementation and the
         *    bad name, this is supposed to be part of the AdServer API.
         *
         *  @flow:      Ad —> JS —> WebKitHTTP
         *  @spec:      ADITION
         */
        AdSDK.bannerEvent = function (remoteURL) // TODO: - Understend what is it
        {
            if (typeof(remoteURL) != "string" || remoteURL.length == 0)
            {
                broadcastEvent(EVENTS.ERROR, "Argument for <remoteURL> must be a non-empty string.", "AdSDK.bannerEvent");
                return false;
            }
            else
            {
                var domImg = window.document.createElement("img");
                domImg.src = remoteURL;
                return true;
            }
        };

    })(window.mraid);   // `window.mraid` scope

    // WebKit seems to have a long-standing “feature”:  If the client
    // JS dynamically inserts a <script> node into the document <head>
    // then NO `window.onload` listener will be run, no matter when
    // or where it was installed.
    window.document.addEventListener("readystatechange", function (event)
    {
        // Store interesting state for later inspection.
        window.mraid.$documentReadyEvent = event;
        window.mraid.$documentReadyState = window.document.readyState;

        // For SPON, we need to be able to run toplevel JS in the creative and
        // have the host app process any results thereof before MRAID “ready”
        // is posted and its listener is run.
        if (window.document.readyState == "complete")
        {
            // Tell the host app that `window.onload` listeners start running now.
            // Toplevel JS has run by the time the SDK performs this command.
            window.mraid.core.performHostCommand("jsWindowDidLoadDOM");
        }
    });

    window.addEventListener("load", function (event)
    {
        // Store interesting state for later inspection.
        window.mraid.$windowLoadEvent = event;
        window.mraid.$windowLoadState = window.document.readyState;
    });

    // Do this last. If any error from above breaks the load, this won't be set.
    window.mraid.$loaded = true;

})(window);     // Wrapper scope


/* ~ mraid.js ~ */


