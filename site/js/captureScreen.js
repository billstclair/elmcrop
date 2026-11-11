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

  async function captureScreen() {
    try {
      // Request screen capture permission
      const stream = await navigator.mediaDevices.getDisplayMedia({
        video: { cursor: "always" }
      });
      
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
      const imageUrl = canvas.toDataURL("image/png");
      
      // Stop the stream tracks
      stream.getTracks().forEach(track => track.stop());
      
      return imageUrl;
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

    var captureScreenIn = ports.captureScreenIn;
    var captureScreenOut = ports.captureScreenOut;

    if (!captureScreenIn || !captureScreenOut) {
      console.log("captureScreenIn or captureScreenOut port not defined.");
      return;
    }

    captureScreenIn.subscribe(function() {
      var url = null;
      captureScreen().then((urlDePromised) => {
        url = urlDePromised;
        captureScreenOut.send(url);
      }).catch((error) => {
        console.error('Failed to captureScreen:', error);
      });
    });
  }

  scope.initCaptureScreen = initCaptureScreen;
})(this);   // Execute the enclosing function.
