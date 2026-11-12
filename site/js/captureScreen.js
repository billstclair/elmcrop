//////////////////////////////////////////////////////////////////////
//
// captureScreen.js
// JavaScript runtime code to capture screen.
// Requires the browser to have "Screen & System Audio Recording" (Mac)
// permission in system settings, and permission to capture the screen.
// Copyright (c) 2026 Bill St. Clair <billstclair@gmail.com>
// Some rights reserved.
// Distributed under the MIT License
// See LICENSE.txt
//
//////////////////////////////////////////////////////////////////////

(function(scope) {

  // displaySurface is "monitor" or "window".
  // which is 'get', 'capture', or 'both'.
  // stream is the stream returned by the last call to captureScreen
  // with which == 'get'.
  async function captureScreen(displaySurface, which, stream) {
    try {
      // Request screen capture permission
      if (which != 'capture') {
        stream = await navigator.mediaDevices.getDisplayMedia({
          video: { cursor: "never",
                   displaySurface: displaySurface
                 }
        });

        if (which == 'get') {
          return stream;
        }
      }

      if (stream) {
        const video = document.createElement("video");
        video.srcObject = stream;
        await video.play();

        // Draw the current frame to a canvas
        const canvas = document.createElement("canvas");
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(video, 0, 0);

        // Convert canvas to a base64 image string
        // (webp compesses bettern than png).
        const imageUrl = canvas.toDataURL("image/webp");
        
        // Stop the stream tracks
        stream.getTracks().forEach(track => track.stop());
        
        return imageUrl;
      }
    } catch (err) {
      console.error("Error capturing screen:", err);
    }
  }

  function initCaptureScreen(app) {
    if (!app) {
      console.log("app is not defined.");
      return;
    }
    var ports = app.ports;
    if (!ports) {
      console.log("app.ports is not defined.");
      return;
    }

    const captureScreenIn = ports.captureScreenIn;
    const captureScreenOut = ports.captureScreenOut;

    if (!captureScreenIn || !captureScreenOut) {
      console.log("captureScreenIn or captureScreenOut port not defined.");
      return;
    }

    var stream = null;

    captureScreenIn.subscribe(function(command) {
      var displaySurface = 'monitor';
      var which = 'both';
      if (typeof(command) == 'string') {
        displaySurface = command;
      } else if (typeof(command.displaySurface) == 'string') {
        displaySurface = command.displaySurface;
        if (typeof(command.which) == 'string') {
          which = command.which;
        }
      } else {
        return;
      }
      captureScreen(displaySurface, which, stream).then((url) => {
        if (which == 'get') {
          stream = url;
          // Let the Elm code know we got here.
          captureScreenOut.send("");
        } else {
          stream = null;
          captureScreenOut.send(url);
        }
      }).catch((error) => {
        console.log('Failed to captureScreen:', error);
      });
    });
  }

  scope.initCaptureScreen = initCaptureScreen;
})(this);   // Execute the enclosing function.
