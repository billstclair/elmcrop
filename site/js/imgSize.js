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
  function initImgSize(app) {
    if (!app) {
      console.log("app is not defined.");
      return;
    }
    var ports = app.ports;
    if (!ports) {
      console.log("app.ports is not defined.");
      return;
    }

    const imgSizeIn = ports.imgSizeIn;
    const imgSizeOut = ports.imgSizeOut;

    if (!imgSizeIn || !imgSizeOut) {
      console.log("imgSizeIn or imgSizeOut port not defined.");
      return;
    }

    imgSizeIn.subscribe(function(id) {
      const img = document.getElementById(id);
      if (img) {
        imgSizeOut.send({ id: id,
                          width: img.width,
                          naturalWidth: img.naturalWidth,
                          height: img.height,
                          naturalHeight: img.naturalHeight
                        });
      }
    });
  }

  scope.initImgSize = initImgSize;
})(this);   // Execute the enclosing function.
